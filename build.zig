const std = @import("std");

pub fn build(builder: *std.build.Builder) void {
    const target = builder.standardTargetOptions(.{});
    const optimize = builder.standardOptimizeOption(.{});

    const exe = builder.addExecutable(.{
        .name = "shogi",
        .root_source_file = .{ .path = "source/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.linkLibC();
    exe.linkSystemLibrary("SDL2");
    builder.installArtifact(exe);

    const run_step = builder.step("run", "Run the program");
    const run_exe = builder.addRunArtifact(exe);
    run_step.dependOn(&run_exe.step);
    run_exe.step.dependOn(builder.getInstallStep());
}
