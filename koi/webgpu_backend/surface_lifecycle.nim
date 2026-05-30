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
  b.availableSurfaceFormats = enumNames(caps.formats, caps.formatCount)
  b.availablePresentModes = enumNames(caps.presentModes, caps.presentModeCount)
  b.availableAlphaModes = enumNames(caps.alphaModes, caps.alphaModeCount)
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
  b.surfaceKind = handle.kind
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
