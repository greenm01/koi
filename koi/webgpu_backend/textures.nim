proc createTexture(
    b: var KoiWgpuBackend, width, height: int, alphaOnly: bool, data: ptr uint8
): GpuTexture =
  let
    format = if alphaOnly: TextureFormat.R8Unorm else: TextureFormat.RGBA8Unorm
    bytesPerPixel = if alphaOnly: 1'u32 else: 4'u32
    size = Extent3D(width: width.uint32, height: height.uint32, depthOrArrayLayers: 1)
    textureLabel =
      "Koi NanoVG " & (if alphaOnly: "alpha" else: "rgba") & " texture " & $width & "x" &
      $height
    viewLabel =
      "Koi NanoVG " & (if alphaOnly: "alpha" else: "rgba") & " texture view " & $width &
      "x" & $height
    bindGroupLabel =
      "Koi NanoVG " & (if alphaOnly: "alpha" else: "rgba") & " bind group " & $width &
      "x" & $height

  result.texture = b.device.create(
    vaddr TextureDescriptor(
      nextInChain: nil,
      label: textureLabel.toStringView(),
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
      label: viewLabel.toStringView(),
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
      label: bindGroupLabel.toStringView(),
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
