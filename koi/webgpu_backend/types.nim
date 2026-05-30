import std/[hashes, strutils, tables]

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
  WebGpuStencilFormat = TextureFormat.Depth24PlusStencil8
  WebGpuTrackedFeatures = [
    FeatureName.DepthClipControl, FeatureName.Depth32FloatStencil8,
    FeatureName.TimestampQuery, FeatureName.TextureCompressionBC,
    FeatureName.TextureCompressionETC2, FeatureName.TextureCompressionASTC,
    FeatureName.IndirectFirstInstance, FeatureName.ShaderF16,
    FeatureName.BGRA8UnormStorage, FeatureName.Float32Filterable,
    FeatureName.Float32Blendable, FeatureName.DualSourceBlending, FeatureName.Subgroups,
    FeatureName.CoreFeaturesAndLimits, FeatureName.PolygonModeLine,
    FeatureName.PolygonModePoint,
  ]

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

  WebGpuBackendDiagnostics* = object
    surfaceKind*: string
    adapterVendor*: string
    adapterArchitecture*: string
    adapterDevice*: string
    adapterDescription*: string
    adapterBackendType*: string
    adapterType*: string
    surfaceFormat*: string
    surfaceAlpha*: string
    stencilFormat*: string
    surfaceFormats*: seq[string]
    presentModes*: seq[string]
    alphaModes*: seq[string]
    width*: uint32
    height*: uint32
    devicePixelRatio*: float32
    maxTextureDimension2D*: uint32
    maxBufferSize*: uint64
    maxVertexBuffers*: uint32
    maxVertexAttributes*: uint32
    maxBindGroups*: uint32
    maxColorAttachments*: uint32
    features*: seq[string]
    lastRenderStats*: WebGpuRenderStats

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
    surfaceKind: KoiWgpuSurfaceKind
    surfaceFormat: TextureFormat
    surfaceAlpha: CompositeAlphaMode
    availableSurfaceFormats: seq[string]
    availablePresentModes: seq[string]
    availableAlphaModes: seq[string]
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
