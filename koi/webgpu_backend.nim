import std/tables

import nanovg
import nanovg/wrapper as nvg
import wgpu
import wgpu/extras/helpers
import wgpu/extras/shaders
import wgpu/extras/strings

const
  NvgTextureAlpha = 0x01
  NvgTextureRgba = 0x02

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
    closed: cuchar
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
      userPtr: pointer, typ, w, h, imageFlags: cint, data: ptr cuchar
    ): cint {.cdecl.}
    renderDeleteTexture: proc(userPtr: pointer, image: cint): cint {.cdecl.}
    renderUpdateTexture:
      proc(userPtr: pointer, image, x, y, w, h: cint, data: ptr cuchar): cint {.cdecl.}
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

  GpuVertex = object
    x, y: float32
    u, v: float32
    r, g, b, a: float32
    mode: float32
    aaMult: float32

  DrawCall = object
    first: uint32
    count: uint32
    textureId: int

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
    pipeline: RenderPipeline
    pipelineLayout: PipelineLayout
    bindLayout: BindGroupLayout
    sampler: Sampler
    white: GpuTexture
    textures: Table[int, GpuTexture]
    nextTextureId: int
    params: pointer
    vertices: seq[GpuVertex]
    drawCalls: seq[DrawCall]
    vertexBuffer: Buffer
    vertexBytes: uint64
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

proc deviceLostCb(
    device: ptr Device,
    reason: DeviceLostReason,
    message: StringView,
    userdata1, userdata2: pointer,
) {.cdecl.} =
  discard

proc errorCb(
    device: ptr Device,
    typ: ErrorType,
    message: StringView,
    userdata1, userdata2: pointer,
) {.cdecl.} =
  discard

proc rgba(c: nvg.Color): array[4, float32] =
  [c.r.float32, c.g.float32, c.b.float32, c.a.float32]

proc backend(userPtr: pointer): ptr KoiWgpuBackend =
  cast[ptr KoiWgpuBackend](userPtr)

proc textureMode(b: KoiWgpuBackend, paint: ptr nvg.Paint): float32 =
  if paint.image == nvg.NoImage:
    0'f32
  else:
    let textureId = int(paint.image)
    if b.textures.hasKey(textureId) and b.textures[textureId].alphaOnly:
      2'f32
    else:
      1'f32

proc textureId(paint: ptr nvg.Paint): int =
  if paint.image == nvg.NoImage:
    0
  else:
    int(paint.image)

proc appendVertex(
    b: var KoiWgpuBackend,
    v: NvgVertex,
    color: array[4, float32],
    mode: float32,
    aaMult: float32,
) =
  if b.width <= 0'f32 or b.height <= 0'f32:
    return

  b.vertices.add GpuVertex(
    x: (v.x.float32 / b.width) * 2'f32 - 1'f32,
    y: 1'f32 - (v.y.float32 / b.height) * 2'f32,
    u: v.u.float32,
    v: v.v.float32,
    r: color[0],
    g: color[1],
    b: color[2],
    a: color[3],
    mode: mode,
    aaMult: aaMult,
  )

