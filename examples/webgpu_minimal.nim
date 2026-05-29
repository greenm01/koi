import std/os
import std/options
import std/strformat

import glfw
from glfw/wrapper import nil
import nanovg

import koi
import koi/backends/surface
import koi/backends/wgpu_renderer

{.
  emit:
    """
#define GLFW_EXPOSE_NATIVE_WAYLAND
#include <GLFW/glfw3.h>
#include <GLFW/glfw3native.h>
"""
.}

proc glfwGetWaylandDisplay(): pointer {.cdecl, importc, dynlib: "libglfw.so.3".}
proc glfwGetWaylandWindow(
  win: wrapper.Window
): pointer {.cdecl, importc, dynlib: "libglfw.so.3".}

var
  vg: NVGContext
  backend: KoiWgpuBackend
  sliderValue = 42.0
  enabled = true
  textValue = "WebGPU scissor clips this deliberately long text field value"

proc createWindow(): Window =
  var cfg = DefaultOpenglWindowConfig
  cfg.size = (w: 900, h: 560)
  cfg.title = "Koi WebGPU"
  cfg.resizable = true
  cfg.visible = true
  cfg.bits = (
    r: 8'i32.some,
    g: 8'i32.some,
    b: 8'i32.some,
    a: 8'i32.some,
    stencil: 8'i32.some,
    depth: 16'i32.some,
  )
  cfg.makeContextCurrent = false
  newWindow(cfg)

proc surfaceSize(win: Window): tuple[width, height: uint32] =
  let
    (winWidth, winHeight) = win.size
    (fbWidth, fbHeight) = win.framebufferSize
    (xscale, yscale) = win.contentScale
    width = max(fbWidth, (winWidth.float * xscale + 0.5).int)
    height = max(fbHeight, (winHeight.float * yscale + 0.5).int)

  (width.uint32, height.uint32)

proc loadData(vg: NVGContext) =
  let dataDir = currentSourcePath().parentDir().parentDir() / "data"

  let regular = vg.createFont("sans", dataDir / "Roboto-Regular.ttf")
  if regular == NoFont:
    quit "Could not load regular font."

  let bold = vg.createFont("sans-bold", dataDir / "Roboto-Bold.ttf")
  if bold == NoFont:
    quit "Could not load bold font."

proc renderUi() =
  beginFrame()

  vg.beginPath()
  vg.rect(0, 0, winWidth(), winHeight())
  vg.fillColor(rgb(0.16, 0.17, 0.18))
  vg.fill()

  var titleStyle = defaultLabelStyle()
  titleStyle.fontSize = 20
  titleStyle.color = rgb(0.92, 0.94, 0.96)

  var labelStyle = defaultLabelStyle()
  labelStyle.color = rgb(0.80, 0.84, 0.88)

  let
    x = 72.0
    w = 220.0
    h = 24.0

  label(x, 52, 420, h, "Koi running on webgpu-nim", style = titleStyle)
  label(x, 90, 360, h, "This is the opt-in WebGPU path.", style = labelStyle)

  if button(x, 132, 120, h, "Button"):
    echo "button pressed"

  toggleButton(x, 172, 120, h, enabled, "Off", "On")

  horizSlider(x, 220, w, h, 0, 100, sliderValue)
  label(x + w + 18, 220, 120, h, fmt"{sliderValue:.1f}", style = labelStyle)

  textField(x, 268, w, h, textValue)
  label(
    x,
    314,
    420,
    h,
    "Text, buttons, sliders, and input all use Koi APIs.",
    style = labelStyle,
  )

  let
    clipX = 360.0
    clipY = 132.0
    clipW = 260.0
    clipH = 142.0

  vg.beginPath()
  vg.roundedRect(clipX - 6, clipY - 6, clipW + 12, clipH + 12, 4)
  vg.fillColor(rgb(0.11, 0.12, 0.13))
  vg.fill()

  vg.save()
  vg.intersectScissor(clipX, clipY, clipW, clipH)

  vg.beginPath()
  vg.rect(clipX - 80, clipY + 18, clipW + 180, 34)
  vg.fillColor(rgb(0.82, 0.22, 0.20))
  vg.fill()

  vg.beginPath()
  vg.rect(clipX + 42, clipY + 66, clipW + 130, 34)
  vg.fillColor(rgb(0.95, 0.70, 0.20))
  vg.fill()

  vg.beginPath()
  vg.circle(clipX + clipW + 4, clipY + 114, 38)
  vg.fillColor(rgb(0.18, 0.58, 0.82))
  vg.fill()

  vg.restore()

  vg.beginPath()
  vg.roundedRect(clipX, clipY, clipW, clipH, 3)
  vg.strokeWidth(1)
  vg.strokeColor(rgb(0.68, 0.72, 0.76))
  vg.stroke()

  label(
    clipX,
    clipY + clipH + 12,
    clipW,
    h,
    "Scissor: shapes should stop at the border.",
    style = labelStyle,
  )

  endFrame()

when isMainModule:
  glfw.initialize()
  let win = createWindow()
  useWindow(win)

  let
    display = glfwGetWaylandDisplay()
    wlSurface = glfwGetWaylandWindow(win.getHandle())
    (width, height) = win.surfaceSize()

  backend.initKoiWgpuBackendWithSurface(
    waylandSurfaceHandle(display, wlSurface),
    width.uint32,
    height.uint32,
  )
  vg = backend.createNanoVgContext({nifAntialias})
  init(vg, glfw.getProcAddress)
  loadData(vg)

  while not win.shouldClose:
    glfw.pollEvents()
    let (width, height) = win.surfaceSize()
    backend.resizeKoiWgpuBackend(width, height)
    renderUi()

  deleteNanoVgContext(vg)
  win.destroy()
  glfw.terminate()
