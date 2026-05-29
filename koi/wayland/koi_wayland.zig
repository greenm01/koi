const std = @import("std");
const c = @cImport({
    @cInclude("wayland-client.h");
    @cInclude("xdg-shell-client-protocol.h");
});

const allocator = std.heap.c_allocator;

const KoiWaylandCallbacks = extern struct {
    on_close: ?*const fn (?*anyopaque) callconv(.c) void,
    on_resize: ?*const fn (u32, u32, ?*anyopaque) callconv(.c) void,
    on_key_down: ?*const fn (u32, u32, ?*anyopaque) callconv(.c) void,
    on_key_up: ?*const fn (u32, u32, ?*anyopaque) callconv(.c) void,
    on_mouse_move: ?*const fn (f64, f64, ?*anyopaque) callconv(.c) void,
    on_mouse_button: ?*const fn (u32, bool, ?*anyopaque) callconv(.c) void,
    on_scroll: ?*const fn (f64, f64, ?*anyopaque) callconv(.c) void,
    on_scale: ?*const fn (f64, ?*anyopaque) callconv(.c) void,
    userdata: ?*anyopaque,
};

const KoiWaylandDisplay = extern struct {
    wl_display: ?*c.struct_wl_display,
    wl_registry: ?*c.struct_wl_registry,
    wl_compositor: ?*c.struct_wl_compositor,
    wl_seat: ?*c.struct_wl_seat,
    wl_pointer: ?*c.struct_wl_pointer,
    xdg_wm_base: ?*c.struct_xdg_wm_base,
    active_window: ?*KoiWaylandWindow,
    pointer_window: ?*KoiWaylandWindow,
};

const KoiWaylandWindow = extern struct {
    display: ?*KoiWaylandDisplay,
    wl_surface: ?*c.struct_wl_surface,
    xdg_surface: ?*c.struct_xdg_surface,
    xdg_toplevel: ?*c.struct_xdg_toplevel,
    callbacks: KoiWaylandCallbacks,
    width: u32,
    height: u32,
};

fn cStringEquals(value: [*c]const u8, expected: []const u8) bool {
    if (value == null) {
        return false;
    }
    const sentinel: [*:0]const u8 = @ptrCast(value);
    return std.mem.eql(u8, std.mem.span(sentinel), expected);
}

fn bindGlobal(
    comptime T: type,
    registry: *c.struct_wl_registry,
    name: u32,
    interface: *const c.struct_wl_interface,
    version: u32,
) ?*T {
    const proxy = c.wl_registry_bind(registry, name, interface, version) orelse return null;
    return @ptrCast(@alignCast(proxy));
}

fn fixedToDouble(value: c.wl_fixed_t) f64 {
    return @as(f64, @floatFromInt(value)) / 256.0;
}

fn registryGlobal(
    data: ?*anyopaque,
    registry: ?*c.struct_wl_registry,
    name: u32,
    interface: [*c]const u8,
    version: u32,
) callconv(.c) void {
    const display: *KoiWaylandDisplay = @ptrCast(@alignCast(data orelse return));
    const reg = registry orelse return;

    if (cStringEquals(interface, "wl_compositor")) {
        display.wl_compositor = bindGlobal(
            c.struct_wl_compositor,
            reg,
            name,
            &c.wl_compositor_interface,
            @min(version, 4),
        );
    } else if (cStringEquals(interface, "xdg_wm_base")) {
        display.xdg_wm_base = bindGlobal(
            c.struct_xdg_wm_base,
            reg,
            name,
            &c.xdg_wm_base_interface,
            @min(version, 6),
        );
        if (display.xdg_wm_base) |wm_base| {
            _ = c.xdg_wm_base_add_listener(wm_base, &xdg_wm_base_listener, display);
        }
    } else if (cStringEquals(interface, "wl_seat")) {
        display.wl_seat = bindGlobal(
            c.struct_wl_seat,
            reg,
            name,
            &c.wl_seat_interface,
            @min(version, 5),
        );
        if (display.wl_seat) |seat| {
            _ = c.wl_seat_add_listener(seat, &wl_seat_listener, display);
        }
    }
}

