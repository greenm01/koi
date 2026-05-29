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

    const test_step = b.step("test", "Build the Koi Wayland C ABI library");
    test_step.dependOn(&lib.step);
}
