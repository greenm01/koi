import nanovg

import koi/backends/wayland
import koi/backends/wayland_wgpu
import koi/backends/wgpu_renderer

type AppState = object
  closed: bool
  width: uint32
  height: uint32

proc onClose(userdata: pointer) {.cdecl.} =
  let state = cast[ptr AppState](userdata)
  if state != nil:
    state.closed = true

proc onResize(w, h: uint32, userdata: pointer) {.cdecl.} =
  let state = cast[ptr AppState](userdata)
  if state != nil:
    state.width = w
    state.height = h

proc draw(vg: NVGContext, width, height: uint32) =
  let
    w = width.float
    h = height.float
    cardW = min(w - 48.0, 420.0)
    cardH = 180.0
    cardX = (w - cardW) * 0.5
    cardY = (h - cardH) * 0.5

  vg.beginFrame(w, h, 1.0)

  vg.beginPath()
  vg.rect(0, 0, w, h)
  vg.fillColor(rgb(0.12, 0.13, 0.14))
  vg.fill()

  vg.beginPath()
  vg.roundedRect(cardX, cardY, cardW, cardH, 8)
  vg.fillColor(rgb(0.20, 0.23, 0.26))
  vg.fill()

  vg.beginPath()
  vg.rect(cardX + 28, cardY + 34, cardW - 56, 28)
  vg.fillColor(rgb(0.20, 0.58, 0.78))
  vg.fill()

  vg.beginPath()
  vg.circle(cardX + 82, cardY + 116, 34)
  vg.fillColor(rgb(0.90, 0.42, 0.24))
  vg.fill()

  vg.beginPath()
  vg.roundedRect(cardX + 142, cardY + 88, cardW - 192, 56, 6)
  vg.fillColor(rgb(0.42, 0.68, 0.34))
  vg.fill()

  vg.endFrame()

when isMainModule:
  var state = AppState(closed: false, width: 640, height: 420)
  var callbacks =
    KoiWaylandCallbacks(onClose: onClose, onResize: onResize, userdata: addr state)

  let display = koiWaylandInit()
  if display == nil:
    echo "No Wayland display available; native Wayland wgpu example skipped."
    quit 0

  let window = koiWaylandCreateWindow(
    display, state.width, state.height, "Koi Native Wayland wgpu"
  )
  if window == nil:
    koiWaylandDestroy(display)
    quit "Could not create native Wayland window."

  koiWaylandSetCallbacks(window, addr callbacks)
  koiWaylandSetCursorShape(window, kwcDefault)

  var backend: KoiWgpuBackend
  let (surfaceW, surfaceH) = surfaceSize(window)
  backend.initKoiWgpuBackendWithSurface(
    wgpuSurfaceHandle(display, window), surfaceW, surfaceH
  )
  let vg = backend.createNanoVgContext({nifAntialias})

  while not state.closed and not koiWaylandWindowShouldClose(window):
    koiWaylandPollEvents(display)
    let (width, height) = surfaceSize(window)
    backend.resizeKoiWgpuBackend(width, height)
    draw(vg, width, height)

  deleteNanoVgContext(vg)
  koiWaylandDestroyWindow(window)
  koiWaylandDestroy(display)
