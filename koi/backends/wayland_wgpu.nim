import koi/backends/surface
import koi/backends/wayland

export surface.KoiWgpuSurfaceHandle

proc wgpuSurfaceHandle*(
    display: ptr KoiWaylandDisplay, window: ptr KoiWaylandWindow
): KoiWgpuSurfaceHandle =
  waylandSurfaceHandle(koiWaylandGetWlDisplay(display), koiWaylandGetWlSurface(window))

proc surfaceSize*(window: ptr KoiWaylandWindow): tuple[width, height: uint32] =
  (koiWaylandGetWidth(window), koiWaylandGetHeight(window))
