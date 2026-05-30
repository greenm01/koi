const shaderCode = staticRead("../shaders/nanovg.wgsl")

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
  let pipelineLabel =
    "Koi NanoVG render pipeline " & $key.mode & " blend=" & $(key.blend.srcRgb) & "/" &
    $(key.blend.dstRgb) & "," & $(key.blend.srcAlpha) & "/" & $(key.blend.dstAlpha)
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
    format: WebGpuStencilFormat,
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
    label: pipelineLabel.toStringView(),
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
