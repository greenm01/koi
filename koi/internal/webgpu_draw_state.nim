import std/hashes
import std/math

import nanovg/wrapper as nvg

const
  NvgZero = 1 shl 0
  NvgOne = 1 shl 1
  NvgSourceColor = 1 shl 2
  NvgOneMinusSourceColor = 1 shl 3
  NvgDestinationColor = 1 shl 4
  NvgOneMinusDestinationColor = 1 shl 5
  NvgSourceAlpha = 1 shl 6
  NvgOneMinusSourceAlpha = 1 shl 7
  NvgDestinationAlpha = 1 shl 8
  NvgOneMinusDestinationAlpha = 1 shl 9
  NvgSourceAlphaSaturate = 1 shl 10

type
  WebGpuBlendFactor* = enum
    wgbfUndefined
    wgbfZero
    wgbfOne
    wgbfSrc
    wgbfOneMinusSrc
    wgbfSrcAlpha
    wgbfOneMinusSrcAlpha
    wgbfDst
    wgbfOneMinusDst
    wgbfDstAlpha
    wgbfOneMinusDstAlpha
    wgbfSrcAlphaSaturated

  WebGpuBlend* = object
    srcRgb*: WebGpuBlendFactor
    dstRgb*: WebGpuBlendFactor
    srcAlpha*: WebGpuBlendFactor
    dstAlpha*: WebGpuBlendFactor

  WebGpuScissor* = object
    active*: bool
    x*, y*, width*, height*: uint32

  WebGpuViewport* = object
    width*, height*: float32

  WebGpuInputVertex* = object
    x*, y*, u*, v*: float32
    maskU*, maskV*: float32

  WebGpuDrawVertex* = object
    x*, y*: float32
    u*, v*: float32
    maskU*, maskV*: float32
    r*, g*, b*, a*: float32
    mode*: float32
    aaMult*: float32

func defaultWebGpuBlend*(): WebGpuBlend =
  WebGpuBlend(
    srcRgb: wgbfOne,
    dstRgb: wgbfOneMinusSrcAlpha,
    srcAlpha: wgbfOne,
    dstAlpha: wgbfOneMinusSrcAlpha,
  )

func hash*(blend: WebGpuBlend): Hash =
  result = hash(ord(blend.srcRgb))
  result = result !& hash(ord(blend.dstRgb))
  result = result !& hash(ord(blend.srcAlpha))
  result = result !& hash(ord(blend.dstAlpha))
  result = !$result

func webGpuBlendFactor*(factor: cint): WebGpuBlendFactor =
  case factor.int
  of NvgZero: wgbfZero
  of NvgOne: wgbfOne
  of NvgSourceColor: wgbfSrc
  of NvgOneMinusSourceColor: wgbfOneMinusSrc
  of NvgDestinationColor: wgbfDst
  of NvgOneMinusDestinationColor: wgbfOneMinusDst
  of NvgSourceAlpha: wgbfSrcAlpha
  of NvgOneMinusSourceAlpha: wgbfOneMinusSrcAlpha
  of NvgDestinationAlpha: wgbfDstAlpha
  of NvgOneMinusDestinationAlpha: wgbfOneMinusDstAlpha
  of NvgSourceAlphaSaturate: wgbfSrcAlphaSaturated
  else: wgbfUndefined

func webGpuBlend*(state: nvg.CompositeOperationState): WebGpuBlend =
  result = WebGpuBlend(
    srcRgb: webGpuBlendFactor(state.srcRGB),
    dstRgb: webGpuBlendFactor(state.dstRGB),
    srcAlpha: webGpuBlendFactor(state.srcAlpha),
    dstAlpha: webGpuBlendFactor(state.dstAlpha),
  )

  if result.srcRgb == wgbfUndefined or result.dstRgb == wgbfUndefined or
      result.srcAlpha == wgbfUndefined or result.dstAlpha == wgbfUndefined:
    result = defaultWebGpuBlend()

func fillAaMult*(fringe: float32): float32 =
  if fringe > 0'f32: 1'f32 else: 0'f32

func strokeAaMult*(fringe, strokeWidth: float32): float32 =
  if fringe > 0'f32:
    (strokeWidth * 0.5'f32 + fringe * 0.5'f32) / fringe
  else:
    0'f32

func hasDrawableViewport*(viewport: WebGpuViewport): bool =
  viewport.width > 0'f32 and viewport.height > 0'f32

func clipVertex*(
    vertex: WebGpuInputVertex,
    viewport: WebGpuViewport,
    color: array[4, float32],
    mode, aaMult: float32,
): WebGpuDrawVertex =
  WebGpuDrawVertex(
    x: (vertex.x / viewport.width) * 2'f32 - 1'f32,
    y: 1'f32 - (vertex.y / viewport.height) * 2'f32,
    u: vertex.u,
    v: vertex.v,
    maskU: vertex.maskU,
    maskV: vertex.maskV,
    r: color[0],
    g: color[1],
    b: color[2],
    a: color[3],
    mode: mode,
    aaMult: aaMult,
  )

iterator triangleListIndices*(count: int): int =
  if count >= 3:
    for i in 0 ..< count:
      yield i

iterator fanIndices*(count: int): int =
  if count >= 3:
    for i in 1 ..< count - 1:
      yield 0
      yield i
      yield i + 1

iterator stripIndices*(count: int): int =
  if count >= 3:
    for i in 0 ..< count - 2:
      if (i and 1) == 0:
        yield i
        yield i + 1
        yield i + 2
      else:
        yield i + 1
        yield i
        yield i + 2

func scissorFromNanoVg*(
    xform: array[6, float32],
    extent: array[2, float32],
    viewportWidth, viewportHeight: uint32,
    devicePixelRatio: float32,
): WebGpuScissor =
  if extent[0] < -0.5'f32 or extent[1] < -0.5'f32 or devicePixelRatio <= 0'f32 or
      viewportWidth == 0 or viewportHeight == 0:
    return WebGpuScissor(active: false)

  var
    minX = Inf.float32
    minY = Inf.float32
    maxX = NegInf.float32
    maxY = NegInf.float32

  for sx in [-extent[0], extent[0]]:
    for sy in [-extent[1], extent[1]]:
      let
        x = xform[4] + xform[0] * sx + xform[2] * sy
        y = xform[5] + xform[1] * sx + xform[3] * sy
      minX = min(minX, x)
      minY = min(minY, y)
      maxX = max(maxX, x)
      maxY = max(maxY, y)

  let
    surfaceW = viewportWidth.float32 * devicePixelRatio
    surfaceH = viewportHeight.float32 * devicePixelRatio
    x0 = clamp(floor(minX * devicePixelRatio), 0'f32, surfaceW)
    y0 = clamp(floor(minY * devicePixelRatio), 0'f32, surfaceH)
    x1 = clamp(ceil(maxX * devicePixelRatio), 0'f32, surfaceW)
    y1 = clamp(ceil(maxY * devicePixelRatio), 0'f32, surfaceH)

  WebGpuScissor(
    active: true,
    x: x0.uint32,
    y: y0.uint32,
    width: max(x1 - x0, 0'f32).uint32,
    height: max(y1 - y0, 0'f32).uint32,
  )
