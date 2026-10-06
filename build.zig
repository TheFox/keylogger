const std = @import("std");
const print = std.debug.print;
const aprint = std.fmt.allocPrint;
const eql = std.mem.eql;

pub fn build(b: *std.Build) !void {
    const version: std.SemanticVersion = .{ // VERSION
        .major = 2,
        .minor = 4,
        .patch = 0,
        .pre = "dev.5",
    };
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{
        .preferred_optimize_mode = .small,
    });
    const is_ci = b.option(bool, "ci", "Enable CI mode") orelse false;

    const target_name = try if (is_ci)
        aprint(b.allocator, "keylogger", .{})
    else if (eql(u8, target.result.cpu.model.name, "x86_64"))
        aprint(b.allocator, "keylogger-{s}", .{@tagName(target.result.cpu.arch)})
    else
        aprint(b.allocator, "keylogger-{s}-{s}", .{ @tagName(target.result.cpu.arch), target.result.cpu.model.name });

    print("target arch: {s}\n", .{@tagName(target.result.cpu.arch)});
    print("target cpu: {s}\n", .{target.result.cpu.model.name});
    print("target os: {s}\n", .{@tagName(target.result.os.tag)});
    print("target name: {s}\n", .{target_name});
    print("optimize: {s}\n", .{@tagName(optimize)});
    print("CI: {any}\n", .{is_ci});

    const translate_c = b.addTranslateC(.{
        .root_source_file = b.path("src/c.h"),
        .target = target,
        .optimize = optimize,
    });

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
