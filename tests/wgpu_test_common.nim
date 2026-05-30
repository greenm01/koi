## Windowed integration harness: brings up a hidden WebGPU window + NanoVG
## context (the real app backend) so widgets that measure glyphs or capture the
## cursor can be driven for real. Importing this module performs the one-time
## setup; it re-exports widget_test_common so a windowed test file needs only
## this single import.
##
## Build with the wgpu flags (see the `testWindow*` nimble tasks). These tests
## need a GPU/display, unlike the pure-headless suites.
##
## IMPORTANT: we never call koi.beginFrame here -- it overwrites mx/my with the
## real cursor position, which would clobber our synthetic input. We keep a
## single NanoVG frame open for glyph measurement and drive widgets directly,
## exactly like the headless harness.

import std/os

import glfw
import nanovg

import koi/drawing
import koi/layout
import koi/types as koi_types
import koi/backends/glfw_wgpu
import koi/webgpu_backend

import widget_test_common
export widget_test_common

var
  gVg*: NVGContext
  gBackend*: KoiWgpuBackend
  gWin*: koi_types.Window

proc setupWgpuWindow() =
  if not gVg.isNil:
    return
  glfw.initialize()
  var cfg = defaultWgpuWindowConfig("koi-test", 400, 300)
  cfg.visible = false
  gWin = newWgpuWindow(cfg, callbacks = false)
  useWindow(gWin)
  let (w, h) = gWin.surfaceSize()
  gBackend.initKoiWgpuBackendWithSurface(gWin.wgpuSurfaceHandle(), w, h)
  gVg = gBackend.createNanoVgContext({nifAntialias})
  init(gVg, glfw.getProcAddress)

  let dataDir = currentSourcePath().parentDir().parentDir() / "data"
  doAssert gVg.createFont("sans", dataDir / "Roboto-Regular.ttf") != NoFont
  doAssert gVg.createFont("sans-bold", dataDir / "Roboto-Bold.ttf") != NoFont

  # Keep one frame open so text measurement (textGlyphPositions) works. We never
  # endFrame, so no rendering/surface-present happens.
  gVg.beginFrame(400, 300, 1.0)

proc measureTextRows*(
    text: string, width: float, fontSize: float = 14.0, fontFace: string = "sans"
): seq[koi_types.TextRow] =
  ## Use the live NanoVG context to produce the same wrapped rows textArea uses.
  gVg.useFont(fontSize, name = fontFace)
  text.textBreakLines(width)

proc measureRowGlyphs*(
    text: string,
    row: koi_types.TextRow,
    fontSize: float = 14.0,
    fontFace: string = "sans",
): seq[GlyphPosition] =
  let rowEnd = textAreaRowEndCursor(row)
  if rowEnd <= row.startPos:
    return @[]

  var glyphs: array[1024, GlyphPosition]
  gVg.useFont(fontSize, name = fontFace)
  let count = gVg.textGlyphPositions(
    0, 0, text, startPos = row.startBytePos, endPos = row.endBytePos, glyphs
  )
  for i in 0 ..< count:
    result.add(glyphs[i])

template renderOneFrame*(body: untyped) =
  ## Flush a small widget tree through layout solving and queued draw commands
  ## inside the live hidden NanoVG frame.
  resetUi()
  g_uiState.winWidth = 400
  g_uiState.winHeight = 300
  g_uiState.hitClipRect = rect(0, 0, 400, 300)
  g_uiState.drawOffsetStack = @[DrawOffset(ox: 0, oy: 0)]
  g_drawLayers.init()
  beginFrameLayout()
  body
  finishFrameLayout()
  g_drawLayers.draw(gVg)
  g_drawLayers.init()

# Enter the edit state of a text field by pressing then releasing inside it.
# Leaves the field active in edit mode with the whole value selected (the
# widget's select-all-on-focus behaviour).
template focusTextField*(id: ItemId, x, y, w, h: float, text: var string) =
  pressLeftAt(x + 4, y + h * 0.5)
  textField(id, x, y, w, h, text)
  releaseLeft()
  textField(id, x, y, w, h, text)

setupWgpuWindow()