fn registryGlobalRemove(
    data: ?*anyopaque,
    registry: ?*c.struct_wl_registry,
    name: u32,
) callconv(.c) void {
    _ = data;
    _ = registry;
    _ = name;
}

const registry_listener = c.struct_wl_registry_listener{
    .global = registryGlobal,
    .global_remove = registryGlobalRemove,
};

fn wlSeatCapabilities(
    data: ?*anyopaque,
    wl_seat: ?*c.struct_wl_seat,
    capabilities: u32,
) callconv(.c) void {
    const display: *KoiWaylandDisplay = @ptrCast(@alignCast(data orelse return));
    const seat = wl_seat orelse return;
    const has_pointer = (capabilities & @as(u32, c.WL_SEAT_CAPABILITY_POINTER)) != 0;

    if (has_pointer and display.wl_pointer == null) {
        display.wl_pointer = c.wl_seat_get_pointer(seat);
        if (display.wl_pointer) |pointer| {
            _ = c.wl_pointer_add_listener(pointer, &wl_pointer_listener, display);
        }
    } else if (!has_pointer and display.wl_pointer != null) {
        c.wl_pointer_destroy(display.wl_pointer.?);
        display.wl_pointer = null;
        display.pointer_window = null;
    }
}

fn wlSeatName(
    data: ?*anyopaque,
    wl_seat: ?*c.struct_wl_seat,
    name: [*c]const u8,
) callconv(.c) void {
    _ = data;
    _ = wl_seat;
    _ = name;
}

const wl_seat_listener = c.struct_wl_seat_listener{
    .capabilities = wlSeatCapabilities,
    .name = wlSeatName,
};

fn pointerWindowForSurface(
    display: *KoiWaylandDisplay,
    surface: ?*c.struct_wl_surface,
) ?*KoiWaylandWindow {
    const window = display.active_window orelse return null;
    if (window.wl_surface == surface) {
        return window;
    }
    return null;
}

fn wlPointerEnter(
    data: ?*anyopaque,
    wl_pointer: ?*c.struct_wl_pointer,
    serial: u32,
    surface: ?*c.struct_wl_surface,
    surface_x: c.wl_fixed_t,
    surface_y: c.wl_fixed_t,
) callconv(.c) void {
    _ = wl_pointer;
    _ = serial;
    const display: *KoiWaylandDisplay = @ptrCast(@alignCast(data orelse return));
    const window = pointerWindowForSurface(display, surface) orelse return;
    display.pointer_window = window;
    if (window.callbacks.on_mouse_move) |on_mouse_move| {
        on_mouse_move(
            fixedToDouble(surface_x),
            fixedToDouble(surface_y),
            window.callbacks.userdata,
        );
    }
}

fn wlPointerLeave(
    data: ?*anyopaque,
    wl_pointer: ?*c.struct_wl_pointer,
    serial: u32,
    surface: ?*c.struct_wl_surface,
) callconv(.c) void {
    _ = wl_pointer;
    _ = serial;
    const display: *KoiWaylandDisplay = @ptrCast(@alignCast(data orelse return));
    if (display.pointer_window) |window| {
        if (window.wl_surface == surface) {
            display.pointer_window = null;
        }
    }
}

fn wlPointerMotion(
    data: ?*anyopaque,
    wl_pointer: ?*c.struct_wl_pointer,
    time: u32,
    surface_x: c.wl_fixed_t,
    surface_y: c.wl_fixed_t,
) callconv(.c) void {
    _ = wl_pointer;
    _ = time;
    const display: *KoiWaylandDisplay = @ptrCast(@alignCast(data orelse return));
    const window = display.pointer_window orelse return;
    if (window.callbacks.on_mouse_move) |on_mouse_move| {
        on_mouse_move(
            fixedToDouble(surface_x),
            fixedToDouble(surface_y),
            window.callbacks.userdata,
        );
    }
}

