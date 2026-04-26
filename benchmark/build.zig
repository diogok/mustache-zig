const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{
        .default_target = .{
            .cpu_model = .baseline,
        },
    });

    // Benchmark defaults to ReleaseSafe
    const mode = std.builtin.OptimizeMode.ReleaseSafe;

    const mustache_module = b.createModule(.{
        .root_source_file = b.path("../src/mustache.zig"),
        .target = target,
        .optimize = mode,
    });

    const exe_module = b.createModule(.{
        .root_source_file = b.path("src/ramhorns_bench.zig"),
        .target = target,
        .optimize = mode,
        .link_libc = true,
    });
    exe_module.addImport("mustache", mustache_module);

    const exe = b.addExecutable(.{
        .name = "benchmark",
        .root_module = exe_module,
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the benchmark");
    run_step.dependOn(&run_cmd.step);
}
