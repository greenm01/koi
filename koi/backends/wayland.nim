type
  KoiWaylandDisplay* {.
    importc, incompleteStruct, header: "koi_wayland.h"
  .} = object
  KoiWaylandWindow* {.
    importc, incompleteStruct, header: "koi_wayland.h"
  .} = object

  KoiWaylandCallbacks* {.
    bycopy, importc, header: "koi_wayland.h"
  .} = object
    onClose*: proc(userdata: pointer) {.cdecl.}
    onResize*: proc(w, h: uint32, userdata: pointer) {.cdecl.}
    onKeyDown*: proc(sym, mods: uint32, userdata: pointer) {.cdecl.}
    onKeyUp*: proc(sym, mods: uint32, userdata: pointer) {.cdecl.}
    onMouseMove*: proc(x, y: cdouble, userdata: pointer) {.cdecl.}
    onMouseButton*: proc(btn: uint32, pressed: bool, userdata: pointer) {.cdecl.}
    onScroll*: proc(dx, dy: cdouble, userdata: pointer) {.cdecl.}
    onScale*: proc(scale: cdouble, userdata: pointer) {.cdecl.}
    userdata*: pointer

proc koiWaylandInit*(): ptr KoiWaylandDisplay {.
  cdecl, importc: "koi_wayland_init", header: "koi_wayland.h".}

proc koiWaylandCreateWindow*(
  display: ptr KoiWaylandDisplay,
  w, h: uint32,
  title: cstring,
): ptr KoiWaylandWindow {.
  cdecl, importc: "koi_wayland_create_window", header: "koi_wayland.h".}

proc koiWaylandSetCallbacks*(
  window: ptr KoiWaylandWindow,
  callbacks: ptr KoiWaylandCallbacks,
) {.cdecl, importc: "koi_wayland_set_callbacks", header: "koi_wayland.h".}

proc koiWaylandPollEvents*(display: ptr KoiWaylandDisplay) {.
  cdecl, importc: "koi_wayland_poll_events", header: "koi_wayland.h".}

proc koiWaylandGetWlDisplay*(display: ptr KoiWaylandDisplay): pointer {.
  cdecl, importc: "koi_wayland_get_wl_display", header: "koi_wayland.h".}

proc koiWaylandGetWlSurface*(window: ptr KoiWaylandWindow): pointer {.
  cdecl, importc: "koi_wayland_get_wl_surface", header: "koi_wayland.h".}

proc koiWaylandSetTitle*(window: ptr KoiWaylandWindow, title: cstring) {.
  cdecl, importc: "koi_wayland_set_title", header: "koi_wayland.h".}

proc koiWaylandSetSize*(window: ptr KoiWaylandWindow, w, h: uint32) {.
  cdecl, importc: "koi_wayland_set_size", header: "koi_wayland.h".}

proc koiWaylandDestroyWindow*(window: ptr KoiWaylandWindow) {.
  cdecl, importc: "koi_wayland_destroy_window", header: "koi_wayland.h".}

proc koiWaylandDestroy*(display: ptr KoiWaylandDisplay) {.
  cdecl, importc: "koi_wayland_destroy", header: "koi_wayland.h".}
