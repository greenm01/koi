## Windowed WebGPU renderer validation. These tests render through the real
## NanoVG backend into an offscreen readback texture and assert sampled pixels.

import std/strutils

import nanovg

import koi/webgpu_backend
import wgpu_test_common

type Pixel = object
  r, g, b, a: uint8

gVg.cancelFrame()

proc pixelAt(pixels: openArray[uint8], width, x, y: int): Pixel =
  let i = (y * width + x) * 4
  Pixel(r: pixels[i], g: pixels[i + 1], b: pixels[i + 2], a: pixels[i + 3])

proc drawRect(x, y, w, h: float, color: Color) =
  gVg.beginPath()
  gVg.rect(x, y, w, h)
  gVg.fillColor(color)
  gVg.fill()

proc drawRoundedRectWithStroke(x, y, w, h, radius: float, fill, stroke: Color) =
  gVg.beginPath()
  gVg.roundedRect(x, y, w, h, radius)
  gVg.fillColor(fill)
  gVg.strokeColor(stroke)
  gVg.strokeWidth(1)
  gVg.fill()
  gVg.stroke()

proc drawRectWithHole(x, y, w, h: float, hx, hy, hw, hh: float, color: Color) =
  gVg.beginPath()
  gVg.rect(x, y, w, h)
  gVg.rect(hx, hy, hw, hh)
  gVg.pathWinding(sHole)
  gVg.fillColor(color)
  gVg.fill()

proc drawTrianglePath(x1, y1, x2, y2, x3, y3: float) =
  gVg.beginPath()
  gVg.moveTo(x1, y1)
  gVg.lineTo(x2, y2)
  gVg.lineTo(x3, y3)
  gVg.closePath()

proc drawHsvTriangleLikePaint() =
  let
    x1 = 32.0
    y1 = 52.0
    x2 = 14.0
    y2 = 12.0
    x3 = 50.0
    y3 = 12.0

  drawTrianglePath(x1, y1, x2, y2, x3, y3)
  var paint =
    gVg.linearGradient(x3, y3, x2, y2, rgba(255, 0, 0, 255), rgba(255, 255, 255, 255))
  gVg.fillPaint(paint)
  gVg.fill()

  drawTrianglePath(x1, y1, x2, y2, x3, y3)
  paint = gVg.linearGradient(
    x1, y1, (x2 + x3) * 0.5, (y2 + y3) * 0.5, rgba(0, 0, 0, 255), rgba(0, 0, 0, 0)
  )
  gVg.fillPaint(paint)
  gVg.fill()

proc drawConcaveNotch(color: Color) =
  gVg.beginPath()
  gVg.moveTo(8, 8)
  gVg.lineTo(56, 8)
  gVg.lineTo(56, 56)
  gVg.lineTo(40, 56)
  gVg.lineTo(40, 24)
  gVg.lineTo(24, 24)
  gVg.lineTo(24, 56)
  gVg.lineTo(8, 56)
  gVg.closePath()
  gVg.fillColor(color)
  gVg.fill()

template capturePixels(frameWidth, frameHeight: int, body: untyped): seq[uint8] =
  block:
    gBackend.captureNextFrame(frameWidth.uint32, frameHeight.uint32)
    gVg.beginFrame(frameWidth.float, frameHeight.float, 1.0)
    body
    gVg.endFrame()
    let capturedSize = gBackend.capturedFrameSize()
    check capturedSize.width == frameWidth.uint32
    check capturedSize.height == frameHeight.uint32
    gBackend.capturedFramePixels()

template checkNear(actual, expected: uint8, tolerance: int) =
  check abs(actual.int - expected.int) <= tolerance

