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
