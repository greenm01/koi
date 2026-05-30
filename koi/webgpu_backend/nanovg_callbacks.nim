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

  if npaths == 1 and pathArray[0].isConvexPath:
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
