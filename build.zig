const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const linkage = b.option(
        std.builtin.LinkMode,
        "linkage",
        "Link mode for scribe library",
    ) orelse .static;
    const rootModules = b.addModule("scribe", .{
        .root_source_file = b.path("src/root.zig"),
        .pic = true,
        .target = target,
        .optimize = optimize,
    });
    const lib = b.addLibrary(.{
        .name = "scribe",
        .root_module = rootModules,
        .linkage = linkage,
    });

    b.installArtifact(lib);
    lib.linkLibC();
    lib.bundle_compiler_rt = true;

    const funnel_lib = b.dependency("funnel", .{
        .target = target,
        .optimize = optimize,
    });

    lib.root_module.addImport("funnel", funnel_lib.module("funnel"));

    var mod = b.addModule("scribe", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    mod.addImport("funnel", funnel_lib.module("funnel"));

    const test_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    const lib_unit_tests = b.addTest(.{
        .root_module = test_mod,
    });
    lib_unit_tests.linkLibC();
    lib_unit_tests.root_module.addImport("funnel", funnel_lib.module("funnel"));

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
