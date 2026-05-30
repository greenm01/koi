import std/[hashes, tables]

import nanovg
import nanovg/wrapper as nvg
import wgpu
import wgpu/extras/helpers
import wgpu/extras/shaders
import wgpu/extras/strings

import koi/backends/surface
import koi/internal/webgpu_draw_state

const
  NvgTextureAlpha = 0x01
  WebGpuTextureRowAlignment = 256'u32

{.
  emit:
    """
/*TYPESECTION*/
typedef struct NVGscissor {
  float xform[6];
  float extent[2];
} NVGscissor;

typedef struct NVGvertex {
  float x, y, u, v;
} NVGvertex;

typedef struct NVGpath {
  int first;
  int count;
  unsigned char closed;
  int nbevel;
  NVGvertex* fill;
  int nfill;
  NVGvertex* stroke;
  int nstroke;
  int winding;
  int convex;
} NVGpath;

typedef struct NVGparams {
  void* userPtr;
  int edgeAntiAlias;
  int (*renderCreate)(void* uptr);
  int (*renderCreateTexture)(void* uptr, int type, int w, int h, int imageFlags, const unsigned char* data);
  int (*renderDeleteTexture)(void* uptr, int image);
  int (*renderUpdateTexture)(void* uptr, int image, int x, int y, int w, int h, const unsigned char* data);
  int (*renderGetTextureSize)(void* uptr, int image, int* w, int* h);
  void (*renderViewport)(void* uptr, float width, float height, float devicePixelRatio);
  void (*renderCancel)(void* uptr);
  void (*renderFlush)(void* uptr);
  void (*renderFill)(void* uptr, void* paint, void* compositeOperation, NVGscissor* scissor, float fringe, const float* bounds, const NVGpath* paths, int npaths);
  void (*renderStroke)(void* uptr, void* paint, void* compositeOperation, NVGscissor* scissor, float fringe, float strokeWidth, const NVGpath* paths, int npaths);
  void (*renderTriangles)(void* uptr, void* paint, void* compositeOperation, NVGscissor* scissor, const NVGvertex* verts, int nverts, float fringe);
  void (*renderDelete)(void* uptr);
} NVGparams;
"""
.}

type
  NvgScissor {.bycopy, importc: "NVGscissor".} = object
    xform: array[6, cfloat]
    extent: array[2, cfloat]

  NvgVertex {.bycopy, importc: "NVGvertex".} = object
    x, y, u, v: cfloat

  NvgPath {.bycopy, importc: "NVGpath".} = object
    first: cint
    count: cint
    closed: uint8
    nbevel: cint
    fill: ptr NvgVertex
    nfill: cint
    stroke: ptr NvgVertex
    nstroke: cint
    winding: cint
    convex: cint

  NvgParams {.bycopy, importc: "NVGparams".} = object
    userPtr: pointer
    edgeAntiAlias: cint
    renderCreate: proc(userPtr: pointer): cint {.cdecl.}
    renderCreateTexture: proc(
      userPtr: pointer, typ, w, h, imageFlags: cint, data: ptr uint8
    ): cint {.cdecl.}
    renderDeleteTexture: proc(userPtr: pointer, image: cint): cint {.cdecl.}
    renderUpdateTexture:
      proc(userPtr: pointer, image, x, y, w, h: cint, data: ptr uint8): cint {.cdecl.}
    renderGetTextureSize:
      proc(userPtr: pointer, image: cint, w, h: ptr cint): cint {.cdecl.}
    renderViewport:
      proc(userPtr: pointer, width, height, devicePixelRatio: cfloat) {.cdecl.}
    renderCancel: proc(userPtr: pointer) {.cdecl.}
    renderFlush: proc(userPtr: pointer) {.cdecl.}
    renderFill: proc(
      userPtr: pointer,
      paint: ptr nvg.Paint,
      compositeOperation: nvg.CompositeOperationState,
      scissor: ptr NvgScissor,
      fringe: cfloat,
      bounds: ptr cfloat,
      paths: ptr NvgPath,
      npaths: cint,
    ) {.cdecl.}
    renderStroke: proc(
      userPtr: pointer,
      paint: ptr nvg.Paint,
      compositeOperation: nvg.CompositeOperationState,
      scissor: ptr NvgScissor,
      fringe, strokeWidth: cfloat,
      paths: ptr NvgPath,
      npaths: cint,
    ) {.cdecl.}
    renderTriangles: proc(
      userPtr: pointer,
      paint: ptr nvg.Paint,
      compositeOperation: nvg.CompositeOperationState,
      scissor: ptr NvgScissor,
      verts: ptr NvgVertex,
      nverts: cint,
      fringe: cfloat,
    ) {.cdecl.}
    renderDelete: proc(userPtr: pointer) {.cdecl.}

  GpuVertex = WebGpuDrawVertex

  DrawMode = enum
    dmColor
    dmStencilBuild
    dmStencilFringe
    dmStencilCover

  PaintMode = enum
    pmSolid
    pmImage
    pmAlphaImage
    pmGradient

  PipelineKey = object
    mode: DrawMode
    blend: WebGpuBlend

  DrawCall = object
    firstIndex: uint32
    indexCount: uint32
    textureId: int
    mode: DrawMode
    blend: WebGpuBlend
    scissor: WebGpuScissor

  WebGpuRenderStats* = object
    drawCalls*: int
    vertices*: int
    indices*: int
    vertexBytes*: uint64
    indexBytes*: uint64
    expandedVertexBytes*: uint64
    stagedBytes*: uint64

  GpuTexture = object
    texture: Texture
    view: TextureView
    bindGroup: BindGroup
    width: int
    height: int
    alphaOnly: bool

  KoiWgpuBackend* = object
    instance: Instance
    surface: Surface
    adapter: Adapter
    device: Device
    queue: Queue
    surfaceFormat: TextureFormat
    surfaceAlpha: CompositeAlphaMode
    config: SurfaceConfiguration
    pipelines: Table[PipelineKey, RenderPipeline]
    pipelineLayout: PipelineLayout
    bindLayout: BindGroupLayout
    sampler: Sampler
    white: GpuTexture
    stencilTexture: Texture
    stencilView: TextureView
    stencilWidth: uint32
    stencilHeight: uint32
    textures: Table[int, GpuTexture]
    nextTextureId: int
    params: pointer
    vertices: seq[GpuVertex]
    indices: seq[uint32]
    drawCalls: seq[DrawCall]
    capturePending: bool
    capturedPixels: seq[uint8]
    capturedWidth: uint32
    capturedHeight: uint32
    lastSubmittedStats: WebGpuRenderStats
    surfaceNeedsConfigure: bool
    vertexBuffer: Buffer
    indexBuffer: Buffer
    vertexBytes: uint64
    indexBytes: uint64
    width: float32
    height: float32
    devicePixelRatio: float32

proc nvgCreateInternal(params: ptr NvgParams): nvg.NVGContext {.cdecl, importc.}

proc nvgDeleteInternal(ctx: nvg.NVGContext) {.cdecl, importc.}

proc adapterRequestCb(
    status: RequestAdapterStatus,
    adapter: Adapter,
    message: StringView,
    userdata1, userdata2: pointer,
) {.cdecl.} =
  cast[ptr Adapter](userdata1)[] = adapter

proc deviceRequestCb(
    status: RequestDeviceStatus,
    device: Device,
    message: StringView,
    userdata1, userdata2: pointer,
) {.cdecl.} =
  cast[ptr Device](userdata1)[] = device

