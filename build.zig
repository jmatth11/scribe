const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{
        .preferred_optimize_mode = .ReleaseFast,
    });

    const lib = b.addStaticLibrary(.{
        .name = "scribe",
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .pic = true,
    });

    b.installArtifact(lib);
    lib.linkLibC();
    lib.bundle_compiler_rt = true;

    const funnel_lib = b.dependency("funnel", .{
        .target = target,
    });

    lib.root_module.addImport("funnel", funnel_lib.module("funnel"));

    var mod = b.addModule("scribe", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    mod.addImport("funnel", funnel_lib.module("funnel"));

    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib_unit_tests.linkLibC();
    lib_unit_tests.root_module.addImport("funnel", funnel_lib.module("funnel"));

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
