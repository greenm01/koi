import wgpu
import wgpu/extras/helpers
import wgpu/extras/strings

type
  KoiWgpuSurfaceKind* = enum
    kwskWayland
    kwskX11
    kwskMetalLayer
    kwskWindowsHwnd

  KoiWgpuSurfaceHandle* = object
    case kind*: KoiWgpuSurfaceKind
    of kwskWayland:
      wlDisplay*: pointer
      wlSurface*: pointer
    of kwskX11:
      x11Display*: pointer
      x11Window*: uint64
    of kwskMetalLayer:
      metalLayer*: pointer
    of kwskWindowsHwnd:
      hwnd*: pointer
      hinstance*: pointer

func waylandSurfaceHandle*(display, surface: pointer): KoiWgpuSurfaceHandle =
  KoiWgpuSurfaceHandle(kind: kwskWayland, wlDisplay: display, wlSurface: surface)

func x11SurfaceHandle*(display: pointer, window: uint64): KoiWgpuSurfaceHandle =
  KoiWgpuSurfaceHandle(kind: kwskX11, x11Display: display, x11Window: window)

func metalLayerSurfaceHandle*(layer: pointer): KoiWgpuSurfaceHandle =
  KoiWgpuSurfaceHandle(kind: kwskMetalLayer, metalLayer: layer)

func windowsHwndSurfaceHandle*(hwnd, hinstance: pointer): KoiWgpuSurfaceHandle =
  KoiWgpuSurfaceHandle(kind: kwskWindowsHwnd, hwnd: hwnd, hinstance: hinstance)

proc createSurface*(instance: Instance, handle: KoiWgpuSurfaceHandle): Surface =
  case handle.kind
  of kwskWayland:
    result = instance.create(
      vaddr SurfaceDescriptor(
        label: "Koi WebGPU Wayland surface".toStringView(),
        nextInChain: cast[ptr ChainedStruct](vaddr SurfaceSourceWaylandSurface(
          chain: ChainedStruct(next: nil, sType: SType.SurfaceSourceWaylandSurface),
          display: handle.wlDisplay,
          surface: handle.wlSurface,
        )),
      )
    )
  of kwskX11:
    raise newException(CatchableError, "Koi WebGPU X11 surfaces are not implemented yet")
  of kwskMetalLayer:
    raise newException(
      CatchableError, "Koi WebGPU Metal layer surfaces are not implemented yet"
    )
  of kwskWindowsHwnd:
    raise newException(
      CatchableError, "Koi WebGPU Win32 HWND surfaces are not implemented yet"
    )
