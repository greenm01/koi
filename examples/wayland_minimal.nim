import koi/backends/wayland

proc onClose(userdata: pointer) {.cdecl.} =
  let closed = cast[ptr bool](userdata)
  if closed != nil:
    closed[] = true

proc onResize(w, h: uint32, userdata: pointer) {.cdecl.} =
  discard w
  discard h
  discard userdata

when isMainModule:
  var closed = false
  var callbacks =
    KoiWaylandCallbacks(onClose: onClose, onResize: onResize, userdata: addr closed)

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
    if closed or koiWaylandWindowShouldClose(window):
      break
    koiWaylandPollEvents(display)

  koiWaylandDestroyWindow(window)
  koiWaylandDestroy(display)
