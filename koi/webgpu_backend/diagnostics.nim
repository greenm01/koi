proc diagnostics*(b: KoiWgpuBackend): WebGpuBackendDiagnostics =
  var info = adapterInfo(b.device)
  let limits = deviceLimits(b.device)
  result = WebGpuBackendDiagnostics(
    surfaceKind: $b.surfaceKind,
    adapterVendor: $info.vendor,
    adapterArchitecture: $info.architecture,
    adapterDevice: $info.device,
    adapterDescription: $info.description,
    adapterBackendType: $info.backendType,
    adapterType: $info.adapterType,
    surfaceFormat: $b.surfaceFormat,
    surfaceAlpha: $b.surfaceAlpha,
    stencilFormat: $WebGpuStencilFormat,
    surfaceFormats: b.availableSurfaceFormats,
    presentModes: b.availablePresentModes,
    alphaModes: b.availableAlphaModes,
    width: b.config.width,
    height: b.config.height,
    devicePixelRatio: b.devicePixelRatio,
    maxTextureDimension2D: limits.maxTextureDimension2D,
    maxBufferSize: limits.maxBufferSize,
    maxVertexBuffers: limits.maxVertexBuffers,
    maxVertexAttributes: limits.maxVertexAttributes,
    maxBindGroups: limits.maxBindGroups,
    maxColorAttachments: limits.maxColorAttachments,
    features: supportedFeatureNames(b.device),
    lastRenderStats: b.lastSubmittedStats,
  )
  info.freeMembers()

proc dumpWebGpuDiagnostics*(b: KoiWgpuBackend): string =
  let d = b.diagnostics()
  result.add("Koi WebGPU diagnostics\n")
  result.add("  surface kind: " & d.surfaceKind & "\n")
  result.add("  adapter: " & d.adapterDescription & "\n")
  result.add("  adapter vendor: " & d.adapterVendor & "\n")
  result.add("  adapter architecture: " & d.adapterArchitecture & "\n")
  result.add("  adapter device: " & d.adapterDevice & "\n")
  result.add("  adapter backend: " & d.adapterBackendType & "\n")
  result.add("  adapter type: " & d.adapterType & "\n")
  result.add("  surface format: " & d.surfaceFormat & "\n")
  result.add("  surface alpha: " & d.surfaceAlpha & "\n")
  result.add("  stencil format: " & d.stencilFormat & "\n")
  result.add("  available surface formats: " & csv(d.surfaceFormats) & "\n")
  result.add("  available present modes: " & csv(d.presentModes) & "\n")
  result.add("  available alpha modes: " & csv(d.alphaModes) & "\n")
  result.add(
    "  framebuffer: " & $d.width & "x" & $d.height & " @ " & $d.devicePixelRatio & "x\n"
  )
  result.add("  max texture dimension 2D: " & $d.maxTextureDimension2D & "\n")
  result.add("  max buffer size: " & $d.maxBufferSize & "\n")
  result.add("  max vertex buffers: " & $d.maxVertexBuffers & "\n")
  result.add("  max vertex attributes: " & $d.maxVertexAttributes & "\n")
  result.add("  max bind groups: " & $d.maxBindGroups & "\n")
  result.add("  max color attachments: " & $d.maxColorAttachments & "\n")
  result.add("  supported tracked features: " & csv(d.features) & "\n")
  result.add("  last draw calls: " & $d.lastRenderStats.drawCalls & "\n")
  result.add("  last vertices: " & $d.lastRenderStats.vertices & "\n")
  result.add("  last indices: " & $d.lastRenderStats.indices & "\n")
  result.add("  last staged bytes: " & $d.lastRenderStats.stagedBytes & "\n")
  result.add(
    "  last expanded vertex bytes: " & $d.lastRenderStats.expandedVertexBytes & "\n"
  )
