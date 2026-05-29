type
  KoiWaylandDisplay* {.importc, incompleteStruct, header: "koi_wayland.h".} = object

  KoiWaylandWindow* {.importc, incompleteStruct, header: "koi_wayland.h".} = object

const
  koiWaylandModShift* = 1'u32 shl 0
  koiWaylandModCtrl* = 1'u32 shl 1
  koiWaylandModAlt* = 1'u32 shl 2
  koiWaylandModSuper* = 1'u32 shl 3

type KoiWaylandCallbacks* {.bycopy, importc, header: "koi_wayland.h".} = object
  onClose* {.importc: "on_close".}: proc(userdata: pointer) {.cdecl.}
  onResize* {.importc: "on_resize".}: proc(w, h: uint32, userdata: pointer) {.cdecl.}
  onKeyDown* {.importc: "on_key_down".}:
    proc(sym, mods: uint32, userdata: pointer) {.cdecl.}
  onKeyUp* {.importc: "on_key_up".}:
    proc(sym, mods: uint32, userdata: pointer) {.cdecl.}
  onMouseMove* {.importc: "on_mouse_move".}:
    proc(x, y: cdouble, userdata: pointer) {.cdecl.}
  onMouseButton* {.importc: "on_mouse_button".}:
    proc(btn: uint32, pressed: bool, userdata: pointer) {.cdecl.}
  onScroll* {.importc: "on_scroll".}: proc(dx, dy: cdouble, userdata: pointer) {.cdecl.}
  onScale* {.importc: "on_scale".}: proc(scale: cdouble, userdata: pointer) {.cdecl.}
  userdata*: pointer

proc koiWaylandInit*(): ptr KoiWaylandDisplay {.
  cdecl, importc: "koi_wayland_init", header: "koi_wayland.h"
.}

proc koiWaylandCreateWindow*(
  display: ptr KoiWaylandDisplay, w, h: uint32, title: cstring
): ptr KoiWaylandWindow {.
  cdecl, importc: "koi_wayland_create_window", header: "koi_wayland.h"
.}

proc koiWaylandSetCallbacks*(
  window: ptr KoiWaylandWindow, callbacks: ptr KoiWaylandCallbacks
) {.cdecl, importc: "koi_wayland_set_callbacks", header: "koi_wayland.h".}

proc koiWaylandPollEvents*(
  display: ptr KoiWaylandDisplay
) {.cdecl, importc: "koi_wayland_poll_events", header: "koi_wayland.h".}

proc koiWaylandGetWlDisplay*(
  display: ptr KoiWaylandDisplay
): pointer {.cdecl, importc: "koi_wayland_get_wl_display", header: "koi_wayland.h".}

proc koiWaylandGetWlSurface*(
  window: ptr KoiWaylandWindow
): pointer {.cdecl, importc: "koi_wayland_get_wl_surface", header: "koi_wayland.h".}

proc koiWaylandGetWidth*(
  window: ptr KoiWaylandWindow
): uint32 {.cdecl, importc: "koi_wayland_get_width", header: "koi_wayland.h".}

proc koiWaylandGetHeight*(
  window: ptr KoiWaylandWindow
): uint32 {.cdecl, importc: "koi_wayland_get_height", header: "koi_wayland.h".}

proc koiWaylandSetTitle*(
  window: ptr KoiWaylandWindow, title: cstring
) {.cdecl, importc: "koi_wayland_set_title", header: "koi_wayland.h".}

proc koiWaylandSetSize*(
  window: ptr KoiWaylandWindow, w, h: uint32
) {.cdecl, importc: "koi_wayland_set_size", header: "koi_wayland.h".}

proc koiWaylandDestroyWindow*(
  window: ptr KoiWaylandWindow
) {.cdecl, importc: "koi_wayland_destroy_window", header: "koi_wayland.h".}

proc koiWaylandDestroy*(
  display: ptr KoiWaylandDisplay
) {.cdecl, importc: "koi_wayland_destroy", header: "koi_wayland.h".}
