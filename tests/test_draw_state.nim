import std/math
import std/unittest

import nanovg/wrapper as nvg

import koi/internal/webgpu_draw_state

const Epsilon = 0.0001'f32

template checkClose(actual, expected: float32) =
  check abs(actual - expected) < Epsilon

func collectTriangleList(count: int): seq[int] =
  for i in triangleListIndices(count):
    result.add i

func collectFan(count: int): seq[int] =
  for i in fanIndices(count):
    result.add i

func collectStrip(count: int): seq[int] =
  for i in stripIndices(count):
    result.add i

suite "wgpu draw geometry":
  test "triangle list keeps valid source order":
    check collectTriangleList(2) == newSeq[int]()
    check collectTriangleList(3) == @[0, 1, 2]
    check collectTriangleList(5) == @[0, 1, 2, 3, 4]

  test "fan expands from the first vertex":
    check collectFan(2) == newSeq[int]()
    check collectFan(4) == @[0, 1, 2, 0, 2, 3]
    check collectFan(6).len == (6 - 2) * 3

  test "strip expansion preserves winding":
    check collectStrip(2) == newSeq[int]()
    check collectStrip(4) == @[0, 1, 2, 2, 1, 3]
    check collectStrip(6).len == (6 - 2) * 3

  test "clip conversion maps viewport pixels to device coordinates":
    let vertex = clipVertex(
      WebGpuInputVertex(x: 50, y: 25, u: 0.25, v: 0.75, maskU: 0.5, maskV: 1.0),
      WebGpuViewport(width: 100, height: 50),
      [0.1'f32, 0.2, 0.3, 0.4],
      mode = 2,
      aaMult = 3,
    )

    checkClose vertex.x, 0
    checkClose vertex.y, 0
    checkClose vertex.u, 0.25
    checkClose vertex.v, 0.75
    checkClose vertex.maskU, 0.5
    checkClose vertex.maskV, 1.0
    checkClose vertex.r, 0.1
    checkClose vertex.g, 0.2
    checkClose vertex.b, 0.3
    checkClose vertex.a, 0.4
    checkClose vertex.mode, 2
    checkClose vertex.aaMult, 3

  test "viewport validity rejects zero dimensions":
    check hasDrawableViewport(WebGpuViewport(width: 1, height: 1))
    check not hasDrawableViewport(WebGpuViewport(width: 0, height: 1))
    check not hasDrawableViewport(WebGpuViewport(width: 1, height: 0))

suite "draw antialiasing metadata":
  test "fill antialiasing follows fringe":
    checkClose fillAaMult(0), 0
    checkClose fillAaMult(1), 1

  test "stroke antialiasing follows fringe and stroke width":
    checkClose strokeAaMult(0, 10), 0
    checkClose strokeAaMult(2, 6), 2

suite "draw blend mapping":
  test "default source-over blend matches NanoVG fallback":
    let blend = defaultWebGpuBlend()

    check blend.srcRgb == wgbfOne
    check blend.dstRgb == wgbfOneMinusSrcAlpha
    check blend.srcAlpha == wgbfOne
    check blend.dstAlpha == wgbfOneMinusSrcAlpha

  test "custom NanoVG blend factors map to wgpu":
    let blend = webGpuBlend(
      nvg.CompositeOperationState(
        srcRGB: (1 shl 6).cint,
        dstRGB: (1 shl 7).cint,
        srcAlpha: (1 shl 1).cint,
        dstAlpha: (1 shl 0).cint,
      )
    )

    check blend.srcRgb == wgbfSrcAlpha
    check blend.dstRgb == wgbfOneMinusSrcAlpha
    check blend.srcAlpha == wgbfOne
    check blend.dstAlpha == wgbfZero

  test "invalid NanoVG blend factors fall back to source-over":
    check webGpuBlend(nvg.CompositeOperationState(srcRGB: 999.cint)) ==
      defaultWebGpuBlend()

suite "draw scissor mapping":
  test "disabled scissor stays inactive":
    let scissor = scissorFromNanoVg([0'f32, 0, 0, 0, 0, 0], [-1'f32, -1], 100, 100, 1)

    check not scissor.active

  test "identity scissor maps center and half extents":
    let scissor = scissorFromNanoVg([1'f32, 0, 0, 1, 50, 30], [20'f32, 10], 100, 100, 1)

    check scissor.active
    check scissor.x == 30
    check scissor.y == 20
    check scissor.width == 40
    check scissor.height == 20

  test "scissor applies scale and device pixel ratio":
    let scissor = scissorFromNanoVg([2'f32, 0, 0, 3, 50, 30], [10'f32, 10], 100, 100, 2)

    check scissor.active
    check scissor.x == 60
    check scissor.y == 0
    check scissor.width == 80
    check scissor.height == 120

  test "scissor clamps to the viewport":
    let scissor =
      scissorFromNanoVg([1'f32, 0, 0, 1, -5, 110], [20'f32, 20], 100, 100, 1)

    check scissor.active
    check scissor.x == 0
    check scissor.y == 90
    check scissor.width == 15
    check scissor.height == 10

  test "empty scissor remains active with zero area":
    let scissor = scissorFromNanoVg([1'f32, 0, 0, 1, 50, 50], [0'f32, 0], 100, 100, 1)

    check scissor.active
    check scissor.x == 50
    check scissor.y == 50
    check scissor.width == 0
    check scissor.height == 0
