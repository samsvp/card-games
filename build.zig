const std = @import("std");
const rlz = @import("raylib_zig");
const emcc = rlz.emcc;

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "cards",
        .root_module = exe_mod,
    });

    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
    });

    const raylib = raylib_dep.module("raylib"); // main raylib module
    const raygui = raylib_dep.module("raygui");
    const raylib_artifact = raylib_dep.artifact("raylib"); // raylib C library

    if (target.query.os_tag == .emscripten) {
        const exe_lib = try emcc.compileForEmscripten(
            b,
            "zig-raylib-web",
            "src/main.zig",
            target,
            optimize,
        );
        exe_lib.root_module.addImport("raylib", raylib);
        exe_lib.root_module.addImport("raygui", raygui);

        // Note that raylib itself isn't actually added to the exe_lib
        // output file, so it also needs to be linked with emscripten.
        exe_lib.linkLibrary(raylib_artifact);
        const link_step = try emcc.linkWithEmscripten(b, &[_]*std.Build.Step.Compile{
            exe_lib,
            raylib_artifact,
        });
        link_step.addArg("--embed-file");
        link_step.addArg("resources/");
        link_step.addArg("--shell-file");
        link_step.addArg("shell.html");

        b.getInstallStep().dependOn(&link_step.step);
        const run_step = try emcc.emscriptenRunStep(b);
        run_step.step.dependOn(&link_step.step);
        const run_option = b.step("run", "Run the app");

        run_option.dependOn(&run_step.step);
    } else {
        exe.linkLibrary(raylib_artifact);
        exe.root_module.addImport("raygui", raygui);
        exe.root_module.addImport("raylib", raylib);

        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);

        run_cmd.step.dependOn(b.getInstallStep());

        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        const run_step = b.step("run", "Run the app");
        run_step.dependOn(&run_cmd.step);

        const exe_unit_tests = b.addTest(.{
            .root_module = exe_mod,
        });

        const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

        const test_step = b.step("test", "Run unit tests");
        test_step.dependOn(&run_exe_unit_tests.step);
    }
}
