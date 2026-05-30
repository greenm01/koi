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
