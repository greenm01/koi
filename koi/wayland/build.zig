const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const xdg_shell_xml = "/usr/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml";
    const cursor_shape_xml = "/usr/share/wayland-protocols/staging/cursor-shape/cursor-shape-v1.xml";
    const tablet_xml = "/usr/share/wayland-protocols/unstable/tablet/tablet-unstable-v2.xml";

    const xdg_header_step = b.addSystemCommand(&.{
        "wayland-scanner",
        "client-header",
        xdg_shell_xml,
    });
    const xdg_header = xdg_header_step.addOutputFileArg("xdg-shell-client-protocol.h");

    const xdg_code_step = b.addSystemCommand(&.{
        "wayland-scanner",
        "private-code",
        xdg_shell_xml,
    });
    const xdg_code = xdg_code_step.addOutputFileArg("xdg-shell-protocol.c");

    const cursor_shape_header_step = b.addSystemCommand(&.{
        "wayland-scanner",
        "client-header",
        cursor_shape_xml,
    });
    const cursor_shape_header = cursor_shape_header_step.addOutputFileArg("cursor-shape-v1-client-protocol.h");

    const cursor_shape_code_step = b.addSystemCommand(&.{
        "wayland-scanner",
        "private-code",
        cursor_shape_xml,
    });
    const cursor_shape_code = cursor_shape_code_step.addOutputFileArg("cursor-shape-v1-protocol.c");

    const tablet_code_step = b.addSystemCommand(&.{
        "wayland-scanner",
        "private-code",
        tablet_xml,
    });
    const tablet_code = tablet_code_step.addOutputFileArg("tablet-unstable-v2-protocol.c");

    const module = b.createModule(.{
        .root_source_file = b.path("koi_wayland.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    module.addIncludePath(xdg_header.dirname());
    module.addIncludePath(cursor_shape_header.dirname());
    module.addCSourceFile(.{
        .file = xdg_code,
        .flags = &.{ "-std=c11", "-Wall", "-Wextra" },
    });
    module.addCSourceFile(.{
        .file = cursor_shape_code,
        .flags = &.{ "-std=c11", "-Wall", "-Wextra" },
    });
    module.addCSourceFile(.{
        .file = tablet_code,
        .flags = &.{ "-std=c11", "-Wall", "-Wextra" },
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
