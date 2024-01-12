const std = @import("std");

pub fn build(builder: *std.build.Builder) void {
    // Take standard zig CLI options.
    const target = builder.standardTargetOptions(.{});
    const optimize = builder.standardOptimizeOption(.{});

    // Add our main executable.
    const exe = builder.addExecutable(.{
        .name = "shogi",
        .root_source_file = .{ .path = "source/main.zig" },

        // This is needed so that we can have our source files under `source/`
        // and other files in another folder like `data/` for example.
        .main_mod_path = .{ .path = "." },

        .target = target,
        .optimize = optimize,
    });

    // Add the C dependencies we need.
    exe.linkLibC();
    exe.linkSystemLibrary("SDL2");

    // Install the executable.
    builder.installArtifact(exe);

    // Add a CLI option `run` for convenience, which (re)builds if necessary
    // and then runs the executable.
    const run_step = builder.step("run", "Run the program");
    const run_exe = builder.addRunArtifact(exe);
    run_step.dependOn(&run_exe.step);
    run_exe.step.dependOn(builder.getInstallStep());
}