fn wlPointerButton(
    data: ?*anyopaque,
    wl_pointer: ?*c.struct_wl_pointer,
    serial: u32,
    time: u32,
    button: u32,
    state: u32,
) callconv(.c) void {
    _ = wl_pointer;
    _ = serial;
    _ = time;
    const display: *KoiWaylandDisplay = @ptrCast(@alignCast(data orelse return));
    const window = display.pointer_window orelse display.active_window orelse return;
    if (window.callbacks.on_mouse_button) |on_mouse_button| {
        on_mouse_button(
            button,
            state == @as(u32, c.WL_POINTER_BUTTON_STATE_PRESSED),
            window.callbacks.userdata,
        );
    }
}

fn wlPointerAxis(
    data: ?*anyopaque,
    wl_pointer: ?*c.struct_wl_pointer,
    time: u32,
    axis: u32,
    value: c.wl_fixed_t,
) callconv(.c) void {
    _ = wl_pointer;
    _ = time;
    const display: *KoiWaylandDisplay = @ptrCast(@alignCast(data orelse return));
    const window = display.pointer_window orelse display.active_window orelse return;
    if (window.callbacks.on_scroll) |on_scroll| {
        const amount = fixedToDouble(value);
        if (axis == @as(u32, c.WL_POINTER_AXIS_HORIZONTAL_SCROLL)) {
            on_scroll(amount, 0, window.callbacks.userdata);
        } else if (axis == @as(u32, c.WL_POINTER_AXIS_VERTICAL_SCROLL)) {
            on_scroll(0, amount, window.callbacks.userdata);
        }
    }
}

fn wlPointerFrame(data: ?*anyopaque, wl_pointer: ?*c.struct_wl_pointer) callconv(.c) void {
    _ = data;
    _ = wl_pointer;
}

fn wlPointerAxisSource(
    data: ?*anyopaque,
    wl_pointer: ?*c.struct_wl_pointer,
    axis_source: u32,
) callconv(.c) void {
    _ = data;
    _ = wl_pointer;
    _ = axis_source;
}

fn wlPointerAxisStop(
    data: ?*anyopaque,
    wl_pointer: ?*c.struct_wl_pointer,
    time: u32,
    axis: u32,
) callconv(.c) void {
    _ = data;
    _ = wl_pointer;
    _ = time;
    _ = axis;
}

fn wlPointerAxisDiscrete(
    data: ?*anyopaque,
    wl_pointer: ?*c.struct_wl_pointer,
    axis: u32,
    discrete: i32,
) callconv(.c) void {
    _ = data;
    _ = wl_pointer;
    _ = axis;
    _ = discrete;
}

fn wlPointerAxisValue120(
    data: ?*anyopaque,
    wl_pointer: ?*c.struct_wl_pointer,
    axis: u32,
    value120: i32,
) callconv(.c) void {
    _ = data;
    _ = wl_pointer;
    _ = axis;
    _ = value120;
}

fn wlPointerAxisRelativeDirection(
    data: ?*anyopaque,
    wl_pointer: ?*c.struct_wl_pointer,
    axis: u32,
    direction: u32,
) callconv(.c) void {
    _ = data;
    _ = wl_pointer;
    _ = axis;
    _ = direction;
}

const wl_pointer_listener = c.struct_wl_pointer_listener{
    .enter = wlPointerEnter,
    .leave = wlPointerLeave,
    .motion = wlPointerMotion,
    .button = wlPointerButton,
    .axis = wlPointerAxis,
    .frame = wlPointerFrame,
    .axis_source = wlPointerAxisSource,
    .axis_stop = wlPointerAxisStop,
    .axis_discrete = wlPointerAxisDiscrete,
    .axis_value120 = wlPointerAxisValue120,
    .axis_relative_direction = wlPointerAxisRelativeDirection,
};

