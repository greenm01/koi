## Windowed WebGPU renderer validation. These tests render through the real
## NanoVG backend into an offscreen readback texture and assert sampled pixels.

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