proc appendTriangleList(
    b: var KoiWgpuBackend, verts: ptr NvgVertex, count: int, paint: ptr nvg.Paint
) =
  if verts.isNil or count < 3:
    return

  let
    first = b.vertices.len.uint32
    color = rgba(paint.innerColor)
    mode = b.textureMode(paint)
    src = cast[ptr UncheckedArray[NvgVertex]](verts)

  for i in 0 ..< count:
    b.appendVertex(src[i], color, mode, 0'f32)

  b.drawCalls.add DrawCall(
    first: first, count: count.uint32, textureId: textureId(paint)
  )

proc appendFan(
    b: var KoiWgpuBackend,
    verts: ptr NvgVertex,
    count: int,
    paint: ptr nvg.Paint,
    aaMult: float32,
) =
  if verts.isNil or count < 3:
    return

  let
    first = b.vertices.len.uint32
    color = rgba(paint.innerColor)
    mode = b.textureMode(paint)
    src = cast[ptr UncheckedArray[NvgVertex]](verts)

  for i in 1 ..< count - 1:
    b.appendVertex(src[0], color, mode, aaMult)
    b.appendVertex(src[i], color, mode, aaMult)
    b.appendVertex(src[i + 1], color, mode, aaMult)

  let added = b.vertices.len.uint32 - first
  if added > 0:
    b.drawCalls.add DrawCall(first: first, count: added, textureId: textureId(paint))

proc appendStrip(
    b: var KoiWgpuBackend,
    verts: ptr NvgVertex,
    count: int,
    paint: ptr nvg.Paint,
    aaMult: float32,
) =
  if verts.isNil or count < 3:
    return

  let
    first = b.vertices.len.uint32
    color = rgba(paint.innerColor)
    mode = b.textureMode(paint)
    src = cast[ptr UncheckedArray[NvgVertex]](verts)

  for i in 0 ..< count - 2:
    if (i and 1) == 0:
      b.appendVertex(src[i], color, mode, aaMult)
      b.appendVertex(src[i + 1], color, mode, aaMult)
      b.appendVertex(src[i + 2], color, mode, aaMult)
    else:
      b.appendVertex(src[i + 1], color, mode, aaMult)
      b.appendVertex(src[i], color, mode, aaMult)
      b.appendVertex(src[i + 2], color, mode, aaMult)

  let added = b.vertices.len.uint32 - first
  if added > 0:
    b.drawCalls.add DrawCall(first: first, count: added, textureId: textureId(paint))

proc createTexture(
    b: var KoiWgpuBackend, width, height: int, alphaOnly: bool, data: ptr cuchar
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
    var dst = TexelCopyTextureInfo(
      texture: result.texture,
      mipLevel: 0,
      origin: Origin3D(x: 0, y: 0, z: 0),
      aspect: TextureAspect.All,
    )
    var layout = TexelCopyBufferLayout(
      offset: 0, bytesPerRow: bytesPerPixel * width.uint32, rowsPerImage: height.uint32
    )
    b.queue.write(
      dst.addr,
      cast[pointer](data),
      (bytesPerPixel * width.uint32 * height.uint32).csize_t,
      layout.addr,
      size.addr,
    )

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
    userPtr: pointer, typ, w, h, imageFlags: cint, data: ptr cuchar
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
    userPtr: pointer, image, x, y, w, h: cint, data: ptr cuchar
): cint {.cdecl.} =
  let b = backend(userPtr)
  let id = image.int
  if data.isNil or not b.textures.hasKey(id):
    return 0

  let tex = b.textures[id]
  let bytesPerPixel = if tex.alphaOnly: 1'u32 else: 4'u32
  let dataOffset = ((y.int * tex.width + x.int) * bytesPerPixel.int)
  var dst = TexelCopyTextureInfo(
    texture: tex.texture,
    mipLevel: 0,
    origin: Origin3D(x: x.uint32, y: y.uint32, z: 0),
    aspect: TextureAspect.All,
  )
  var layout = TexelCopyBufferLayout(
    offset: 0, bytesPerRow: bytesPerPixel * tex.width.uint32, rowsPerImage: h.uint32
  )
  var size = Extent3D(width: w.uint32, height: h.uint32, depthOrArrayLayers: 1)
  let dataSize =
    if h <= 1:
      bytesPerPixel * w.uint32
    else:
      bytesPerPixel * tex.width.uint32 * (h.uint32 - 1) + bytesPerPixel * w.uint32
  b.queue.write(
    dst.addr,
    cast[pointer](cast[uint](data) + dataOffset.uint),
    dataSize.csize_t,
    layout.addr,
    size.addr,
  )
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

proc renderCancel(userPtr: pointer) {.cdecl.} =
  let b = backend(userPtr)
  b.vertices.setLen(0)
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
  let aaMult = if fringe > 0: 1'f32 else: 0'f32
  for i in 0 ..< npaths.int:
    b[].appendFan(pathArray[i].fill, pathArray[i].nfill.int, paint, aaMult)
    b[].appendStrip(pathArray[i].stroke, pathArray[i].nstroke.int, paint, aaMult)

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
  let aaMult =
    if fringe > 0:
      ((strokeWidth * 0.5 + fringe * 0.5) / fringe).float32
    else:
      0'f32
  for i in 0 ..< npaths.int:
    b[].appendStrip(pathArray[i].stroke, pathArray[i].nstroke.int, paint, aaMult)

proc renderTriangles(
    userPtr: pointer,
    paint: ptr nvg.Paint,
    compositeOperation: nvg.CompositeOperationState,
    scissor: ptr NvgScissor,
    verts: ptr NvgVertex,
    nverts: cint,
    fringe: cfloat,
) {.cdecl.} =
  backend(userPtr)[].appendTriangleList(verts, nverts.int, paint)

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

proc renderFlush(userPtr: pointer) {.cdecl.} =
  let b = backend(userPtr)
  if b.vertices.len == 0:
    return

  let byteLen = (b.vertices.len * sizeof(GpuVertex)).uint64
  b[].ensureVertexBuffer(byteLen)
  b.queue.write(b.vertexBuffer, 0'u64, b.vertices[0].addr, byteLen.csize_t)

  var surfaceTexture = SurfaceTexture()
  b.surface.getCurrentTexture(surfaceTexture.addr)
  case surfaceTexture.status
  of SuccessOptimal, SuccessSuboptimal:
    discard
  of Timeout, Outdated, Lost:
    if not surfaceTexture.texture.isNil:
      surfaceTexture.texture.release()
    b.surface.configure(b.config.addr)
    return
  else:
    return

  let nextTexture = surfaceTexture.texture.create(nil)
  let encoder = b.device.create(
    vaddr CommandEncoderDescriptor(
      nextInChain: nil, label: "Koi NanoVG command encoder".toStringView()
    )
  )
  var renderPassDesc = RenderPassDescriptor(
    nextInChain: nil,
    label: "Koi NanoVG render pass".toStringView(),
    colorAttachmentCount: 1,
    colorAttachments: vaddr RenderPassColorAttachment(
      view: nextTexture,
      resolveTarget: nil,
      loadOp: Clear,
      storeOp: Store,
      clearValue: wgpu.Color(r: 0.08, g: 0.08, b: 0.08, a: 1.0),
    ),
    depthStencilAttachment: nil,
    occlusionQuerySet: nil,
    timestampWrites: nil,
  )
  let pass = encoder.begin(renderPassDesc.addr)
  pass.set(b.pipeline)
  pass.setVertexBuffer(0, b.vertexBuffer, 0, byteLen)
  for call in b.drawCalls:
    if call.textureId != 0 and b.textures.hasKey(call.textureId):
      pass.set(0, b.textures[call.textureId].bindGroup, 0, nil)
    else:
      pass.set(0, b.white.bindGroup, 0, nil)
    pass.draw(call.count, 1, call.first, 0)
  pass.End()
  nextTexture.release()

  let commandBuffer = encoder.finish(
    vaddr CommandBufferDescriptor(
      nextInChain: nil, label: "Koi NanoVG command buffer".toStringView()
    )
  )
  b.queue.submit(1, commandBuffer.addr)
  discard b.surface.present()

  b.vertices.setLen(0)
  b.drawCalls.setLen(0)

proc renderDelete(userPtr: pointer) {.cdecl.} =
  let b = backend(userPtr)
  for texture in b.textures.values:
    releaseTexture(texture)
  b.textures.clear()
  releaseTexture(b.white)
  if not b.vertexBuffer.isNil:
    b.vertexBuffer.release()
  if not b.params.isNil:
    dealloc(b.params)
    b.params = nil

const shaderCode =
  """
struct VertexIn {
  @location(0) pos: vec2<f32>,
  @location(1) uv: vec2<f32>,
  @location(2) color: vec4<f32>,
  @location(3) mode: f32,
  @location(4) aaMult: f32,
};

struct VertexOut {
  @builtin(position) pos: vec4<f32>,
  @location(0) uv: vec2<f32>,
  @location(1) color: vec4<f32>,
  @location(2) mode: f32,
  @location(3) aaMult: f32,
};

@group(0) @binding(0) var image: texture_2d<f32>;
@group(0) @binding(1) var imageSampler: sampler;

@vertex
fn vs_main(input: VertexIn) -> VertexOut {
  var out: VertexOut;
  out.pos = vec4<f32>(input.pos, 0.0, 1.0);
  out.uv = input.uv;
  out.color = input.color;
  out.mode = input.mode;
  out.aaMult = input.aaMult;
  return out;
}

fn edge_alpha(uv: vec2<f32>, aaMult: f32) -> f32 {
  if aaMult <= 0.0 {
    return 1.0;
  }

  let x = min(1.0, (1.0 - abs(uv.x * 2.0 - 1.0)) * aaMult);
  let y = min(1.0, uv.y);
  return x * y;
}

@fragment
fn fs_main(input: VertexOut) -> @location(0) vec4<f32> {
  let edgeAlpha = edge_alpha(input.uv, input.aaMult);
  if input.mode < 0.5 {
    let alpha = input.color.a * edgeAlpha;
    return vec4<f32>(input.color.rgb * alpha, alpha);
  }

  let sample = textureSample(image, imageSampler, input.uv);
  if input.mode < 1.5 {
    let alpha = input.color.a * sample.a * edgeAlpha;
    return vec4<f32>(input.color.rgb * sample.rgb * alpha, alpha);
  }

  let alpha = input.color.a * sample.r * edgeAlpha;
  return vec4<f32>(input.color.rgb * alpha, alpha);
}
"""

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
  b.surfaceFormat = cast[ptr UncheckedArray[TextureFormat]](caps.formats)[0]
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

  var attributes = [
    VertexAttribute(format: VertexFormat.Float32x2, offset: 0, shaderLocation: 0),
    VertexAttribute(format: VertexFormat.Float32x2, offset: 8, shaderLocation: 1),
    VertexAttribute(format: VertexFormat.Float32x4, offset: 16, shaderLocation: 2),
    VertexAttribute(format: VertexFormat.Float32, offset: 32, shaderLocation: 3),
    VertexAttribute(format: VertexFormat.Float32, offset: 36, shaderLocation: 4),
  ]
  var vertexLayout = VertexBufferLayout(
    arrayStride: sizeof(GpuVertex).uint64,
    stepMode: VertexStepMode.Vertex,
    attributeCount: attributes.len.uint32,
    attributes: attributes[0].addr,
  )

  var shaderDesc = wgsl.toDescriptor(shaderCode, label = "Koi NanoVG shader")
  let shader = b.device.create(shaderDesc.addr)
  var blend = BlendState(
    alpha: BlendComponent(
      operation: wgpu.BlendOperation.Add,
      srcFactor: wgpu.BlendFactor.One,
      dstFactor: wgpu.BlendFactor.OneMinusSrcAlpha,
    ),
    color: BlendComponent(
      operation: wgpu.BlendOperation.Add,
      srcFactor: wgpu.BlendFactor.One,
      dstFactor: wgpu.BlendFactor.OneMinusSrcAlpha,
    ),
  )
  var target = ColorTargetState(
    nextInChain: nil,
    format: b.surfaceFormat,
    blend: blend.addr,
    writeMask: ColorWriteMask_All,
  )

  b.pipeline = b.device.create(
    vaddr RenderPipelineDescriptor(
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
      depthStencil: nil,
      multisample: MultisampleState(
        nextInChain: nil,
        count: 1,
        mask: uint32.high,
        alphaToCoverageEnabled: false.uint32,
      ),
      fragment: vaddr FragmentState(
        nextInChain: nil,
        module: shader,
        entryPoint: "fs_main".toStringView(),
        constantCount: 0,
        constants: nil,
        targetCount: 1,
        targets: target.addr,
      ),
    )
  )

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
  b.white = b.createTexture(1, 1, false, cast[ptr cuchar](whitePixel[0].addr))

proc initKoiWgpuBackend*(
    b: var KoiWgpuBackend, display, wlSurface: pointer, width, height: uint32
) =
  b.instance = wgpu.create(vaddr InstanceDescriptor(nextInChain: nil))
  doAssert not b.instance.isNil, "Could not initialize WebGPU"
  b.surface = b.instance.create(
    vaddr SurfaceDescriptor(
      label: "Koi WebGPU Wayland surface".toStringView(),
      nextInChain: cast[ptr ChainedStruct](vaddr SurfaceSourceWaylandSurface(
        chain: ChainedStruct(next: nil, sType: SType.SurfaceSourceWaylandSurface),
        display: display,
        surface: wlSurface,
      )),
    )
  )
  doAssert not b.surface.isNil, "Could not create WebGPU surface"
  b.nextTextureId = 1
  b.requestAdapter()
  b.requestDevice()
  b.configureSurface(width, height)
  b.createPipeline()

proc resizeKoiWgpuBackend*(b: var KoiWgpuBackend, width, height: uint32) =
  if width == 0 or height == 0:
    return
  if b.config.width == width and b.config.height == height:
    return

  b.config.width = width
  b.config.height = height
  b.surface.configure(b.config.addr)

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
