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
      format: WebGpuStencilFormat,
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
      format: WebGpuStencilFormat,
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

  let nextTexture = surfaceTexture.texture.create(
    vaddr TextureViewDescriptor(
      nextInChain: nil,
      label: "Koi NanoVG swapchain texture view".toStringView(),
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
