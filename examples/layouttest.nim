import std/lenientops
import std/options

import glad/gl
import glfw
from glfw/wrapper import showWindow
import nanovg

import koi

# Global NanoVG context
var vg: NVGContext

proc createWindow(): Window =
  var cfg = DefaultOpenglWindowConfig
  cfg.size = (w: 800, h: 600)
  cfg.title = "Koi Layout Test"
  cfg.resizable = true
  cfg.visible = true
  cfg.nMultiSamples = 4
  newWindow(cfg)

proc loadData(vg: NVGContext) =
  # Assuming Roboto-Regular.ttf exists in data/ as in test.nim
  discard vg.createFont("sans", "data/Roboto-Regular.ttf")

proc renderUI() =
  koi.beginFrame()
  
  # Standard auto-layout
  label("Standard Auto-layout:")
  if button("Standard Button"): echo "Standard Button clicked"
  
  label("Hierarchical Layout (Row 30px, Static 150 + Dynamic):")
  layoutRow(30.0):
    col(150.0):
      if button("Static 150"): echo "Static Button clicked"
    colDynamic():
      if button("Dynamic"): echo "Dynamic Button clicked"

  label("Hierarchical Layout (Row 30px, 3x Ratio 0.33):")
  layoutRow(30.0):
    colRatio(0.33):
      if button("Ratio 1"): echo "Ratio 1 clicked"
    colRatio(0.33):
      if button("Ratio 2"): echo "Ratio 2 clicked"
    colRatio(0.33):
      if button("Ratio 3"): echo "Ratio 3 clicked"

  label("Layout Space (200px height):")
  layoutSpace(200.0):
    # Absolute positioning relative to the space
    label(20, 20, 100, 20, "At 20,20")
    if button(150, 50, 100, 30, "At 150,50"): echo "Space Button clicked"

  koi.endFrame()

proc renderFrame(win: Window) =
  if win.iconified: return
  
  let size = win.size
  glViewport(0, 0, size.w.int32, size.h.int32)
  glClearColor(0.2, 0.2, 0.2, 1.0)
  glClear(GL_COLOR_BUFFER_BIT or GL_STENCIL_BUFFER_BIT)

  vg.beginFrame(size.w.float, size.h.float, 1.0)
  renderUI()
  vg.endFrame()
  
  win.swapBuffers()

proc main() =
  glfw.initialize()
  let win = createWindow()
  win.makeContextCurrent()

  if not gladLoadGL(glfw.getProcAddress):
    quit "Failed to load GL"

  vg = nvgCreateContext({nifStencilStrokes, nifAntialias})
  loadData(vg)

  koi.init(vg, glfw.getProcAddress)
  initAutoLayout(DefaultAutoLayoutParams)

  while not win.shouldClose:
    if koi.shouldRenderNextFrame():
      glfw.pollEvents()
    else:
      glfw.waitEvents()
    renderFrame(win)

  koi.deinit()
  nvgDeleteContext(vg)
  glfw.terminate()

main()
