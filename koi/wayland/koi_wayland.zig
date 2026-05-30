const std = @import("std");
const c = @cImport({
    @cInclude("poll.h");
    @cInclude("time.h");
    @cInclude("unistd.h");
    @cInclude("cursor-shape-v1-client-protocol.h");
    @cInclude("wayland-client.h");
    @cInclude("xkbcommon/xkbcommon.h");
    @cInclude("xdg-shell-client-protocol.h");
});

const allocator = std.heap.c_allocator;

const KoiWaylandModShift: u32 = 1 << 0;
const KoiWaylandModCtrl: u32 = 1 << 1;
const KoiWaylandModAlt: u32 = 1 << 2;
const KoiWaylandModSuper: u32 = 1 << 3;

const KoiWaylandCursorDefault: u32 = 1;
const KoiWaylandCursorText: u32 = 2;
const KoiWaylandCursorCrosshair: u32 = 3;
const KoiWaylandCursorPointer: u32 = 4;
const KoiWaylandCursorResizeEw: u32 = 5;
const KoiWaylandCursorResizeNs: u32 = 6;
const KoiWaylandCursorResizeNwse: u32 = 7;
const KoiWaylandCursorResizeNesw: u32 = 8;
const KoiWaylandCursorResizeAll: u32 = 9;

const KoiWaylandCallbacks = extern struct {
    on_close: ?*const fn (?*anyopaque) callconv(.c) void,
    on_focus: ?*const fn (bool, ?*anyopaque) callconv(.c) void,
    on_resize: ?*const fn (u32, u32, ?*anyopaque) callconv(.c) void,
    on_key_down: ?*const fn (u32, u32, ?*anyopaque) callconv(.c) void,
    on_key_repeat: ?*const fn (u32, u32, ?*anyopaque) callconv(.c) void,
    on_key_up: ?*const fn (u32, u32, ?*anyopaque) callconv(.c) void,
    on_char: ?*const fn (u32, ?*anyopaque) callconv(.c) void,
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
    wl_keyboard: ?*c.struct_wl_keyboard,
    wl_output: ?*c.struct_wl_output,
    xdg_wm_base: ?*c.struct_xdg_wm_base,
    cursor_shape_manager: ?*c.struct_wp_cursor_shape_manager_v1,
    cursor_shape_device: ?*c.struct_wp_cursor_shape_device_v1,
    cursor_shape_version: u32,
    xkb_context: ?*c.struct_xkb_context,
    xkb_keymap: ?*c.struct_xkb_keymap,
    xkb_state: ?*c.struct_xkb_state,
    mod_shift: c.xkb_mod_index_t,
    mod_ctrl: c.xkb_mod_index_t,
    mod_alt: c.xkb_mod_index_t,
    mod_super: c.xkb_mod_index_t,
    mods: u32,
    physical_mods: u32,
    output_scale: f64,
    repeat_rate: i32,
    repeat_delay: i32,
    repeat_key: u32,
    repeat_sym: u32,
    repeat_mods: u32,
    repeat_next_ms: i64,
    repeat_window: ?*KoiWaylandWindow,
    active_window: ?*KoiWaylandWindow,
    pointer_window: ?*KoiWaylandWindow,
    keyboard_window: ?*KoiWaylandWindow,
    pointer_enter_serial: u32,
};

