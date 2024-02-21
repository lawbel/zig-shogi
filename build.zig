const std = @import("std");

// This is needed so that we can have our source files under `source/`
// and other files in another folder like `data/` for example.
const main_mod_path: std.build.LazyPath = .{ .path = "." };

/// Builds this project.
pub fn build(builder: *std.Build) void {
    // Take standard zig CLI options.
    const target = builder.standardTargetOptions(.{});
    const optimize = builder.standardOptimizeOption(.{});

    // Add our main executable.
    const exe = builder.addExecutable(.{
        .name = "shogi",
        .root_source_file = .{ .path = "source/main.zig" },
        .main_mod_path = main_mod_path,
        .target = target,
        .optimize = optimize,
    });

    // Add the C dependencies we need.
    exe.linkLibC();
    exe.linkSystemLibrary("SDL2");
    exe.linkSystemLibrary("SDL2_image");
    exe.linkSystemLibrary("SDL2_gfx");
    exe.linkSystemLibrary("SDL2_ttf");

    // Install the executable.
    builder.installArtifact(exe);

    // Add a 'step' for the executable.
    const exe_run = builder.addRunArtifact(exe);
    const exe_step = builder.step("run", "Run the program");
    exe_step.dependOn(&exe_run.step);

    // Test suite.
    const tester = builder.addTest(.{
        .root_source_file = .{ .path = "source/test.zig" },
        // .main_mod_path = main_mod_path,
        .target = target,
        .optimize = optimize,
    });

    // Add a 'step' for the test suite.
    const tester_run = builder.addRunArtifact(tester);
    const tester_step = builder.step("test", "Run the test suite");
    tester_step.dependOn(&tester_run.step);
}