fn xdgWmBasePing(
    data: ?*anyopaque,
    xdg_wm_base: ?*c.struct_xdg_wm_base,
    serial: u32,
) callconv(.c) void {
    _ = data;
    const wm_base = xdg_wm_base orelse return;
    c.xdg_wm_base_pong(wm_base, serial);
}

const xdg_wm_base_listener = c.struct_xdg_wm_base_listener{
    .ping = xdgWmBasePing,
};

fn xdgSurfaceConfigure(
    data: ?*anyopaque,
    xdg_surface: ?*c.struct_xdg_surface,
    serial: u32,
) callconv(.c) void {
    _ = data;
    const surface = xdg_surface orelse return;
    c.xdg_surface_ack_configure(surface, serial);
}

const xdg_surface_listener = c.struct_xdg_surface_listener{
    .configure = xdgSurfaceConfigure,
};

fn xdgToplevelConfigure(
    data: ?*anyopaque,
    xdg_toplevel: ?*c.struct_xdg_toplevel,
    width: i32,
    height: i32,
    states: ?*c.struct_wl_array,
) callconv(.c) void {
    _ = xdg_toplevel;
    _ = states;

    const window: *KoiWaylandWindow = @ptrCast(@alignCast(data orelse return));
    if (width > 0 and height > 0) {
        const next_width: u32 = @intCast(width);
        const next_height: u32 = @intCast(height);
        if (window.width != next_width or window.height != next_height) {
            window.width = next_width;
            window.height = next_height;
            if (window.callbacks.on_resize) |on_resize| {
                on_resize(next_width, next_height, window.callbacks.userdata);
            }
        }
    }
}

fn xdgToplevelClose(
    data: ?*anyopaque,
    xdg_toplevel: ?*c.struct_xdg_toplevel,
) callconv(.c) void {
    _ = xdg_toplevel;
    const window: *KoiWaylandWindow = @ptrCast(@alignCast(data orelse return));
    if (window.callbacks.on_close) |on_close| {
        on_close(window.callbacks.userdata);
    }
}

fn xdgToplevelConfigureBounds(
    data: ?*anyopaque,
    xdg_toplevel: ?*c.struct_xdg_toplevel,
    width: i32,
    height: i32,
) callconv(.c) void {
    _ = data;
    _ = xdg_toplevel;
    _ = width;
    _ = height;
}

fn xdgToplevelWmCapabilities(
    data: ?*anyopaque,
    xdg_toplevel: ?*c.struct_xdg_toplevel,
    capabilities: ?*c.struct_wl_array,
) callconv(.c) void {
    _ = data;
    _ = xdg_toplevel;
    _ = capabilities;
}

const xdg_toplevel_listener = c.struct_xdg_toplevel_listener{
    .configure = xdgToplevelConfigure,
    .close = xdgToplevelClose,
    .configure_bounds = xdgToplevelConfigureBounds,
    .wm_capabilities = xdgToplevelWmCapabilities,
};

fn destroyDisplayResources(display: *KoiWaylandDisplay) void {
    if (display.wl_pointer) |pointer| {
        c.wl_pointer_destroy(pointer);
    }
    if (display.wl_seat) |seat| {
        c.wl_seat_destroy(seat);
    }
    if (display.xdg_wm_base) |wm_base| {
        c.xdg_wm_base_destroy(wm_base);
    }
    if (display.wl_compositor) |compositor| {
        c.wl_compositor_destroy(compositor);
    }
    if (display.wl_registry) |registry| {
        c.wl_registry_destroy(registry);
    }
    if (display.wl_display) |wl_display| {
        c.wl_display_disconnect(wl_display);
    }
}

