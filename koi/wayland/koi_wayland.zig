const std = @import("std");
const c = @cImport({
    @cInclude("wayland-client.h");
});

const allocator = std.heap.c_allocator;

const KoiWaylandDisplay = extern struct {
    wl_display: ?*c.struct_wl_display,
};

const KoiWaylandWindow = extern struct {
    display: ?*KoiWaylandDisplay,
    wl_surface: ?*c.struct_wl_surface,
    width: u32,
    height: u32,
};

export fn koi_wayland_init() ?*KoiWaylandDisplay {
    const display = allocator.create(KoiWaylandDisplay) catch return null;
    display.* = .{
        .wl_display = c.wl_display_connect(null),
    };
    if (display.wl_display == null) {
        allocator.destroy(display);
        return null;
    }
    return display;
}

export fn koi_wayland_create_window(
    display: ?*KoiWaylandDisplay,
    w: u32,
    h: u32,
    title: [*:0]const u8,
) ?*KoiWaylandWindow {
    _ = title;
    const d = display orelse return null;
    const window = allocator.create(KoiWaylandWindow) catch return null;
    window.* = .{
        .display = d,
        .wl_surface = null,
        .width = w,
        .height = h,
    };
    return window;
}

export fn koi_wayland_set_callbacks(
    window: ?*KoiWaylandWindow,
    callbacks: ?*const anyopaque,
) void {
    _ = window;
    _ = callbacks;
}

export fn koi_wayland_poll_events(display: ?*KoiWaylandDisplay) void {
    const d = display orelse return;
    const wl_display = d.wl_display orelse return;
    _ = c.wl_display_dispatch_pending(wl_display);
    _ = c.wl_display_flush(wl_display);
}

export fn koi_wayland_get_wl_display(display: ?*KoiWaylandDisplay) ?*anyopaque {
    const d = display orelse return null;
    return d.wl_display;
}

export fn koi_wayland_get_wl_surface(window: ?*KoiWaylandWindow) ?*anyopaque {
    const w = window orelse return null;
    return w.wl_surface;
}

export fn koi_wayland_set_title(window: ?*KoiWaylandWindow, title: [*:0]const u8) void {
    _ = window;
    _ = title;
}

export fn koi_wayland_set_size(window: ?*KoiWaylandWindow, w: u32, h: u32) void {
    const win = window orelse return;
    win.width = w;
    win.height = h;
}

export fn koi_wayland_destroy_window(window: ?*KoiWaylandWindow) void {
    const win = window orelse return;
    if (win.wl_surface) |surface| {
        c.wl_surface_destroy(surface);
    }
    allocator.destroy(win);
}

export fn koi_wayland_destroy(display: ?*KoiWaylandDisplay) void {
    const d = display orelse return;
    if (d.wl_display) |wl_display| {
        c.wl_display_disconnect(wl_display);
    }
    allocator.destroy(d);
}