const KoiWaylandWindow = extern struct {
    display: ?*KoiWaylandDisplay,
    wl_surface: ?*c.struct_wl_surface,
    xdg_surface: ?*c.struct_xdg_surface,
    xdg_toplevel: ?*c.struct_xdg_toplevel,
    callbacks: KoiWaylandCallbacks,
    width: u32,
    height: u32,
    pending_width: u32,
    pending_height: u32,
    has_pending_resize: bool,
    configured: bool,
    closed: bool,
    cursor_shape: u32,
    scale: f64,
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

fn nowMs() i64 {
    var ts: c.struct_timespec = undefined;
    if (c.clock_gettime(c.CLOCK_MONOTONIC, &ts) != 0) {
        return 0;
    }
    return @as(i64, @intCast(ts.tv_sec)) * 1000 + @divTrunc(@as(i64, @intCast(ts.tv_nsec)), 1_000_000);
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
    } else if (cStringEquals(interface, "wp_cursor_shape_manager_v1")) {
        const cursor_shape_version = @min(version, 2);
        display.cursor_shape_manager = bindGlobal(
            c.struct_wp_cursor_shape_manager_v1,
            reg,
            name,
            &c.wp_cursor_shape_manager_v1_interface,
            cursor_shape_version,
        );
        display.cursor_shape_version = cursor_shape_version;
        if (display.cursor_shape_manager) |manager| {
            if (display.wl_pointer) |pointer| {
                display.cursor_shape_device = c.wp_cursor_shape_manager_v1_get_pointer(
                    manager,
                    pointer,
                );
            }
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
    } else if (cStringEquals(interface, "wl_output") and display.wl_output == null) {
        display.wl_output = bindGlobal(
            c.struct_wl_output,
            reg,
            name,
            &c.wl_output_interface,
            @min(version, 2),
        );
        if (display.wl_output) |output| {
            _ = c.wl_output_add_listener(output, &wl_output_listener, display);
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
    const has_keyboard = (capabilities & @as(u32, c.WL_SEAT_CAPABILITY_KEYBOARD)) != 0;

    if (has_pointer and display.wl_pointer == null) {
        display.wl_pointer = c.wl_seat_get_pointer(seat);
        if (display.wl_pointer) |pointer| {
            _ = c.wl_pointer_add_listener(pointer, &wl_pointer_listener, display);
            if (display.cursor_shape_manager) |manager| {
                display.cursor_shape_device = c.wp_cursor_shape_manager_v1_get_pointer(
                    manager,
                    pointer,
                );
            }
        }
    } else if (!has_pointer and display.wl_pointer != null) {
        if (display.cursor_shape_device) |device| {
            c.wp_cursor_shape_device_v1_destroy(device);
            display.cursor_shape_device = null;
        }
        c.wl_pointer_destroy(display.wl_pointer.?);
        display.wl_pointer = null;
        display.pointer_window = null;
        display.pointer_enter_serial = 0;
    }

    if (has_keyboard and display.wl_keyboard == null) {
        display.wl_keyboard = c.wl_seat_get_keyboard(seat);
        if (display.wl_keyboard) |keyboard| {
            _ = c.wl_keyboard_add_listener(keyboard, &wl_keyboard_listener, display);
        }
    } else if (!has_keyboard and display.wl_keyboard != null) {
        c.wl_keyboard_destroy(display.wl_keyboard.?);
        display.wl_keyboard = null;
        display.keyboard_window = null;
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

fn notifyWindowScale(window: *KoiWaylandWindow, scale: f64) void {
    if (window.scale == scale) {
        return;
    }
    window.scale = scale;
    if (window.callbacks.on_scale) |on_scale| {
        on_scale(scale, window.callbacks.userdata);
    }
}

fn notifyActiveWindowScale(display: *KoiWaylandDisplay) void {
    if (display.active_window) |window| {
        notifyWindowScale(window, display.output_scale);
    }
}

fn wlOutputGeometry(
    data: ?*anyopaque,
    wl_output: ?*c.struct_wl_output,
    x: i32,
    y: i32,
    physical_width: i32,
    physical_height: i32,
    subpixel: i32,
    make: [*c]const u8,
    model: [*c]const u8,
    transform: i32,
) callconv(.c) void {
    _ = data;
    _ = wl_output;
    _ = x;
    _ = y;
    _ = physical_width;
    _ = physical_height;
    _ = subpixel;
    _ = make;
    _ = model;
    _ = transform;
}

fn wlOutputMode(
    data: ?*anyopaque,
    wl_output: ?*c.struct_wl_output,
    flags: u32,
    width: i32,
    height: i32,
    refresh: i32,
) callconv(.c) void {
    _ = data;
    _ = wl_output;
    _ = flags;
    _ = width;
    _ = height;
    _ = refresh;
}

fn wlOutputDone(data: ?*anyopaque, wl_output: ?*c.struct_wl_output) callconv(.c) void {
    _ = wl_output;
    const display: *KoiWaylandDisplay = @ptrCast(@alignCast(data orelse return));
    notifyActiveWindowScale(display);
}

fn wlOutputScale(
    data: ?*anyopaque,
    wl_output: ?*c.struct_wl_output,
    factor: i32,
) callconv(.c) void {
    _ = wl_output;
    const display: *KoiWaylandDisplay = @ptrCast(@alignCast(data orelse return));
    display.output_scale = @floatFromInt(@max(factor, 1));
    notifyActiveWindowScale(display);
}

const wl_output_listener = c.struct_wl_output_listener{
    .geometry = wlOutputGeometry,
    .mode = wlOutputMode,
    .done = wlOutputDone,
    .scale = wlOutputScale,
};

fn protocolCursorShape(shape: u32, version: u32) u32 {
    return switch (shape) {
        KoiWaylandCursorText => c.WP_CURSOR_SHAPE_DEVICE_V1_SHAPE_TEXT,
        KoiWaylandCursorCrosshair => c.WP_CURSOR_SHAPE_DEVICE_V1_SHAPE_CROSSHAIR,
        KoiWaylandCursorPointer => c.WP_CURSOR_SHAPE_DEVICE_V1_SHAPE_POINTER,
        KoiWaylandCursorResizeEw => c.WP_CURSOR_SHAPE_DEVICE_V1_SHAPE_EW_RESIZE,
        KoiWaylandCursorResizeNs => c.WP_CURSOR_SHAPE_DEVICE_V1_SHAPE_NS_RESIZE,
        KoiWaylandCursorResizeNwse => c.WP_CURSOR_SHAPE_DEVICE_V1_SHAPE_NWSE_RESIZE,
        KoiWaylandCursorResizeNesw => c.WP_CURSOR_SHAPE_DEVICE_V1_SHAPE_NESW_RESIZE,
        KoiWaylandCursorResizeAll => if (version >= 2)
            c.WP_CURSOR_SHAPE_DEVICE_V1_SHAPE_ALL_RESIZE
        else
            c.WP_CURSOR_SHAPE_DEVICE_V1_SHAPE_ALL_SCROLL,
        else => c.WP_CURSOR_SHAPE_DEVICE_V1_SHAPE_DEFAULT,
    };
}

fn applyCursorShape(window: *KoiWaylandWindow) void {
    const display = window.display orelse return;
    if (display.pointer_window != window or display.pointer_enter_serial == 0) {
        return;
    }
    const device = display.cursor_shape_device orelse return;
    c.wp_cursor_shape_device_v1_set_shape(
        device,
        display.pointer_enter_serial,
        protocolCursorShape(window.cursor_shape, display.cursor_shape_version),
    );
}

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
    const display: *KoiWaylandDisplay = @ptrCast(@alignCast(data orelse return));
    const window = pointerWindowForSurface(display, surface) orelse return;
    display.pointer_window = window;
    display.pointer_enter_serial = serial;
    applyCursorShape(window);
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
            display.pointer_enter_serial = 0;
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

fn resetXkbState(display: *KoiWaylandDisplay) void {
    if (display.xkb_state) |state| {
        c.xkb_state_unref(state);
        display.xkb_state = null;
    }
    if (display.xkb_keymap) |keymap| {
        c.xkb_keymap_unref(keymap);
        display.xkb_keymap = null;
    }
    display.mod_shift = c.XKB_MOD_INVALID;
    display.mod_ctrl = c.XKB_MOD_INVALID;
    display.mod_alt = c.XKB_MOD_INVALID;
    display.mod_super = c.XKB_MOD_INVALID;
    display.mods = 0;
    display.physical_mods = 0;
}

fn readKeymapFd(fd: i32, size: u32) ?[:0]u8 {
    const len: usize = @intCast(size);
    const keymap = allocator.allocSentinel(u8, len, 0) catch return null;

    var offset: usize = 0;
    while (offset < len) {
        const n = std.posix.read(fd, keymap[offset..len]) catch {
            allocator.free(keymap);
            return null;
        };
        if (n == 0) {
            break;
        }
        offset += n;
    }

    if (offset == 0) {
        allocator.free(keymap);
        return null;
    }
    return keymap;
}

fn updateModifierNames(display: *KoiWaylandDisplay) void {
    const keymap = display.xkb_keymap orelse return;
    display.mod_shift = c.xkb_keymap_mod_get_index(keymap, "Shift");
    display.mod_ctrl = c.xkb_keymap_mod_get_index(keymap, "Control");
    display.mod_alt = c.xkb_keymap_mod_get_index(keymap, "Mod1");
    display.mod_super = c.xkb_keymap_mod_get_index(keymap, "Mod4");
}

fn modifierActive(
    state: *c.struct_xkb_state,
    index: c.xkb_mod_index_t,
) bool {
    if (index == c.XKB_MOD_INVALID) {
        return false;
    }
    return c.xkb_state_mod_index_is_active(
        state,
        index,
        c.XKB_STATE_MODS_EFFECTIVE,
    ) != 0;
}

fn updateModifiers(display: *KoiWaylandDisplay) void {
    const state = display.xkb_state orelse {
        display.mods = display.physical_mods;
        return;
    };

    var mods: u32 = display.physical_mods;
    if (modifierActive(state, display.mod_shift)) {
        mods |= KoiWaylandModShift;
    }
    if (modifierActive(state, display.mod_ctrl)) {
        mods |= KoiWaylandModCtrl;
    }
    if (modifierActive(state, display.mod_alt)) {
        mods |= KoiWaylandModAlt;
    }
    if (modifierActive(state, display.mod_super)) {
        mods |= KoiWaylandModSuper;
    }
    display.mods = mods;
}

fn modifierForKeycode(key: u32) u32 {
    return switch (key) {
        42, 54 => KoiWaylandModShift,
        29, 97 => KoiWaylandModCtrl,
        56, 100 => KoiWaylandModAlt,
        125, 126 => KoiWaylandModSuper,
        else => 0,
    };
}

fn inferredModifiersForCodepoint(key: u32, codepoint: u32) u32 {
    if (codepoint >= 'A' and codepoint <= 'Z') {
        return KoiWaylandModShift;
    }
    return switch (key) {
        2 => if (codepoint == '!') KoiWaylandModShift else 0,
        3 => if (codepoint == '@') KoiWaylandModShift else 0,
        4 => if (codepoint == '#') KoiWaylandModShift else 0,
        5 => if (codepoint == '$') KoiWaylandModShift else 0,
        6 => if (codepoint == '%') KoiWaylandModShift else 0,
        7 => if (codepoint == '^') KoiWaylandModShift else 0,
        8 => if (codepoint == '&') KoiWaylandModShift else 0,
        9 => if (codepoint == '*') KoiWaylandModShift else 0,
        10 => if (codepoint == '(') KoiWaylandModShift else 0,
        11 => if (codepoint == ')') KoiWaylandModShift else 0,
        12 => if (codepoint == '_') KoiWaylandModShift else 0,
        13 => if (codepoint == '+') KoiWaylandModShift else 0,
        26 => if (codepoint == '{') KoiWaylandModShift else 0,
        27 => if (codepoint == '}') KoiWaylandModShift else 0,
        39 => if (codepoint == ':') KoiWaylandModShift else 0,
        40 => if (codepoint == '"') KoiWaylandModShift else 0,
        41 => if (codepoint == '~') KoiWaylandModShift else 0,
        43 => if (codepoint == '|') KoiWaylandModShift else 0,
        51 => if (codepoint == '<') KoiWaylandModShift else 0,
        52 => if (codepoint == '>') KoiWaylandModShift else 0,
        53 => if (codepoint == '?') KoiWaylandModShift else 0,
        else => 0,
    };
}

fn stopKeyRepeat(display: *KoiWaylandDisplay) void {
    display.repeat_key = 0;
    display.repeat_sym = 0;
    display.repeat_mods = 0;
    display.repeat_next_ms = 0;
    display.repeat_window = null;
}

fn startKeyRepeat(
    display: *KoiWaylandDisplay,
    window: *KoiWaylandWindow,
    key: u32,
    sym: u32,
    mods: u32,
) void {
    if (display.repeat_rate <= 0) {
        stopKeyRepeat(display);
        return;
    }

    display.repeat_key = key;
    display.repeat_sym = sym;
    display.repeat_mods = mods;
    display.repeat_next_ms = nowMs() + @as(i64, @intCast(@max(display.repeat_delay, 0)));
    display.repeat_window = window;
}

fn dispatchKeyRepeats(display: *KoiWaylandDisplay) void {
    const window = display.repeat_window orelse return;
    const on_key_repeat = window.callbacks.on_key_repeat orelse return;
    if (display.repeat_rate <= 0 or display.repeat_key == 0 or display.repeat_next_ms <= 0) {
        return;
    }

    const interval_ms = @max(@divTrunc(1000, display.repeat_rate), 1);
    var next = display.repeat_next_ms;
    const now = nowMs();
    while (now >= next) {
        on_key_repeat(display.repeat_sym, display.repeat_mods, window.callbacks.userdata);
        next += @as(i64, @intCast(interval_ms));
    }
    display.repeat_next_ms = next;
}

fn wlKeyboardKeymap(
    data: ?*anyopaque,
    wl_keyboard: ?*c.struct_wl_keyboard,
    format: u32,
    fd: i32,
    size: u32,
) callconv(.c) void {
    _ = wl_keyboard;
    defer _ = c.close(fd);

    const display: *KoiWaylandDisplay = @ptrCast(@alignCast(data orelse return));
    const context = display.xkb_context orelse return;
    if (format != @as(u32, c.WL_KEYBOARD_KEYMAP_FORMAT_XKB_V1)) {
        return;
    }

    const keymap_data = readKeymapFd(fd, size) orelse return;
    defer allocator.free(keymap_data);

    const keymap = c.xkb_keymap_new_from_string(
        context,
        keymap_data.ptr,
        c.XKB_KEYMAP_FORMAT_TEXT_V1,
        c.XKB_KEYMAP_COMPILE_NO_FLAGS,
    ) orelse return;
    const state = c.xkb_state_new(keymap) orelse {
        c.xkb_keymap_unref(keymap);
        return;
    };

    resetXkbState(display);
    display.xkb_keymap = keymap;
    display.xkb_state = state;
    updateModifierNames(display);
    updateModifiers(display);
}

fn wlKeyboardEnter(
    data: ?*anyopaque,
    wl_keyboard: ?*c.struct_wl_keyboard,
    serial: u32,
    surface: ?*c.struct_wl_surface,
    keys: ?*c.struct_wl_array,
) callconv(.c) void {
    _ = wl_keyboard;
    _ = serial;
    _ = keys;
    const display: *KoiWaylandDisplay = @ptrCast(@alignCast(data orelse return));
    display.keyboard_window = pointerWindowForSurface(display, surface);
    if (display.keyboard_window) |window| {
        if (window.callbacks.on_focus) |on_focus| {
            on_focus(true, window.callbacks.userdata);
        }
    }
}

fn wlKeyboardLeave(
    data: ?*anyopaque,
    wl_keyboard: ?*c.struct_wl_keyboard,
    serial: u32,
    surface: ?*c.struct_wl_surface,
) callconv(.c) void {
    _ = wl_keyboard;
    _ = serial;
    const display: *KoiWaylandDisplay = @ptrCast(@alignCast(data orelse return));
    if (display.keyboard_window) |window| {
        if (window.wl_surface == surface) {
            display.keyboard_window = null;
            stopKeyRepeat(display);
            display.physical_mods = 0;
            display.mods = 0;
            if (window.callbacks.on_focus) |on_focus| {
                on_focus(false, window.callbacks.userdata);
            }
        }
    }
}

fn wlKeyboardKey(
    data: ?*anyopaque,
    wl_keyboard: ?*c.struct_wl_keyboard,
    serial: u32,
    time: u32,
    key: u32,
    state: u32,
) callconv(.c) void {
    _ = wl_keyboard;
    _ = serial;
    _ = time;
    const display: *KoiWaylandDisplay = @ptrCast(@alignCast(data orelse return));
    const window = display.keyboard_window orelse display.active_window orelse return;
    const key_mod = modifierForKeycode(key);

    if (state == @as(u32, c.WL_KEYBOARD_KEY_STATE_PRESSED)) {
        display.physical_mods |= key_mod;
        updateModifiers(display);
        var codepoint: u32 = 0;
        if (display.xkb_state) |xkb_state| {
            codepoint = c.xkb_state_key_get_utf32(xkb_state, key + 8);
        }
        const event_mods = display.mods | key_mod | inferredModifiersForCodepoint(key, codepoint);
        if (window.callbacks.on_key_down) |on_key_down| {
            on_key_down(key, event_mods, window.callbacks.userdata);
        }
        if (window.callbacks.on_char) |on_char| {
            if (codepoint >= 32 and codepoint != 127) {
                on_char(codepoint, window.callbacks.userdata);
            }
        }
        startKeyRepeat(display, window, key, key, event_mods);
    } else if (state == @as(u32, c.WL_KEYBOARD_KEY_STATE_RELEASED)) {
        if (display.repeat_key == key) {
            stopKeyRepeat(display);
        }
        display.physical_mods &= ~key_mod;
        updateModifiers(display);
        const event_mods = display.mods & ~key_mod;
        if (window.callbacks.on_key_up) |on_key_up| {
            on_key_up(key, event_mods, window.callbacks.userdata);
        }
    }
}

fn wlKeyboardModifiers(
    data: ?*anyopaque,
    wl_keyboard: ?*c.struct_wl_keyboard,
    serial: u32,
    mods_depressed: u32,
    mods_latched: u32,
    mods_locked: u32,
    group: u32,
) callconv(.c) void {
    _ = wl_keyboard;
    _ = serial;
    const display: *KoiWaylandDisplay = @ptrCast(@alignCast(data orelse return));
    const state = display.xkb_state orelse return;
    _ = c.xkb_state_update_mask(
        state,
        mods_depressed,
        mods_latched,
        mods_locked,
        0,
        0,
        group,
    );
    updateModifiers(display);
}

fn wlKeyboardRepeatInfo(
    data: ?*anyopaque,
    wl_keyboard: ?*c.struct_wl_keyboard,
    rate: i32,
    delay: i32,
) callconv(.c) void {
    _ = wl_keyboard;
    const display: *KoiWaylandDisplay = @ptrCast(@alignCast(data orelse return));
    display.repeat_rate = rate;
    display.repeat_delay = delay;
    if (rate <= 0) {
        stopKeyRepeat(display);
    }
}

const wl_keyboard_listener = c.struct_wl_keyboard_listener{
    .keymap = wlKeyboardKeymap,
    .enter = wlKeyboardEnter,
    .leave = wlKeyboardLeave,
    .key = wlKeyboardKey,
    .modifiers = wlKeyboardModifiers,
    .repeat_info = wlKeyboardRepeatInfo,
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
    const window: *KoiWaylandWindow = @ptrCast(@alignCast(data orelse return));
    const surface = xdg_surface orelse return;
    c.xdg_surface_ack_configure(surface, serial);
    window.configured = true;
    if (window.has_pending_resize) {
        window.has_pending_resize = false;
        if (window.width != window.pending_width or window.height != window.pending_height) {
            window.width = window.pending_width;
            window.height = window.pending_height;
            if (window.callbacks.on_resize) |on_resize| {
                on_resize(window.width, window.height, window.callbacks.userdata);
            }
        }
    }
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
        window.pending_width = @intCast(width);
        window.pending_height = @intCast(height);
        window.has_pending_resize = true;
    }
}

fn xdgToplevelClose(
    data: ?*anyopaque,
    xdg_toplevel: ?*c.struct_xdg_toplevel,
) callconv(.c) void {
    _ = xdg_toplevel;
    const window: *KoiWaylandWindow = @ptrCast(@alignCast(data orelse return));
    window.closed = true;
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
    if (display.wl_keyboard) |keyboard| {
        c.wl_keyboard_destroy(keyboard);
    }
    if (display.cursor_shape_device) |device| {
        c.wp_cursor_shape_device_v1_destroy(device);
    }
    if (display.wl_pointer) |pointer| {
        c.wl_pointer_destroy(pointer);
    }
    if (display.wl_seat) |seat| {
        c.wl_seat_destroy(seat);
    }
    if (display.wl_output) |output| {
        c.wl_output_destroy(output);
    }
    if (display.xdg_wm_base) |wm_base| {
        c.xdg_wm_base_destroy(wm_base);
    }
    if (display.cursor_shape_manager) |manager| {
        c.wp_cursor_shape_manager_v1_destroy(manager);
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
    resetXkbState(display);
    if (display.xkb_context) |context| {
        c.xkb_context_unref(context);
        display.xkb_context = null;
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
        .wl_keyboard = null,
        .wl_output = null,
        .xdg_wm_base = null,
        .cursor_shape_manager = null,
        .cursor_shape_device = null,
        .cursor_shape_version = 0,
        .xkb_context = c.xkb_context_new(c.XKB_CONTEXT_NO_FLAGS),
        .xkb_keymap = null,
        .xkb_state = null,
        .mod_shift = c.XKB_MOD_INVALID,
        .mod_ctrl = c.XKB_MOD_INVALID,
        .mod_alt = c.XKB_MOD_INVALID,
        .mod_super = c.XKB_MOD_INVALID,
        .mods = 0,
        .physical_mods = 0,
        .output_scale = 1.0,
        .repeat_rate = 0,
        .repeat_delay = 0,
        .repeat_key = 0,
        .repeat_sym = 0,
        .repeat_mods = 0,
        .repeat_next_ms = 0,
        .repeat_window = null,
        .active_window = null,
        .pointer_window = null,
        .keyboard_window = null,
        .pointer_enter_serial = 0,
    };
    if (display.wl_display == null) {
        if (display.xkb_context) |context| {
            c.xkb_context_unref(context);
        }
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
    for (0..2) |_| {
        if (c.wl_display_roundtrip(display.wl_display.?) < 0) {
            destroyDisplayResources(display);
            allocator.destroy(display);
            return null;
        }
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
        .pending_width = w,
        .pending_height = h,
        .has_pending_resize = false,
        .configured = false,
        .closed = false,
        .cursor_shape = KoiWaylandCursorDefault,
        .scale = d.output_scale,
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
    notifyWindowScale(window, d.output_scale);

    return window;
}

export fn koi_wayland_set_callbacks(
    window: ?*KoiWaylandWindow,
    callbacks: ?*const anyopaque,
) void {
    const win = window orelse return;
    if (callbacks) |cb| {
        win.callbacks = @as(*const KoiWaylandCallbacks, @ptrCast(@alignCast(cb))).*;
        if (win.callbacks.on_scale) |on_scale| {
            on_scale(win.scale, win.callbacks.userdata);
        }
    } else {
        win.callbacks = std.mem.zeroes(KoiWaylandCallbacks);
    }
}

fn dispatchWaylandEvents(display: *KoiWaylandDisplay) void {
    const wl_display = display.wl_display orelse return;

    while (c.wl_display_dispatch_pending(wl_display) > 0) {}
    while (c.wl_display_prepare_read(wl_display) != 0) {
        if (c.wl_display_dispatch_pending(wl_display) < 0) {
            return;
        }
    }

    _ = c.wl_display_flush(wl_display);

    var pfd = c.struct_pollfd{
        .fd = c.wl_display_get_fd(wl_display),
        .events = c.POLLIN,
        .revents = 0,
    };
    const ready = c.poll(&pfd, 1, 0);
    if (ready > 0 and (pfd.revents & c.POLLIN) != 0) {
        if (c.wl_display_read_events(wl_display) == 0) {
            _ = c.wl_display_dispatch_pending(wl_display);
        }
    } else {
        c.wl_display_cancel_read(wl_display);
    }
}

export fn koi_wayland_poll_events(display: ?*KoiWaylandDisplay) void {
    const d = display orelse return;
    dispatchWaylandEvents(d);
    dispatchKeyRepeats(d);
    if (d.wl_display) |wl_display| {
        _ = c.wl_display_flush(wl_display);
    }
}

export fn koi_wayland_roundtrip(display: ?*KoiWaylandDisplay) void {
    const d = display orelse return;
    if (d.wl_display) |wl_display| {
        _ = c.wl_display_roundtrip(wl_display);
        dispatchKeyRepeats(d);
        _ = c.wl_display_flush(wl_display);
    }
}

export fn koi_wayland_get_wl_display(display: ?*KoiWaylandDisplay) ?*anyopaque {
    const d = display orelse return null;
    return d.wl_display;
}

export fn koi_wayland_get_wl_surface(window: ?*KoiWaylandWindow) ?*anyopaque {
    const w = window orelse return null;
    return w.wl_surface;
}

export fn koi_wayland_get_width(window: ?*KoiWaylandWindow) u32 {
    const w = window orelse return 0;
    return w.width;
}

export fn koi_wayland_get_height(window: ?*KoiWaylandWindow) u32 {
    const w = window orelse return 0;
    return w.height;
}

export fn koi_wayland_window_should_close(window: ?*KoiWaylandWindow) bool {
    const w = window orelse return true;
    return w.closed;
}

export fn koi_wayland_window_configured(window: ?*KoiWaylandWindow) bool {
    const w = window orelse return false;
    return w.configured;
}

export fn koi_wayland_set_title(window: ?*KoiWaylandWindow, title: [*:0]const u8) void {
    const win = window orelse return;
    if (win.xdg_toplevel) |toplevel| {
        c.xdg_toplevel_set_title(toplevel, title);
    }
}

export fn koi_wayland_set_app_id(window: ?*KoiWaylandWindow, app_id: [*:0]const u8) void {
    const win = window orelse return;
    if (win.xdg_toplevel) |toplevel| {
        c.xdg_toplevel_set_app_id(toplevel, app_id);
    }
}

export fn koi_wayland_set_size(window: ?*KoiWaylandWindow, w: u32, h: u32) void {
    const win = window orelse return;
    win.width = w;
    win.height = h;
}

export fn koi_wayland_set_size_limits(
    window: ?*KoiWaylandWindow,
    min_w: u32,
    min_h: u32,
    max_w: u32,
    max_h: u32,
) void {
    const win = window orelse return;
    if (win.xdg_toplevel) |toplevel| {
        c.xdg_toplevel_set_min_size(toplevel, @intCast(min_w), @intCast(min_h));
        c.xdg_toplevel_set_max_size(toplevel, @intCast(max_w), @intCast(max_h));
    }
}

export fn koi_wayland_set_cursor_shape(window: ?*KoiWaylandWindow, shape: u32) void {
    const win = window orelse return;
    win.cursor_shape = shape;
    applyCursorShape(win);
}

export fn koi_wayland_destroy_window(window: ?*KoiWaylandWindow) void {
    const win = window orelse return;
    if (win.display) |display| {
        if (display.pointer_window == win) {
            display.pointer_window = null;
        }
        if (display.keyboard_window == win) {
            display.keyboard_window = null;
        }
        if (display.repeat_window == win) {
            stopKeyRepeat(display);
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