suite "wgpu renderer readback":
  test "later draw calls cover earlier draw calls":
    let pixels = capturePixels(64, 64):
      drawRect(8, 8, 48, 48, rgba(255, 0, 0, 255))
      drawRect(24, 24, 24, 24, rgba(0, 0, 255, 255))

    let red = pixels.pixelAt(64, 12, 12)
    check red.r > 220
    check red.g < 30
    check red.b < 30

    let blue = pixels.pixelAt(64, 32, 32)
    check blue.r < 30
    check blue.g < 30
    check blue.b > 220

  test "scissor clips drawing to the requested rectangle":
    let pixels = capturePixels(64, 64):
      gVg.save()
      gVg.scissor(16, 16, 24, 24)
      drawRect(0, 0, 64, 64, rgba(0, 255, 0, 255))
      gVg.restore()

    let inside = pixels.pixelAt(64, 24, 24)
    check inside.r < 30
    check inside.g > 220
    check inside.b < 30

    let outside = pixels.pixelAt(64, 8, 8)
    checkNear(outside.r, 20'u8, 6)
    checkNear(outside.g, 20'u8, 6)
    checkNear(outside.b, 20'u8, 6)

  test "source-over alpha blend keeps both source and destination color":
    let pixels = capturePixels(64, 64):
      drawRect(8, 8, 48, 48, rgba(255, 0, 0, 255))
      drawRect(8, 8, 48, 48, rgba(0, 255, 0, 128))

    let blended = pixels.pixelAt(64, 32, 32)
    check blended.r in 95'u8 .. 160'u8
    check blended.g in 95'u8 .. 170'u8
    check blended.b < 30
    check blended.a > 240

  test "image paint samples uploaded textures":
    var data = @[255'u8, 128'u8, 0'u8, 255'u8]
    let image = gVg.createImageRGBA(1, 1, {}, data)
    let pixels = capturePixels(64, 64):
      let paint = gVg.imagePattern(16, 16, 32, 32, 0, image, 1)
      gVg.beginPath()
      gVg.rect(16, 16, 32, 32)
      gVg.fillPaint(paint)
      gVg.fill()

    let sampled = pixels.pixelAt(64, 32, 32)
    check sampled.r > 220
    check sampled.g in 95'u8 .. 160'u8
    check sampled.b < 30
    check sampled.a > 240

  test "linear gradient paint interpolates across filled geometry":
    let pixels = capturePixels(64, 64):
      let paint =
        gVg.linearGradient(8, 16, 56, 16, rgba(255, 0, 0, 255), rgba(0, 0, 255, 255))
      gVg.beginPath()
      gVg.rect(8, 8, 48, 16)
      gVg.fillPaint(paint)
      gVg.fill()

    let left = pixels.pixelAt(64, 12, 16)
    check left.r > 180
    check left.g < 40
    check left.b < 100

    let right = pixels.pixelAt(64, 52, 16)
    check right.r < 100
    check right.g < 40
    check right.b > 180

  test "overlaid HSV triangle gradients do not collapse to black":
    let pixels = capturePixels(64, 64):
      drawHsvTriangleLikePaint()

    let redCorner = pixels.pixelAt(64, 46, 14)
    check redCorner.r > 180
    check redCorner.g < 80
    check redCorner.b < 80

    let whiteCorner = pixels.pixelAt(64, 18, 14)
    check whiteCorner.r > 180
    check whiteCorner.g > 180
    check whiteCorner.b > 180

    let body = pixels.pixelAt(64, 32, 24)
    check body.r > 80
    check body.g > 30
    check body.b > 30

  test "filled paths preserve explicit holes":
    let pixels = capturePixels(64, 64):
      drawRectWithHole(8, 8, 48, 48, 24, 24, 16, 16, rgba(255, 0, 0, 255))

    let filled = pixels.pixelAt(64, 16, 16)
    check filled.r > 220
    check filled.g < 30
    check filled.b < 30

    let hole = pixels.pixelAt(64, 32, 32)
    checkNear(hole.r, 20'u8, 6)
    checkNear(hole.g, 20'u8, 6)
    checkNear(hole.b, 20'u8, 6)

  test "filled path stencil does not mask later draws":
    let pixels = capturePixels(64, 64):
      drawRectWithHole(8, 8, 48, 48, 24, 24, 16, 16, rgba(255, 0, 0, 255))
      drawRect(24, 24, 16, 16, rgba(0, 0, 255, 255))

    let filled = pixels.pixelAt(64, 16, 16)
    check filled.r > 220
    check filled.g < 30
    check filled.b < 30

    let later = pixels.pixelAt(64, 32, 32)
    check later.r < 30
    check later.g < 30
    check later.b > 220

  test "concave filled paths do not overfill notches":
    let pixels = capturePixels(64, 64):
      drawConcaveNotch(rgba(0, 255, 0, 255))

    let body = pixels.pixelAt(64, 16, 44)
    check body.r < 30
    check body.g > 220
    check body.b < 30

    let bridge = pixels.pixelAt(64, 32, 16)
    check bridge.r < 30
    check bridge.g > 220
    check bridge.b < 30

    let notch = pixels.pixelAt(64, 32, 44)
    checkNear(notch.r, 20'u8, 6)
    checkNear(notch.g, 20'u8, 6)
    checkNear(notch.b, 20'u8, 6)

  test "single convex paths use direct indexed draw":
    let pixels = capturePixels(64, 64):
      drawRoundedRectWithStroke(
        8, 8, 48, 32, 6, rgba(255, 0, 0, 255), rgba(255, 255, 255, 255)
      )

    let stats = gBackend.lastSubmittedRenderStats()
    check stats.drawCalls == 1
    check pixels.pixelAt(64, 32, 24).r > 220

  test "adjacent matching state coalesces into one draw call":
    let pixels = capturePixels(64, 64):
      drawRect(8, 8, 16, 16, rgba(255, 0, 0, 255))
      drawRect(32, 32, 16, 16, rgba(255, 0, 0, 255))

    check gBackend.lastSubmittedDrawCallCount() == 1
    let stats = gBackend.lastSubmittedRenderStats()
    check stats.drawCalls == 1
    check stats.vertices > 0
    check stats.indices > 0
    check stats.indexBytes == (stats.indices * sizeof(uint32)).uint64
    check stats.stagedBytes == stats.vertexBytes + stats.indexBytes
    check stats.expandedVertexBytes ==
      (stats.indices.uint64 * (stats.vertexBytes div stats.vertices.uint64))
    check stats.stagedBytes < stats.expandedVertexBytes
    check pixels.pixelAt(64, 16, 16).r > 220
    check pixels.pixelAt(64, 40, 40).r > 220

  test "diagnostics report selected formats and last render stats":
    discard capturePixels(64, 64):
      drawRect(8, 8, 16, 16, rgba(255, 0, 0, 255))

    let diagnostics = gBackend.diagnostics()
    check diagnostics.surfaceKind.len > 0
    check diagnostics.surfaceFormat.len > 0
    check diagnostics.surfaceAlpha.len > 0
    check diagnostics.stencilFormat == "Depth24PlusStencil8"
    check diagnostics.surfaceFormats.len > 0
    check diagnostics.width > 0
    check diagnostics.height > 0
    check diagnostics.lastRenderStats.drawCalls > 0
    check diagnostics.lastRenderStats.stagedBytes > 0

    let dump = gBackend.dumpWebGpuDiagnostics()
    check dump.contains("surface format:")
    check dump.contains("stencil format:")
    check dump.contains("last draw calls:")
