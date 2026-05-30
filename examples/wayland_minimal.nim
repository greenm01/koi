import koi/backends/wayland
import koi/backends/wayland_keys
from koi/types import keyC, keyQ

type AppState = object
  closed: bool

proc quitShortcut(keycode, mods: uint32): bool =
  let key = waylandKeycode(keycode)
  (mods and koiWaylandModCtrl) != 0 and (key == keyQ or key == keyC)

proc onClose(userdata: pointer) {.cdecl.} =
  let state = cast[ptr AppState](userdata)
  if state != nil:
    state.closed = true

proc onKeyDown(keycode, mods: uint32, userdata: pointer) {.cdecl.} =
  let state = cast[ptr AppState](userdata)
  if state != nil and quitShortcut(keycode, mods):
    state.closed = true

proc onResize(w, h: uint32, userdata: pointer) {.cdecl.} =
  discard w
  discard h
  discard userdata

when isMainModule:
  var state = AppState(closed: false)
  var callbacks = KoiWaylandCallbacks(
    onClose: onClose,
    onResize: onResize,
    onKeyDown: onKeyDown,
    onKeyRepeat: onKeyDown,
    userdata: addr state,
  )

  let display = koiWaylandInit()
  if display == nil:
    echo "No Wayland display available; native Wayland smoke skipped."
    quit 0

  let window = koiWaylandCreateWindow(display, 640, 420, "Koi Native Wayland")
  if window == nil:
    koiWaylandDestroy(display)
    quit "Could not create native Wayland window."

  koiWaylandSetCallbacks(window, addr callbacks)
  koiWaylandSetTitle(window, "Koi Native Wayland")
  koiWaylandSetSize(window, 640, 420)
  koiWaylandSetCursorShape(window, kwcDefault)

  if koiWaylandGetWlDisplay(display) == nil:
    koiWaylandDestroyWindow(window)
    koiWaylandDestroy(display)
    quit "Wayland display handle was nil."
  if koiWaylandGetWlSurface(window) == nil:
    koiWaylandDestroyWindow(window)
    koiWaylandDestroy(display)
    quit "Wayland surface handle was nil."

  for _ in 0 ..< 3:
    if state.closed or koiWaylandWindowShouldClose(window):
      break
    koiWaylandPollEvents(display)

  koiWaylandDestroyWindow(window)
  koiWaylandDestroy(display)
