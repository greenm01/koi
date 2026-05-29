import glfw
from glfw/wrapper import nil

import koi/backends/surface

{.
  emit:
    """
#if defined(_WIN32)
  #define GLFW_EXPOSE_NATIVE_WIN32
#elif defined(__APPLE__)
  #define GLFW_EXPOSE_NATIVE_COCOA
  #include <objc/message.h>
  #include <objc/runtime.h>
#endif

#include <GLFW/glfw3.h>
#if !defined(__linux__)
#include <GLFW/glfw3native.h>
#endif

#if defined(_WIN32)
static void* koi_glfw_get_win32_window(void* window) {
  return glfwGetWin32Window((GLFWwindow*)window);
}
#elif defined(__APPLE__)
static void* koi_glfw_get_cocoa_window(void* window) {
  return glfwGetCocoaWindow((GLFWwindow*)window);
}
#endif

#if defined(__APPLE__)
static void* koi_glfw_create_metal_layer(void* ns_window) {
  id window = (id)ns_window;
  SEL contentViewSel = sel_registerName("contentView");
  SEL layerSel = sel_registerName("layer");
  SEL setWantsLayerSel = sel_registerName("setWantsLayer:");
  SEL setLayerSel = sel_registerName("setLayer:");

  id contentView = ((id (*)(id, SEL))objc_msgSend)(window, contentViewSel);
  Class metalLayerClass = objc_getClass("CAMetalLayer");
  id layer = ((id (*)(Class, SEL))objc_msgSend)(metalLayerClass, layerSel);

  ((void (*)(id, SEL, signed char))objc_msgSend)(contentView, setWantsLayerSel, 1);
  ((void (*)(id, SEL, id))objc_msgSend)(contentView, setLayerSel, layer);

  return layer;
}
#endif
"""
.}

when defined(linux):
  when defined(wayland):
    proc getWaylandDisplay(): pointer {.cdecl, importc: "glfwGetWaylandDisplay", dynlib: "libglfw.so.3".}
    proc getWaylandWindow(win: pointer): pointer {.cdecl, importc: "glfwGetWaylandWindow", dynlib: "libglfw.so.3".}
  else:
    proc getX11Display(): pointer {.cdecl, importc: "glfwGetX11Display", dynlib: "libglfw.so.3".}
    proc getX11Window(win: pointer): culong {.cdecl, importc: "glfwGetX11Window", dynlib: "libglfw.so.3".}
elif defined(windows):
  proc getWin32Window(win: pointer): pointer {.cdecl, importc: "koi_glfw_get_win32_window".}
  proc getModuleHandle(lpModuleName: cstring): pointer {.importc: "GetModuleHandleW", stdcall, dynlib: "kernel32".}
elif defined(macosx):
  {.passL: "-framework Cocoa -framework Metal -framework QuartzCore -lobjc".}
  proc getCocoaWindow(win: pointer): pointer {.cdecl, importc: "koi_glfw_get_cocoa_window".}
  proc createMetalLayer(nsWindow: pointer): pointer {.cdecl, importc: "koi_glfw_create_metal_layer".}

proc defaultWgpuWindowConfig*(
    title = "Koi wgpu", width = 640, height = 480
): OpenglWindowConfig =
  result = DefaultOpenglWindowConfig
  result.title = title
  result.size = (w: width.int32, h: height.int32)
  result.makeContextCurrent = false
  result.resizable = true

proc newWgpuWindow*(cfg: OpenglWindowConfig; callbacks = true): Window =
  if callbacks:
    return newWindow(cfg)

  template hint(name, value: untyped) =
    wrapper.windowHint(name.int32, value.int32)

  wrapper.defaultWindowHints()
  hint(wrapper.hClientApi, wrapper.oaNoApi)
  hint(wrapper.hVisible, cfg.visible)
  hint(wrapper.hResizable, cfg.resizable)
  hint(wrapper.hDecorated, cfg.decorated)
  hint(wrapper.hFloating, cfg.floating)
  hint(wrapper.hTransparentFramebuffer, cfg.transparentFramebuffer)
  hint(wrapper.hFocusOnShow, cfg.focusOnShow)
  hint(wrapper.hMousePassthrough, cfg.mousePassthrough)
  when defined(windows):
    hint(wrapper.hHideFromTaskbar, cfg.hideFromTaskbar)

  let handle = wrapper.createWindow(
    cfg.size.w,
    cfg.size.h,
    cstring(cfg.title),
    nil,
    nil,
  )
  if handle.isNil:
    raise newException(CatchableError, "Could not create GLFW wgpu window")
  result = glfw.newWindow(handle)

proc surfaceSize*(win: Window): tuple[width, height: uint32] =
  let
    (winWidth, winHeight) = win.size
    (fbWidth, fbHeight) = win.framebufferSize
    (xscale, yscale) = win.contentScale
    width = max(fbWidth, (winWidth.float * xscale + 0.5).int)
    height = max(fbHeight, (winHeight.float * yscale + 0.5).int)

  (width.uint32, height.uint32)

proc wgpuSurfaceHandle*(win: Window): KoiWgpuSurfaceHandle =
  when defined(linux) and defined(wayland):
    waylandSurfaceHandle(
      getWaylandDisplay(),
      getWaylandWindow(cast[pointer](win.getHandle())),
    )
  elif defined(linux):
    x11SurfaceHandle(
      getX11Display(),
      getX11Window(cast[pointer](win.getHandle())).uint64,
    )
  elif defined(windows):
    windowsHwndSurfaceHandle(
      getWin32Window(cast[pointer](win.getHandle())),
      getModuleHandle(nil),
    )
  elif defined(macosx):
    metalLayerSurfaceHandle(
      createMetalLayer(getCocoaWindow(cast[pointer](win.getHandle())))
    )
  else:
    {.error: "Koi WebGPU GLFW surfaces are not implemented for this platform".}
