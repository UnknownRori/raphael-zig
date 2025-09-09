const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const flag_lib = flag_build(b, target, optimize);
    const flag_zig_mod = flag_lib.root_module;

    const yaml_lib = yaml_parser_build(b, target, optimize);
    const yaml_lib_mod = yaml_lib.root_module;

    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    lib_mod.addImport("yaml_zig", yaml_lib_mod);

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe_mod.addImport("flag_zig", flag_zig_mod);
    exe_mod.addImport("raphael_zig_lib", lib_mod);

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "raphael_zig",
        .root_module = lib_mod,
    });

    b.installArtifact(lib);
    b.installArtifact(yaml_lib);
    b.installArtifact(flag_lib);

    const exe = b.addExecutable(.{
        .name = "raphael_zig",
        .root_module = exe_mod,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const lib_unit_tests = b.addTest(.{
        .root_module = lib_mod,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
}

fn flag_build(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Step.Compile {
    const mod = b.createModule(.{
        .root_source_file = b.path("external/flag.zig/src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "flag_zig",
        .root_module = mod,
    });

    return lib;
}

fn yaml_parser_build(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Step.Compile {
    const mod = b.createModule(.{
        .root_source_file = b.path("external/yaml.zig/src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "yaml_zig",
        .root_module = mod,
    });

    return lib;
}