export fn koi_wayland_init() ?*KoiWaylandDisplay {
    const display = allocator.create(KoiWaylandDisplay) catch return null;
    display.* = .{
        .wl_display = c.wl_display_connect(null),
        .wl_registry = null,
        .wl_compositor = null,
        .wl_seat = null,
        .wl_pointer = null,
        .xdg_wm_base = null,
        .active_window = null,
        .pointer_window = null,
    };
    if (display.wl_display == null) {
        allocator.destroy(display);
        return null;
    }
    display.wl_registry = c.wl_display_get_registry(display.wl_display.?);
    if (display.wl_registry == null) {
        destroyDisplayResources(display);
        allocator.destroy(display);
        return null;
    }

    _ = c.wl_registry_add_listener(display.wl_registry.?, &registry_listener, display);
    if (c.wl_display_roundtrip(display.wl_display.?) < 0) {
        destroyDisplayResources(display);
        allocator.destroy(display);
        return null;
    }
    if (display.wl_compositor == null or display.xdg_wm_base == null) {
        destroyDisplayResources(display);
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
    const d = display orelse return null;
    const compositor = d.wl_compositor orelse return null;
    const wm_base = d.xdg_wm_base orelse return null;

    const window = allocator.create(KoiWaylandWindow) catch return null;
    window.* = .{
        .display = d,
        .wl_surface = c.wl_compositor_create_surface(compositor),
        .xdg_surface = null,
        .xdg_toplevel = null,
        .callbacks = std.mem.zeroes(KoiWaylandCallbacks),
        .width = w,
        .height = h,
    };
    if (window.wl_surface == null) {
        allocator.destroy(window);
        return null;
    }

    window.xdg_surface = c.xdg_wm_base_get_xdg_surface(wm_base, window.wl_surface.?);
    if (window.xdg_surface == null) {
        c.wl_surface_destroy(window.wl_surface.?);
        allocator.destroy(window);
        return null;
    }

    _ = c.xdg_surface_add_listener(window.xdg_surface.?, &xdg_surface_listener, window);
    window.xdg_toplevel = c.xdg_surface_get_toplevel(window.xdg_surface.?);
    if (window.xdg_toplevel == null) {
        c.xdg_surface_destroy(window.xdg_surface.?);
        c.wl_surface_destroy(window.wl_surface.?);
        allocator.destroy(window);
        return null;
    }

    _ = c.xdg_toplevel_add_listener(window.xdg_toplevel.?, &xdg_toplevel_listener, window);
    c.xdg_toplevel_set_title(window.xdg_toplevel.?, title);
    c.wl_surface_commit(window.wl_surface.?);
    if (d.wl_display) |wl_display| {
        _ = c.wl_display_flush(wl_display);
    }
    d.active_window = window;

    return window;
}

export fn koi_wayland_set_callbacks(
    window: ?*KoiWaylandWindow,
    callbacks: ?*const anyopaque,
) void {
    const win = window orelse return;
    if (callbacks) |cb| {
        win.callbacks = @as(*const KoiWaylandCallbacks, @ptrCast(@alignCast(cb))).*;
    } else {
        win.callbacks = std.mem.zeroes(KoiWaylandCallbacks);
    }
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
    const win = window orelse return;
    if (win.xdg_toplevel) |toplevel| {
        c.xdg_toplevel_set_title(toplevel, title);
    }
}

export fn koi_wayland_set_size(window: ?*KoiWaylandWindow, w: u32, h: u32) void {
    const win = window orelse return;
    win.width = w;
    win.height = h;
}

export fn koi_wayland_destroy_window(window: ?*KoiWaylandWindow) void {
    const win = window orelse return;
    if (win.display) |display| {
        if (display.pointer_window == win) {
            display.pointer_window = null;
        }
        if (display.active_window == win) {
            display.active_window = null;
        }
    }
    if (win.xdg_toplevel) |toplevel| {
        c.xdg_toplevel_destroy(toplevel);
    }
    if (win.xdg_surface) |surface| {
        c.xdg_surface_destroy(surface);
    }
    if (win.wl_surface) |surface| {
        c.wl_surface_destroy(surface);
    }
    allocator.destroy(win);
}

export fn koi_wayland_destroy(display: ?*KoiWaylandDisplay) void {
    const d = display orelse return;
    destroyDisplayResources(d);
    allocator.destroy(d);
}
