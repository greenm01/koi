const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const module = b.createModule(.{
        .root_source_file = b.path("koi_wayland.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    module.linkSystemLibrary("wayland-client", .{ .use_pkg_config = .yes });
    module.linkSystemLibrary("xkbcommon", .{ .use_pkg_config = .yes });

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "koi_wayland",
        .root_module = module,
    });
    lib.installHeader(b.path("koi_wayland.h"), "koi_wayland.h");
    b.installArtifact(lib);

    const smoke = b.addExecutable(.{
        .name = "koi-wayland-c-abi-smoke",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    smoke.root_module.addCSourceFile(.{
        .file = b.path("c_abi_smoke.c"),
        .flags = &.{ "-std=c11", "-Wall", "-Wextra", "-Werror" },
    });
    smoke.root_module.addIncludePath(b.path("."));
    smoke.root_module.linkLibrary(lib);
    smoke.root_module.linkSystemLibrary("wayland-client", .{ .use_pkg_config = .yes });
    smoke.root_module.linkSystemLibrary("xkbcommon", .{ .use_pkg_config = .yes });

    const smoke_run = b.addRunArtifact(smoke);
    const test_step = b.step("test", "Run Koi Wayland C ABI smoke checks");
    test_step.dependOn(&smoke_run.step);
}