proc rgba(c: nvg.Color): array[4, float32] =
  [c.r.float32, c.g.float32, c.b.float32, c.a.float32]

func inputVertex(v: NvgVertex): WebGpuInputVertex =
  WebGpuInputVertex(
    x: v.x.float32,
    y: v.y.float32,
    u: v.u.float32,
    v: v.v.float32,
    maskU: v.u.float32,
    maskV: v.v.float32,
  )

func invertTransform(xform: array[6, cfloat], inverse: var array[6, float32]): bool =
  let
    a = xform[0].float32
    b = xform[1].float32
    c = xform[2].float32
    d = xform[3].float32
    e = xform[4].float32
    f = xform[5].float32
    det = a * d - c * b

  if abs(det) < 1e-6'f32:
    return false

  let invDet = 1'f32 / det
  inverse[0] = d * invDet
  inverse[1] = -b * invDet
  inverse[2] = -c * invDet
  inverse[3] = a * invDet
  inverse[4] = (c * f - d * e) * invDet
  inverse[5] = (b * e - a * f) * invDet
  true

proc isGradientPaint(paint: ptr nvg.Paint): bool =
  paint.image == nvg.NoImage and paint.extent[0] != 0 and paint.extent[1] != 0 and
    paint.feather > 0

proc paintParams(paint: ptr nvg.Paint): array[4, float32] =
  if paint.isGradientPaint:
    [
      paint.extent[0].float32,
      paint.extent[1].float32,
      paint.radius.float32,
      paint.feather.float32,
    ]
  else:
    [0'f32, 0, 0, 0]

proc paintVertex(v: NvgVertex, paint: ptr nvg.Paint): WebGpuInputVertex =
  result = inputVertex(v)
  if (paint.image == nvg.NoImage and not paint.isGradientPaint) or paint.extent[0] == 0 or
      paint.extent[1] == 0:
    return

  var inverse: array[6, float32]
  if not invertTransform(paint.xform, inverse):
    return

  let
    x = v.x.float32
    y = v.y.float32
    px = inverse[0] * x + inverse[2] * y + inverse[4]
    py = inverse[1] * x + inverse[3] * y + inverse[5]

  if paint.isGradientPaint:
    result.u = px
    result.v = py
  else:
    result.u = px / paint.extent[0].float32
    result.v = py / paint.extent[1].float32

proc backend(userPtr: pointer): ptr KoiWgpuBackend =
  cast[ptr KoiWgpuBackend](userPtr)

func viewport(b: KoiWgpuBackend): WebGpuViewport =
  WebGpuViewport(width: b.width, height: b.height)

func hash(key: PipelineKey): Hash =
  result = hash(ord(key.mode))
  result = result !& hash(key.blend)
  result = !$result

proc paintMode(b: KoiWgpuBackend, paint: ptr nvg.Paint): PaintMode =
  if paint.isGradientPaint:
    return pmGradient
  if paint.image == nvg.NoImage:
    return pmSolid

  let textureId = int(paint.image)
  if b.textures.hasKey(textureId) and b.textures[textureId].alphaOnly:
    pmAlphaImage
  else:
    pmImage

func shaderMode(mode: PaintMode): float32 =
  case mode
  of pmSolid: 0'f32
  of pmImage: 1'f32
  of pmAlphaImage: 2'f32
  of pmGradient: 3'f32

proc textureId(paint: ptr nvg.Paint): int =
  if paint.image == nvg.NoImage:
    0
  else:
    int(paint.image)

func sameDrawState(a, b: DrawCall): bool =
  a.textureId == b.textureId and a.mode == b.mode and a.blend == b.blend and
    a.scissor == b.scissor

func usesStencil(mode: DrawMode): bool =
  mode in {dmStencilBuild, dmStencilFringe, dmStencilCover}

proc appendDrawCall(
    b: var KoiWgpuBackend,
    firstIndex, indexCount: uint32,
    textureId: int,
    mode: DrawMode,
    blend: WebGpuBlend,
    scissor: WebGpuScissor,
) =
  let call = DrawCall(
    firstIndex: firstIndex,
    indexCount: indexCount,
    textureId: textureId,
    mode: mode,
    blend: blend,
    scissor: scissor,
  )
  if b.drawCalls.len > 0:
    let last = b.drawCalls.high
    if b.drawCalls[last].firstIndex + b.drawCalls[last].indexCount == firstIndex and
        sameDrawState(b.drawCalls[last], call):
      b.drawCalls[last].indexCount += indexCount
      return

  b.drawCalls.add call

func drawScissor(b: KoiWgpuBackend, scissor: ptr NvgScissor): WebGpuScissor =
  if scissor.isNil:
    return WebGpuScissor(active: false)

  var
    xform: array[6, float32]
    extent: array[2, float32]
  for i in 0 ..< xform.len:
    xform[i] = scissor.xform[i].float32
  for i in 0 ..< extent.len:
    extent[i] = scissor.extent[i].float32

  scissorFromNanoVg(
    xform,
    extent,
    max(b.width, 0'f32).uint32,
    max(b.height, 0'f32).uint32,
    b.devicePixelRatio,
  )

func toWgpuBlendFactor(factor: WebGpuBlendFactor): wgpu.BlendFactor =
  case factor
  of wgbfZero: wgpu.BlendFactor.Zero
  of wgbfOne: wgpu.BlendFactor.One
  of wgbfSrc: wgpu.BlendFactor.Src
  of wgbfOneMinusSrc: wgpu.BlendFactor.OneMinusSrc
  of wgbfSrcAlpha: wgpu.BlendFactor.SrcAlpha
  of wgbfOneMinusSrcAlpha: wgpu.BlendFactor.OneMinusSrcAlpha
  of wgbfDst: wgpu.BlendFactor.Dst
  of wgbfOneMinusDst: wgpu.BlendFactor.OneMinusDst
  of wgbfDstAlpha: wgpu.BlendFactor.DstAlpha
  of wgbfOneMinusDstAlpha: wgpu.BlendFactor.OneMinusDstAlpha
  of wgbfSrcAlphaSaturated: wgpu.BlendFactor.SrcAlphaSaturated
  of wgbfUndefined: wgpu.BlendFactor.Undefined

proc appendVertex(
    b: var KoiWgpuBackend,
    viewport: WebGpuViewport,
    v: WebGpuInputVertex,
    color: array[4, float32],
    outerColor: array[4, float32],
    paintParams: array[4, float32],
    mode: float32,
    aaMult: float32,
) =
  b.vertices.add clipVertex(v, viewport, color, outerColor, paintParams, mode, aaMult)

proc appendSourceVertices(
    b: var KoiWgpuBackend,
    verts: ptr NvgVertex,
    count: int,
    paint: ptr nvg.Paint,
    color: array[4, float32],
    outerColor: array[4, float32],
    paintParams: array[4, float32],
    mode: PaintMode,
    aaMult: float32,
    preserveTriangleUvs = false,
): uint32 =
  result = b.vertices.len.uint32
  let src = cast[ptr UncheckedArray[NvgVertex]](verts)
  let shaderMode = mode.shaderMode
  let viewport = b.viewport()
  for i in 0 ..< count:
    let vertex =
      if preserveTriangleUvs and mode != pmGradient:
        inputVertex(src[i])
      else:
        paintVertex(src[i], paint)
    b.appendVertex(viewport, vertex, color, outerColor, paintParams, shaderMode, aaMult)

template appendIndexedPrimitive(
    b: var KoiWgpuBackend, baseVertex: uint32, count: int, indexIterator: untyped
) =
  for i in indexIterator(count):
    b.indices.add baseVertex + i.uint32

proc appendTriangleList(
    b: var KoiWgpuBackend,
    verts: ptr NvgVertex,
    count: int,
    paint: ptr nvg.Paint,
    blend: WebGpuBlend,
    scissor: WebGpuScissor,
    drawMode = dmColor,
) =
  if verts.isNil or count < 3 or not hasDrawableViewport(b.viewport()):
    return

  let
    firstIndex = b.indices.len.uint32
    color = rgba(paint.innerColor)
    outerColor = rgba(paint.outerColor)
    params = paintParams(paint)
    mode = b.paintMode(paint)
    baseVertex = b.appendSourceVertices(
      verts,
      count,
      paint,
      color,
      outerColor,
      params,
      mode,
      0'f32,
      preserveTriangleUvs = true,
    )

  appendIndexedPrimitive(b, baseVertex, count, triangleListIndices)
  let added = b.indices.len.uint32 - firstIndex
  if added > 0:
    b.appendDrawCall(firstIndex, added, textureId(paint), drawMode, blend, scissor)

proc appendFan(
    b: var KoiWgpuBackend,
    verts: ptr NvgVertex,
    count: int,
    paint: ptr nvg.Paint,
    aaMult: float32,
    blend: WebGpuBlend,
    scissor: WebGpuScissor,
    drawMode = dmColor,
) =
  if verts.isNil or count < 3 or not hasDrawableViewport(b.viewport()):
    return

  let
    firstIndex = b.indices.len.uint32
    color = rgba(paint.innerColor)
    outerColor = rgba(paint.outerColor)
    params = paintParams(paint)
    mode = b.paintMode(paint)
    baseVertex = b.appendSourceVertices(
      verts, count, paint, color, outerColor, params, mode, aaMult
    )

  appendIndexedPrimitive(b, baseVertex, count, fanIndices)
  let added = b.indices.len.uint32 - firstIndex
  if added > 0:
    b.appendDrawCall(firstIndex, added, textureId(paint), drawMode, blend, scissor)

proc appendStrip(
    b: var KoiWgpuBackend,
    verts: ptr NvgVertex,
    count: int,
    paint: ptr nvg.Paint,
    aaMult: float32,
    blend: WebGpuBlend,
    scissor: WebGpuScissor,
    drawMode = dmColor,
) =
  if verts.isNil or count < 3 or not hasDrawableViewport(b.viewport()):
    return

  let
    firstIndex = b.indices.len.uint32
    color = rgba(paint.innerColor)
    outerColor = rgba(paint.outerColor)
    params = paintParams(paint)
    mode = b.paintMode(paint)
    baseVertex = b.appendSourceVertices(
      verts, count, paint, color, outerColor, params, mode, aaMult
    )

  appendIndexedPrimitive(b, baseVertex, count, stripIndices)
  let added = b.indices.len.uint32 - firstIndex
  if added > 0:
    b.appendDrawCall(firstIndex, added, textureId(paint), drawMode, blend, scissor)

proc appendCoverQuad(
    b: var KoiWgpuBackend,
    bounds: ptr cfloat,
    paint: ptr nvg.Paint,
    blend: WebGpuBlend,
    scissor: WebGpuScissor,
) =
  if bounds.isNil or not hasDrawableViewport(b.viewport()):
    return

  let
    boundArray = cast[ptr UncheckedArray[cfloat]](bounds)
    minX = boundArray[0].float32
    minY = boundArray[1].float32
    maxX = boundArray[2].float32
    maxY = boundArray[3].float32
    firstIndex = b.indices.len.uint32
    color = rgba(paint.innerColor)
    outerColor = rgba(paint.outerColor)
    params = paintParams(paint)
    mode = b.paintMode(paint)
    verts = [
      NvgVertex(x: maxX.cfloat, y: maxY.cfloat, u: 0.5, v: 1),
      NvgVertex(x: maxX.cfloat, y: minY.cfloat, u: 0.5, v: 1),
      NvgVertex(x: minX.cfloat, y: maxY.cfloat, u: 0.5, v: 1),
      NvgVertex(x: minX.cfloat, y: minY.cfloat, u: 0.5, v: 1),
    ]

  let baseVertex = b.vertices.len.uint32
  let viewport = b.viewport()
  for v in verts:
    b.appendVertex(
      viewport, paintVertex(v, paint), color, outerColor, params, mode.shaderMode, 0'f32
    )

  appendIndexedPrimitive(b, baseVertex, verts.len, stripIndices)
  let added = b.indices.len.uint32 - firstIndex
  if added > 0:
    b.appendDrawCall(
      firstIndex, added, textureId(paint), dmStencilCover, blend, scissor
    )

proc createTexture(
    b: var KoiWgpuBackend, width, height: int, alphaOnly: bool, data: ptr uint8
): GpuTexture =
  let
    format = if alphaOnly: TextureFormat.R8Unorm else: TextureFormat.RGBA8Unorm
    bytesPerPixel = if alphaOnly: 1'u32 else: 4'u32
    size = Extent3D(width: width.uint32, height: height.uint32, depthOrArrayLayers: 1)

  result.texture = b.device.create(
    vaddr TextureDescriptor(
      nextInChain: nil,
      label: "Koi NanoVG texture".toStringView(),
      usage: TextureUsage_CopyDst or TextureUsage_TextureBinding,
      dimension: TextureDimension.D2D,
      size: size,
      format: format,
      mipLevelCount: 1,
      sampleCount: 1,
      viewFormatCount: 0,
      viewFormats: nil,
    )
  )
  result.view = result.texture.create(
    vaddr TextureViewDescriptor(
      nextInChain: nil,
      label: "Koi NanoVG texture view".toStringView(),
      format: format,
      dimension: TextureViewDimension.D2D,
      baseMipLevel: 0,
      mipLevelCount: 1,
      baseArrayLayer: 0,
      arrayLayerCount: 1,
      aspect: TextureAspect.All,
    )
  )
  result.width = width
  result.height = height
  result.alphaOnly = alphaOnly

  if not data.isNil:
    let
      rowBytes = bytesPerPixel * width.uint32
      paddedRowBytes =
        ((rowBytes + WebGpuTextureRowAlignment - 1) div WebGpuTextureRowAlignment) *
        WebGpuTextureRowAlignment
      copyBytes = (paddedRowBytes * height.uint32).int
    var upload = newSeq[uint8](copyBytes)
    for row in 0 ..< height:
      copyMem(
        upload[row * paddedRowBytes.int].addr,
        cast[pointer](cast[uint](data) + (row.uint * rowBytes.uint)),
        rowBytes.int,
      )
    var dst = TexelCopyTextureInfo(
      texture: result.texture,
      mipLevel: 0,
      origin: Origin3D(x: 0, y: 0, z: 0),
      aspect: TextureAspect.All,
    )
    var layout = TexelCopyBufferLayout(
      offset: 0, bytesPerRow: paddedRowBytes, rowsPerImage: height.uint32
    )
    b.queue.write(dst.addr, upload[0].addr, copyBytes.csize_t, layout.addr, size.addr)

  var entries = [
    BindGroupEntry(
      nextInChain: nil,
      binding: 0,
      buffer: nil,
      offset: 0,
      size: 0,
      sampler: nil,
      textureView: result.view,
    ),
    BindGroupEntry(
      nextInChain: nil,
      binding: 1,
      buffer: nil,
      offset: 0,
      size: 0,
      sampler: b.sampler,
      textureView: nil,
    ),
  ]
  result.bindGroup = b.device.create(
    vaddr BindGroupDescriptor(
      nextInChain: nil,
      label: "Koi NanoVG bind group".toStringView(),
      layout: b.bindLayout,
      entryCount: entries.len.uint32,
      entries: entries[0].addr,
    )
  )

proc releaseTexture(texture: GpuTexture) =
  if not texture.bindGroup.isNil:
    texture.bindGroup.release()
  if not texture.view.isNil:
    texture.view.release()
  if not texture.texture.isNil:
    texture.texture.release()

proc renderCreate(userPtr: pointer): cint {.cdecl.} =
  1

proc renderCreateTexture(
    userPtr: pointer, typ, w, h, imageFlags: cint, data: ptr uint8
): cint {.cdecl.} =
  let b = backend(userPtr)
  let id = b.nextTextureId
  b.nextTextureId.inc
  b.textures[id] = b[].createTexture(w.int, h.int, typ == NvgTextureAlpha, data)
  id.cint

proc renderDeleteTexture(userPtr: pointer, image: cint): cint {.cdecl.} =
  let b = backend(userPtr)
  let id = image.int
  if b.textures.hasKey(id):
    releaseTexture(b.textures[id])
    b.textures.del(id)
    1
  else:
    0

proc renderUpdateTexture(
    userPtr: pointer, image, x, y, w, h: cint, data: ptr uint8
): cint {.cdecl.} =
  let b = backend(userPtr)
  let id = image.int
  if data.isNil or not b.textures.hasKey(id):
    return 0

  let tex = b.textures[id]
  let bytesPerPixel = if tex.alphaOnly: 1'u32 else: 4'u32
  let
    rowBytes = bytesPerPixel * w.uint32
    sourceStride = bytesPerPixel * tex.width.uint32
    paddedRowBytes =
      ((rowBytes + WebGpuTextureRowAlignment - 1) div WebGpuTextureRowAlignment) *
      WebGpuTextureRowAlignment
    copyBytes = (paddedRowBytes * h.uint32).int
    dataOffset = ((y.int * tex.width + x.int) * bytesPerPixel.int)
  var upload = newSeq[uint8](copyBytes)
  for row in 0 ..< h.int:
    copyMem(
      upload[row * paddedRowBytes.int].addr,
      cast[pointer](cast[uint](data) + dataOffset.uint + (row.uint * sourceStride.uint)),
      rowBytes.int,
    )
  var dst = TexelCopyTextureInfo(
    texture: tex.texture,
    mipLevel: 0,
    origin: Origin3D(x: x.uint32, y: y.uint32, z: 0),
    aspect: TextureAspect.All,
  )
  var layout = TexelCopyBufferLayout(
    offset: 0, bytesPerRow: paddedRowBytes, rowsPerImage: h.uint32
  )
  var size = Extent3D(width: w.uint32, height: h.uint32, depthOrArrayLayers: 1)
  b.queue.write(dst.addr, upload[0].addr, copyBytes.csize_t, layout.addr, size.addr)
  1

proc renderGetTextureSize(
    userPtr: pointer, image: cint, w, h: ptr cint
): cint {.cdecl.} =
  let b = backend(userPtr)
  let id = image.int
  if not b.textures.hasKey(id):
    return 0
  w[] = b.textures[id].width.cint
  h[] = b.textures[id].height.cint
  1

proc renderViewport(
    userPtr: pointer, width, height, devicePixelRatio: cfloat
) {.cdecl.} =
  let b = backend(userPtr)
  b.width = width.float32
  b.height = height.float32
  b.devicePixelRatio = devicePixelRatio.float32

func nonSrgbEquivalent(format: TextureFormat): TextureFormat =
  case format
  of TextureFormat.RGBA8UnormSrgb: TextureFormat.RGBA8Unorm
  of TextureFormat.BGRA8UnormSrgb: TextureFormat.BGRA8Unorm
  else: format

func chooseSurfaceFormat(
    formats: ptr UncheckedArray[TextureFormat], count: int
): TextureFormat =
  result = formats[0]
  let preferred = [TextureFormat.BGRA8Unorm, TextureFormat.RGBA8Unorm]

  for wanted in preferred:
    for i in 0 ..< count:
      if formats[i] == wanted:
        return wanted

  let linearDefault = nonSrgbEquivalent(result)
  if linearDefault != result:
    for i in 0 ..< count:
      if formats[i] == linearDefault:
        return linearDefault

proc renderCancel(userPtr: pointer) {.cdecl.} =
  let b = backend(userPtr)
  b.vertices.setLen(0)
  b.indices.setLen(0)
  b.drawCalls.setLen(0)

proc renderFill(
    userPtr: pointer,
    paint: ptr nvg.Paint,
    compositeOperation: nvg.CompositeOperationState,
    scissor: ptr NvgScissor,
    fringe: cfloat,
    bounds: ptr cfloat,
    paths: ptr NvgPath,
    npaths: cint,
) {.cdecl.} =
  let b = backend(userPtr)
  let pathArray = cast[ptr UncheckedArray[NvgPath]](paths)
  let
    aaMult = fillAaMult(fringe.float32)
    blend = webGpuBlend(compositeOperation)
    scissor = b[].drawScissor(scissor)

  if npaths == 1 and pathArray[0].convex != 0:
    b[].appendFan(
      pathArray[0].fill, pathArray[0].nfill.int, paint, aaMult, blend, scissor
    )
    b[].appendStrip(
      pathArray[0].stroke, pathArray[0].nstroke.int, paint, aaMult, blend, scissor
    )
    return

  for i in 0 ..< npaths.int:
    b[].appendFan(
      pathArray[i].fill,
      pathArray[i].nfill.int,
      paint,
      0'f32,
      blend,
      scissor,
      dmStencilBuild,
    )

  if aaMult > 0'f32:
    for i in 0 ..< npaths.int:
      b[].appendStrip(
        pathArray[i].stroke,
        pathArray[i].nstroke.int,
        paint,
        aaMult,
        blend,
        scissor,
        dmStencilFringe,
      )

  b[].appendCoverQuad(bounds, paint, blend, scissor)

proc renderStroke(
    userPtr: pointer,
    paint: ptr nvg.Paint,
    compositeOperation: nvg.CompositeOperationState,
    scissor: ptr NvgScissor,
    fringe, strokeWidth: cfloat,
    paths: ptr NvgPath,
    npaths: cint,
) {.cdecl.} =
  let b = backend(userPtr)
  let pathArray = cast[ptr UncheckedArray[NvgPath]](paths)
  let
    aaMult = strokeAaMult(fringe.float32, strokeWidth.float32)
    blend = webGpuBlend(compositeOperation)
    scissor = b[].drawScissor(scissor)
  for i in 0 ..< npaths.int:
    b[].appendStrip(
      pathArray[i].stroke, pathArray[i].nstroke.int, paint, aaMult, blend, scissor
    )

proc renderTriangles(
    userPtr: pointer,
    paint: ptr nvg.Paint,
    compositeOperation: nvg.CompositeOperationState,
    scissor: ptr NvgScissor,
    verts: ptr NvgVertex,
    nverts: cint,
    fringe: cfloat,
) {.cdecl.} =
  let b = backend(userPtr)
  b[].appendTriangleList(
    verts, nverts.int, paint, webGpuBlend(compositeOperation), b[].drawScissor(scissor)
  )

proc ensureVertexBuffer(b: var KoiWgpuBackend, bytes: uint64) =
  if bytes <= b.vertexBytes and not b.vertexBuffer.isNil:
    return

  if not b.vertexBuffer.isNil:
    b.vertexBuffer.release()

  b.vertexBytes = max(bytes, 4096'u64)
  b.vertexBuffer = b.device.create(
    vaddr BufferDescriptor(
      nextInChain: nil,
      label: "Koi NanoVG vertex buffer".toStringView(),
      usage: BufferUsage_CopyDst or BufferUsage_Vertex,
      size: b.vertexBytes,
      mappedAtCreation: false,
    )
  )

proc ensureIndexBuffer(b: var KoiWgpuBackend, bytes: uint64) =
  if bytes <= b.indexBytes and not b.indexBuffer.isNil:
    return

  if not b.indexBuffer.isNil:
    b.indexBuffer.release()

  b.indexBytes = max(bytes, 4096'u64)
  b.indexBuffer = b.device.create(
    vaddr BufferDescriptor(
      nextInChain: nil,
      label: "Koi NanoVG index buffer".toStringView(),
      usage: BufferUsage_CopyDst or BufferUsage_Index,
      size: b.indexBytes,
      mappedAtCreation: false,
    )
  )

proc releaseStencilTarget(b: var KoiWgpuBackend) =
  if not b.stencilView.isNil:
    b.stencilView.release()
    b.stencilView = nil
  if not b.stencilTexture.isNil:
    b.stencilTexture.release()
    b.stencilTexture = nil
  b.stencilWidth = 0
  b.stencilHeight = 0

proc ensureStencilTarget(b: var KoiWgpuBackend, width, height: uint32) =
  let
    w = max(1'u32, width)
    h = max(1'u32, height)
  if not b.stencilTexture.isNil and b.stencilWidth == w and b.stencilHeight == h:
    return

  b.releaseStencilTarget()
  b.stencilTexture = b.device.create(
    vaddr TextureDescriptor(
      nextInChain: nil,
      label: "Koi NanoVG stencil texture".toStringView(),
      usage: TextureUsage_RenderAttachment,
      dimension: TextureDimension.D2D,
      size: Extent3D(width: w, height: h, depthOrArrayLayers: 1),
      format: TextureFormat.Depth24PlusStencil8,
      mipLevelCount: 1,
      sampleCount: 1,
      viewFormatCount: 0,
      viewFormats: nil,
    )
  )
  b.stencilView = b.stencilTexture.create(
    vaddr TextureViewDescriptor(
      nextInChain: nil,
      label: "Koi NanoVG stencil texture view".toStringView(),
      format: TextureFormat.Depth24PlusStencil8,
      dimension: TextureViewDimension.D2D,
      baseMipLevel: 0,
      mipLevelCount: 1,
      baseArrayLayer: 0,
      arrayLayerCount: 1,
      aspect: TextureAspect.All,
    )
  )
  b.stencilWidth = w
  b.stencilHeight = h

proc pipelineForKey(b: var KoiWgpuBackend, key: PipelineKey): RenderPipeline

proc applyDrawScissor(
    pass: RenderPassEncoder,
    scissor: WebGpuScissor,
    fallbackWidth, fallbackHeight: uint32,
) =
  if scissor.active:
    pass.setScissorRect(scissor.x, scissor.y, scissor.width, scissor.height)
  else:
    pass.setScissorRect(0, 0, fallbackWidth, fallbackHeight)

proc renderQueuedDraws(
    b: var KoiWgpuBackend,
    encoder: CommandEncoder,
    targetView: TextureView,
    targetWidth, targetHeight: uint32,
    vertexByteLen, indexByteLen: uint64,
) =
  b.ensureStencilTarget(targetWidth, targetHeight)
  var depthStencil = RenderPassDepthStencilAttachment(
    nextInChain: nil,
    view: b.stencilView,
    depthLoadOp: Clear,
    depthStoreOp: Discard,
    depthClearValue: 1.0,
    depthReadOnly: false.uint32,
    stencilLoadOp: Clear,
    stencilStoreOp: Discard,
    stencilClearValue: 0,
    stencilReadOnly: false.uint32,
  )
  var renderPassDesc = RenderPassDescriptor(
    nextInChain: nil,
    label: "Koi NanoVG render pass".toStringView(),
    colorAttachmentCount: 1,
    colorAttachments: vaddr RenderPassColorAttachment(
      view: targetView,
      resolveTarget: nil,
      loadOp: Clear,
      storeOp: Store,
      clearValue: wgpu.Color(r: 0.08, g: 0.08, b: 0.08, a: 1.0),
    ),
    depthStencilAttachment: depthStencil.addr,
    occlusionQuerySet: nil,
    timestampWrites: nil,
  )
  let pass = encoder.begin(renderPassDesc.addr)
  pass.setVertexBuffer(0, b.vertexBuffer, 0, vertexByteLen)
  pass.setIndexBuffer(b.indexBuffer, IndexFormat.Uint32, 0, indexByteLen)
  for call in b.drawCalls:
    if call.scissor.active and (call.scissor.width == 0 or call.scissor.height == 0):
      continue

    pass.set(b.pipelineForKey(PipelineKey(mode: call.mode, blend: call.blend)))
    pass.setStencilReference(0)
    applyDrawScissor(pass, call.scissor, targetWidth, targetHeight)
    if call.textureId != 0 and b.textures.hasKey(call.textureId):
      pass.set(0, b.textures[call.textureId].bindGroup, 0, nil)
    else:
      pass.set(0, b.white.bindGroup, 0, nil)
    pass.drawIndexed(call.indexCount, 1, call.firstIndex, 0, 0)
  pass.End()

func captureRowBytes(width: uint32): uint32 =
  let rowBytes = width * 4'u32
  ((rowBytes + WebGpuTextureRowAlignment - 1) div WebGpuTextureRowAlignment) *
    WebGpuTextureRowAlignment

proc readCapturedTexture(
    b: KoiWgpuBackend, texture: Texture, width, height: uint32, encoder: CommandEncoder
): Buffer =
  let
    paddedRowBytes = captureRowBytes(width)
    readBytes = paddedRowBytes.uint64 * height.uint64
  result = b.device.create(
    vaddr BufferDescriptor(
      nextInChain: nil,
      label: "Koi NanoVG capture readback buffer".toStringView(),
      usage: BufferUsage_CopyDst or BufferUsage_MapRead,
      size: readBytes,
      mappedAtCreation: false.uint32,
    )
  )
  var source = TexelCopyTextureInfo(
    texture: texture,
    mipLevel: 0,
    origin: Origin3D(x: 0, y: 0, z: 0),
    aspect: TextureAspect.All,
  )
  var destination = TexelCopyBufferInfo(
    layout: TexelCopyBufferLayout(
      offset: 0, bytesPerRow: paddedRowBytes, rowsPerImage: height
    ),
    buffer: result,
  )
  var size = Extent3D(width: width, height: height, depthOrArrayLayers: 1)
  encoder.copy(source.addr, destination.addr, size.addr)

proc copyCapturedPixels(
    b: var KoiWgpuBackend, readBuffer: Buffer, width, height: uint32
) =
  let
    paddedRowBytes = captureRowBytes(width)
    rowBytes = width * 4'u32
    readBytes = paddedRowBytes.uint64 * height.uint64
  var mapped: pointer
  readBuffer.map(MapMode_Read, 0.csize_t, readBytes.csize_t, mapped.addr)
  doAssert not mapped.isNil, "Could not map WebGPU capture buffer"

  b.capturedPixels.setLen((rowBytes * height).int)
  for y in 0 ..< height.int:
    let
      dstOffset = y * rowBytes.int
      srcOffset = y * paddedRowBytes.int
    copyMem(
      b.capturedPixels[dstOffset].addr,
      cast[pointer](cast[uint](mapped) + srcOffset.uint),
      rowBytes.int,
    )

  if b.surfaceFormat == TextureFormat.BGRA8Unorm or
      b.surfaceFormat == TextureFormat.BGRA8UnormSrgb:
    for i in countup(0, b.capturedPixels.high, 4):
      swap(b.capturedPixels[i], b.capturedPixels[i + 2])

  readBuffer.unmap()

proc renderCaptureFrame(b: var KoiWgpuBackend, vertexByteLen, indexByteLen: uint64) =
  let
    width = max(1'u32, b.capturedWidth)
    height = max(1'u32, b.capturedHeight)
  let texture = b.device.create(
    vaddr TextureDescriptor(
      nextInChain: nil,
      label: "Koi NanoVG capture texture".toStringView(),
      usage: TextureUsage_RenderAttachment or TextureUsage_CopySrc,
      dimension: TextureDimension.D2D,
      size: Extent3D(width: width, height: height, depthOrArrayLayers: 1),
      format: b.surfaceFormat,
      mipLevelCount: 1,
      sampleCount: 1,
      viewFormatCount: 0,
      viewFormats: nil,
    )
  )
  let view = texture.create(
    vaddr TextureViewDescriptor(
      nextInChain: nil,
      label: "Koi NanoVG capture texture view".toStringView(),
      format: b.surfaceFormat,
      dimension: TextureViewDimension.D2D,
      baseMipLevel: 0,
      mipLevelCount: 1,
      baseArrayLayer: 0,
      arrayLayerCount: 1,
      aspect: TextureAspect.All,
    )
  )
  let encoder = b.device.create(
    vaddr CommandEncoderDescriptor(
      nextInChain: nil, label: "Koi NanoVG capture command encoder".toStringView()
    )
  )
  b.renderQueuedDraws(encoder, view, width, height, vertexByteLen, indexByteLen)
  let readBuffer = b.readCapturedTexture(texture, width, height, encoder)
  let commandBuffer = encoder.finish(
    vaddr CommandBufferDescriptor(
      nextInChain: nil, label: "Koi NanoVG capture command buffer".toStringView()
    )
  )
  b.queue.submit(1, commandBuffer.addr)
  b.queue.waitIdle()
  b.copyCapturedPixels(readBuffer, width, height)
  b.capturedWidth = width
  b.capturedHeight = height

  commandBuffer.release()
  encoder.release()
  readBuffer.release()
  view.release()
  texture.release()

proc renderSurfaceFrame(
    b: var KoiWgpuBackend, vertexByteLen, indexByteLen: uint64
): bool =
  if b.surfaceNeedsConfigure:
    b.surface.configure(b.config.addr)
    b.surfaceNeedsConfigure = false

  var surfaceTexture = SurfaceTexture()
  b.surface.getCurrentTexture(surfaceTexture.addr)
  case surfaceTexture.status
  of SuccessOptimal, SuccessSuboptimal:
    discard
  of Timeout, Outdated, Lost:
    if not surfaceTexture.texture.isNil:
      surfaceTexture.texture.release()
    b.surface.configure(b.config.addr)
    return false
  else:
    return false

  let nextTexture = surfaceTexture.texture.create(nil)
  let encoder = b.device.create(
    vaddr CommandEncoderDescriptor(
      nextInChain: nil, label: "Koi NanoVG command encoder".toStringView()
    )
  )
  b.renderQueuedDraws(
    encoder, nextTexture, b.config.width, b.config.height, vertexByteLen, indexByteLen
  )
  nextTexture.release()

  let commandBuffer = encoder.finish(
    vaddr CommandBufferDescriptor(
      nextInChain: nil, label: "Koi NanoVG command buffer".toStringView()
    )
  )
  b.queue.submit(1, commandBuffer.addr)
  let presentStatus = b.surface.present()
  if presentStatus != Status.Success:
    b.surfaceNeedsConfigure = true
  commandBuffer.release()
  encoder.release()
  presentStatus == Status.Success

proc renderFlush(userPtr: pointer) {.cdecl.} =
  let b = backend(userPtr)
  if b.vertices.len == 0 or b.indices.len == 0:
    b.capturePending = false
    b.lastSubmittedStats = WebGpuRenderStats()
    return

  let
    vertexByteLen = (b.vertices.len * sizeof(GpuVertex)).uint64
    indexByteLen = (b.indices.len * sizeof(uint32)).uint64
  b[].ensureVertexBuffer(vertexByteLen)
  b[].ensureIndexBuffer(indexByteLen)
  b.queue.write(b.vertexBuffer, 0'u64, b.vertices[0].addr, vertexByteLen.csize_t)
  b.queue.write(b.indexBuffer, 0'u64, b.indices[0].addr, indexByteLen.csize_t)
  b.lastSubmittedStats = WebGpuRenderStats(
    drawCalls: b.drawCalls.len,
    vertices: b.vertices.len,
    indices: b.indices.len,
    vertexBytes: vertexByteLen,
    indexBytes: indexByteLen,
    expandedVertexBytes: (b.indices.len * sizeof(GpuVertex)).uint64,
    stagedBytes: vertexByteLen + indexByteLen,
  )

  if b.capturePending:
    b[].renderCaptureFrame(vertexByteLen, indexByteLen)
    b.capturePending = false
  else:
    discard b[].renderSurfaceFrame(vertexByteLen, indexByteLen)

  b.vertices.setLen(0)
  b.indices.setLen(0)
  b.drawCalls.setLen(0)

proc renderDelete(userPtr: pointer) {.cdecl.} =
  let b = backend(userPtr)
  for texture in b.textures.values:
    releaseTexture(texture)
  b.textures.clear()
  for pipeline in b.pipelines.values:
    pipeline.release()
  b.pipelines.clear()
  b[].releaseStencilTarget()
  releaseTexture(b.white)
  if not b.vertexBuffer.isNil:
    b.vertexBuffer.release()
  if not b.indexBuffer.isNil:
    b.indexBuffer.release()
  if not b.params.isNil:
    dealloc(b.params)
    b.params = nil

const shaderCode = staticRead("shaders/nanovg.wgsl")

func blendState(blend: WebGpuBlend): BlendState =
  BlendState(
    alpha: BlendComponent(
      operation: wgpu.BlendOperation.Add,
      srcFactor: toWgpuBlendFactor(blend.srcAlpha),
      dstFactor: toWgpuBlendFactor(blend.dstAlpha),
    ),
    color: BlendComponent(
      operation: wgpu.BlendOperation.Add,
      srcFactor: toWgpuBlendFactor(blend.srcRgb),
      dstFactor: toWgpuBlendFactor(blend.dstRgb),
    ),
  )

func stencilFrontState(mode: DrawMode): StencilFaceState =
  case mode
  of dmStencilBuild:
    StencilFaceState(
      compare: CompareFunction.Always,
      failOp: StencilOperation.Keep,
      depthFailOp: StencilOperation.Keep,
      passOp: StencilOperation.IncrementWrap,
    )
  of dmStencilFringe:
    StencilFaceState(
      compare: CompareFunction.Equal,
      failOp: StencilOperation.Keep,
      depthFailOp: StencilOperation.Keep,
      passOp: StencilOperation.Keep,
    )
  of dmStencilCover:
    StencilFaceState(
      compare: CompareFunction.NotEqual,
      failOp: StencilOperation.Zero,
      depthFailOp: StencilOperation.Zero,
      passOp: StencilOperation.Zero,
    )
  of dmColor:
    StencilFaceState(
      compare: CompareFunction.Always,
      failOp: StencilOperation.Keep,
      depthFailOp: StencilOperation.Keep,
      passOp: StencilOperation.Keep,
    )

func stencilBackState(mode: DrawMode): StencilFaceState =
  case mode
  of dmStencilBuild:
    StencilFaceState(
      compare: CompareFunction.Always,
      failOp: StencilOperation.Keep,
      depthFailOp: StencilOperation.Keep,
      passOp: StencilOperation.DecrementWrap,
    )
  else:
    stencilFrontState(mode)

func stencilReadMask(mode: DrawMode): uint32 =
  if mode.usesStencil: 0xff'u32 else: 0'u32

func stencilWriteMask(mode: DrawMode): uint32 =
  case mode
  of dmStencilBuild, dmStencilCover: 0xff'u32
  of dmColor, dmStencilFringe: 0'u32

func noOpBlendState(): BlendState =
  BlendState(
    alpha: BlendComponent(
      operation: wgpu.BlendOperation.Add,
      srcFactor: wgpu.BlendFactor.Zero,
      dstFactor: wgpu.BlendFactor.One,
    ),
    color: BlendComponent(
      operation: wgpu.BlendOperation.Add,
      srcFactor: wgpu.BlendFactor.Zero,
      dstFactor: wgpu.BlendFactor.One,
    ),
  )

proc createRenderPipeline(b: KoiWgpuBackend, key: PipelineKey): RenderPipeline =
  var attributes = [
    VertexAttribute(format: VertexFormat.Float32x2, offset: 0, shaderLocation: 0),
    VertexAttribute(format: VertexFormat.Float32x2, offset: 8, shaderLocation: 1),
    VertexAttribute(format: VertexFormat.Float32x2, offset: 16, shaderLocation: 2),
    VertexAttribute(format: VertexFormat.Float32x4, offset: 24, shaderLocation: 3),
    VertexAttribute(format: VertexFormat.Float32x4, offset: 40, shaderLocation: 4),
    VertexAttribute(format: VertexFormat.Float32x4, offset: 56, shaderLocation: 5),
    VertexAttribute(format: VertexFormat.Float32, offset: 72, shaderLocation: 6),
    VertexAttribute(format: VertexFormat.Float32, offset: 76, shaderLocation: 7),
  ]
  var vertexLayout = VertexBufferLayout(
    arrayStride: sizeof(GpuVertex).uint64,
    stepMode: VertexStepMode.Vertex,
    attributeCount: attributes.len.uint32,
    attributes: attributes[0].addr,
  )

  var shaderDesc = wgsl.toDescriptor(shaderCode, label = "Koi NanoVG shader")
  let shader = b.device.create(shaderDesc.addr)
  var blend =
    if key.mode == dmStencilBuild:
      noOpBlendState()
    else:
      blendState(key.blend)
  var target = ColorTargetState(
    nextInChain: nil,
    format: b.surfaceFormat,
    blend: blend.addr,
    writeMask: ColorWriteMask_All,
  )
  var depthStencil = DepthStencilState(
    nextInChain: nil,
    format: TextureFormat.Depth24PlusStencil8,
    depthWriteEnabled: false.uint32,
    depthCompare: CompareFunction.Always,
    stencilFront: stencilFrontState(key.mode),
    stencilBack: stencilBackState(key.mode),
    stencilReadMask: stencilReadMask(key.mode),
    stencilWriteMask: stencilWriteMask(key.mode),
    depthBias: 0,
    depthBiasSlopeScale: 0,
    depthBiasClamp: 0,
  )

  var fragment = FragmentState(
    nextInChain: nil,
    module: shader,
    entryPoint: "fs_main".toStringView(),
    constantCount: 0,
    constants: nil,
    targetCount: 1,
    targets: target.addr,
  )
  var desc = RenderPipelineDescriptor(
    nextInChain: nil,
    label: "Koi NanoVG render pipeline".toStringView(),
    layout: b.pipelineLayout,
    vertex: VertexState(
      module: shader,
      entryPoint: "vs_main".toStringView(),
      constantCount: 0,
      constants: nil,
      bufferCount: 1,
      buffers: vertexLayout.addr,
    ),
    primitive: PrimitiveState(
      nextInChain: nil,
      topology: PrimitiveTopology.TriangleList,
      stripIndexFormat: IndexFormat.Undefined,
      frontFace: FrontFace.CCW,
      cullMode: CullMode.None,
    ),
    depthStencil: depthStencil.addr,
    multisample: MultisampleState(
      nextInChain: nil,
      count: 1,
      mask: uint32.high,
      alphaToCoverageEnabled: false.uint32,
    ),
    fragment: fragment.addr,
  )
  result = b.device.create(desc.addr)

proc pipelineForKey(b: var KoiWgpuBackend, key: PipelineKey): RenderPipeline =
  if not b.pipelines.hasKey(key):
    b.pipelines[key] = b.createRenderPipeline(key)
  b.pipelines[key]

proc requestAdapter(b: var KoiWgpuBackend) =
  let future = b.instance.request(
    options = vaddr RequestAdapterOptions(
      nextInChain: nil,
      featureLevel: Core,
      powerPreference: HighPerformance,
      forceFallbackAdapter: false.uint32,
      backendType: Undefined,
      compatibleSurface: b.surface,
    ),
    callbackInfo = RequestAdapterCallbackInfo(
      nextInChain: nil,
      mode: AllowSpontaneous,
      callback: adapterRequestCb,
      userdata1: b.adapter.addr,
      userdata2: nil,
    ),
  )
  var waitInfo = FutureWaitInfo(future: future, completed: 0)
  doAssert b.instance.wait(1, waitInfo.addr, uint64.high) == Success
  doAssert waitInfo.completed != 0 and not b.adapter.isNil

proc requestDevice(b: var KoiWgpuBackend) =
  let future = b.adapter.request(
    options = vaddr DeviceDescriptor(
      nextInChain: nil,
      label: "Koi WebGPU device".toStringView(),
      requiredFeatureCount: 0,
      requiredFeatures: nil,
      requiredLimits: nil,
      defaultQueue:
        QueueDescriptor(nextInChain: nil, label: "Koi WebGPU queue".toStringView()),
      deviceLostCallbackInfo: DeviceLostCallbackInfo(
        nextInChain: nil, callback: nil, userdata1: nil, userdata2: nil
      ),
      uncapturedErrorCallbackInfo: UncapturedErrorCallbackInfo(
        nextInChain: nil, callback: nil, userdata1: nil, userdata2: nil
      ),
    ),
    callbackInfo = RequestDeviceCallbackInfo(
      nextInChain: nil,
      mode: AllowSpontaneous,
      callback: deviceRequestCb,
      userdata1: b.device.addr,
      userdata2: nil,
    ),
  )
  var waitInfo = FutureWaitInfo(future: future, completed: 0)
  doAssert b.instance.wait(1, waitInfo.addr, uint64.high) == Success
  doAssert waitInfo.completed != 0 and not b.device.isNil
  b.queue = b.device.getQueue()

proc configureSurface(b: var KoiWgpuBackend, width, height: uint32) =
  var caps = SurfaceCapabilities()
  doAssert b.surface.get(b.adapter, caps.addr) == Status.Success
  doAssert caps.formatCount > 0
  doAssert caps.alphaModeCount > 0
  let formats = cast[ptr UncheckedArray[TextureFormat]](caps.formats)
  b.surfaceFormat = chooseSurfaceFormat(formats, caps.formatCount.int)
  b.surfaceAlpha = cast[ptr UncheckedArray[CompositeAlphaMode]](caps.alphaModes)[0]
  b.config = SurfaceConfiguration(
    nextInChain: nil,
    device: b.device,
    format: b.surfaceFormat,
    usage: TextureUsage_RenderAttachment,
    width: width,
    height: height,
    viewFormatCount: 0,
    viewFormats: nil,
    alphaMode: b.surfaceAlpha,
    presentMode: Fifo,
  )
  b.surface.configure(b.config.addr)
  b.width = width.float32
  b.height = height.float32
  b.devicePixelRatio = 1'f32
  caps.freeMembers()

proc createPipeline(b: var KoiWgpuBackend) =
  var bindEntries = [
    BindGroupLayoutEntry(
      nextInChain: nil,
      binding: 0,
      visibility: ShaderStage_Fragment,
      buffer: BufferBindingLayout(
        nextInChain: nil,
        `type`: BufferBindingType.BindingNotUsed,
        hasDynamicOffset: false.uint32,
        minBindingSize: 0,
      ),
      sampler: SamplerBindingLayout(
        nextInChain: nil, `type`: SamplerBindingType.BindingNotUsed
      ),
      texture: TextureBindingLayout(
        nextInChain: nil,
        sampleType: TextureSampleType.Float,
        viewDimension: TextureViewDimension.D2D,
        multisampled: false.uint32,
      ),
      storageTexture: StorageTextureBindingLayout(
        nextInChain: nil,
        access: StorageTextureAccess.BindingNotUsed,
        format: TextureFormat.Undefined,
        viewDimension: TextureViewDimension.Undefined,
      ),
    ),
    BindGroupLayoutEntry(
      nextInChain: nil,
      binding: 1,
      visibility: ShaderStage_Fragment,
      buffer: BufferBindingLayout(
        nextInChain: nil,
        `type`: BufferBindingType.BindingNotUsed,
        hasDynamicOffset: false.uint32,
        minBindingSize: 0,
      ),
      sampler:
        SamplerBindingLayout(nextInChain: nil, `type`: SamplerBindingType.Filtering),
      texture: TextureBindingLayout(
        nextInChain: nil,
        sampleType: TextureSampleType.BindingNotUsed,
        viewDimension: TextureViewDimension.Undefined,
        multisampled: false.uint32,
      ),
      storageTexture: StorageTextureBindingLayout(
        nextInChain: nil,
        access: StorageTextureAccess.BindingNotUsed,
        format: TextureFormat.Undefined,
        viewDimension: TextureViewDimension.Undefined,
      ),
    ),
  ]
  b.bindLayout = b.device.createLayout(
    vaddr BindGroupLayoutDescriptor(
      nextInChain: nil,
      label: "Koi NanoVG bind layout".toStringView(),
      entryCount: bindEntries.len.uint32,
      entries: bindEntries[0].addr,
    )
  )
  b.pipelineLayout = b.device.create(
    vaddr PipelineLayoutDescriptor(
      nextInChain: nil,
      label: "Koi NanoVG pipeline layout".toStringView(),
      bindGroupLayoutCount: 1,
      bindGroupLayouts: b.bindLayout.addr,
    )
  )

  let defaultBlend = defaultWebGpuBlend()
  let defaultKey = PipelineKey(mode: dmColor, blend: defaultBlend)
  b.pipelines[defaultKey] = b.createRenderPipeline(defaultKey)

  b.sampler = b.device.create(
    vaddr SamplerDescriptor(
      nextInChain: nil,
      label: "Koi NanoVG sampler".toStringView(),
      addressModeU: AddressMode.ClampToEdge,
      addressModeV: AddressMode.ClampToEdge,
      addressModeW: AddressMode.ClampToEdge,
      magFilter: FilterMode.Linear,
      minFilter: FilterMode.Linear,
      mipmapFilter: MipmapFilterMode.Nearest,
      lodMinClamp: 0,
      lodMaxClamp: 32,
      compare: CompareFunction.Undefined,
      maxAnisotropy: 1,
    )
  )

  var whitePixel = [255'u8, 255'u8, 255'u8, 255'u8]
  b.white = b.createTexture(1, 1, false, whitePixel[0].addr)

proc initKoiWgpuBackendWithSurface*(
    b: var KoiWgpuBackend, handle: KoiWgpuSurfaceHandle, width, height: uint32
) =
  b.instance = wgpu.create(vaddr InstanceDescriptor(nextInChain: nil))
  doAssert not b.instance.isNil, "Could not initialize WebGPU"
  b.surface = b.instance.createSurface(handle)
  doAssert not b.surface.isNil, "Could not create WebGPU surface"
  b.nextTextureId = 1
  b.requestAdapter()
  b.requestDevice()
  b.configureSurface(width, height)
  b.createPipeline()

proc initKoiWgpuBackend*(
    b: var KoiWgpuBackend, display, wlSurface: pointer, width, height: uint32
) =
  b.initKoiWgpuBackendWithSurface(
    waylandSurfaceHandle(display, wlSurface), width, height
  )

proc resizeKoiWgpuBackend*(b: var KoiWgpuBackend, width, height: uint32) =
  if width == 0 or height == 0:
    return
  if b.config.width == width and b.config.height == height:
    return

  b.config.width = width
  b.config.height = height
  b.surfaceNeedsConfigure = false
  b.surface.configure(b.config.addr)

proc captureNextFrame*(b: var KoiWgpuBackend, width, height: uint32) =
  ## Diagnostic/test helper: the next NanoVG endFrame renders offscreen and
  ## stores tightly packed RGBA8 pixels instead of presenting to the surface.
  b.capturePending = true
  b.capturedPixels.setLen(0)
  b.capturedWidth = width
  b.capturedHeight = height

proc capturedFramePixels*(b: KoiWgpuBackend): seq[uint8] =
  b.capturedPixels

proc capturedFrameSize*(b: KoiWgpuBackend): tuple[width, height: uint32] =
  (b.capturedWidth, b.capturedHeight)

proc lastSubmittedDrawCallCount*(b: KoiWgpuBackend): int =
  b.lastSubmittedStats.drawCalls

proc lastSubmittedRenderStats*(b: KoiWgpuBackend): WebGpuRenderStats =
  b.lastSubmittedStats

proc createNanoVgContext*(
    b: var KoiWgpuBackend, flags: set[nvg.NVGInitFlag] = {}
): nvg.NVGContext =
  if b.params.isNil:
    b.params = alloc0(sizeof(NvgParams))
  let params = cast[ptr NvgParams](b.params)
  params[] = NvgParams(
    userPtr: b.addr,
    edgeAntiAlias: (if nvg.nifAntialias in flags: 1.cint else: 0.cint),
    renderCreate: renderCreate,
    renderCreateTexture: renderCreateTexture,
    renderDeleteTexture: renderDeleteTexture,
    renderUpdateTexture: renderUpdateTexture,
    renderGetTextureSize: renderGetTextureSize,
    renderViewport: renderViewport,
    renderCancel: renderCancel,
    renderFlush: renderFlush,
    renderFill: renderFill,
    renderStroke: renderStroke,
    renderTriangles: renderTriangles,
    renderDelete: renderDelete,
  )
  result = nvgCreateInternal(params)

proc deleteNanoVgContext*(ctx: nvg.NVGContext) =
  if not ctx.isNil:
    nvgDeleteInternal(ctx)
