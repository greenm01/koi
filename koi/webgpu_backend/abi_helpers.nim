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

func csv(values: seq[string]): string =
  if values.len == 0:
    "(none)"
  else:
    values.join(", ")

proc enumNames[T](values: ptr T, count: csize_t): seq[string] =
  if values.isNil:
    return
  let items = cast[ptr UncheckedArray[T]](values)
  for i in 0 ..< count.int:
    result.add($items[i])

proc supportedFeatureNames(device: Device): seq[string] =
  if device.isNil:
    return
  for feature in WebGpuTrackedFeatures:
    if device.has(feature) != 0:
      result.add($feature)

proc adapterInfo(device: Device): AdapterInfo =
  if not device.isNil:
    discard device.getAdapterInfo(result.addr)

proc deviceLimits(device: Device): Limits =
  if not device.isNil:
    discard device.get(result.addr)

proc rgba(c: nvg.Color): array[4, float32] =
  [c.r.float32, c.g.float32, c.b.float32, c.a.float32]

func inputVertex(v: NvgVertex): WebGpuInputVertex =
  WebGpuInputVertex(
    x: v.x.float32,
    y: v.y.float32,
    u: v.u.float32,
    v: v.v.float32,
    maskU: v.u.float32,
    maskV: v.v.float32,
  )

func cross(a, b, c: NvgVertex): float32 =
  let
    abx = b.x.float32 - a.x.float32
    aby = b.y.float32 - a.y.float32
    bcx = c.x.float32 - b.x.float32
    bcy = c.y.float32 - b.y.float32
  abx * bcy - aby * bcx

func isConvexFill(verts: ptr NvgVertex, count: int): bool =
  if verts.isNil or count < 3:
    return false

  let src = cast[ptr UncheckedArray[NvgVertex]](verts)
  var winding = 0
  for i in 0 ..< count:
    let
      turn = cross(src[i], src[(i + 1) mod count], src[(i + 2) mod count])
      nextWinding =
        if turn > 1e-5'f32:
          1
        elif turn < -1e-5'f32:
          -1
        else:
          0
    if nextWinding == 0:
      continue
    if winding == 0:
      winding = nextWinding
    elif winding != nextWinding:
      return false

  winding != 0

func isConvexPath(path: NvgPath): bool =
  path.convex != 0 or isConvexFill(path.fill, path.nfill.int)

func invertTransform(xform: array[6, cfloat], inverse: var array[6, float32]): bool =
  let
    a = xform[0].float32
    b = xform[1].float32
    c = xform[2].float32
    d = xform[3].float32
    e = xform[4].float32
    f = xform[5].float32
    det = a * d - c * b

  if abs(det) < 1e-6'f32:
    return false

  let invDet = 1'f32 / det
  inverse[0] = d * invDet
  inverse[1] = -b * invDet
  inverse[2] = -c * invDet
  inverse[3] = a * invDet
  inverse[4] = (c * f - d * e) * invDet
  inverse[5] = (b * e - a * f) * invDet
  true

proc isGradientPaint(paint: ptr nvg.Paint): bool =
  paint.image == nvg.NoImage and paint.extent[0] != 0 and paint.extent[1] != 0 and
    paint.feather > 0

proc paintParams(paint: ptr nvg.Paint): array[4, float32] =
  if paint.isGradientPaint:
    [
      paint.extent[0].float32,
      paint.extent[1].float32,
      paint.radius.float32,
      paint.feather.float32,
    ]
  else:
    [0'f32, 0, 0, 0]

proc paintVertex(v: NvgVertex, paint: ptr nvg.Paint): WebGpuInputVertex =
  result = inputVertex(v)
  if (paint.image == nvg.NoImage and not paint.isGradientPaint) or paint.extent[0] == 0 or
      paint.extent[1] == 0:
    return

  var inverse: array[6, float32]
  if not invertTransform(paint.xform, inverse):
    return

  let
    x = v.x.float32
    y = v.y.float32
    px = inverse[0] * x + inverse[2] * y + inverse[4]
    py = inverse[1] * x + inverse[3] * y + inverse[5]

  if paint.isGradientPaint:
    result.u = px
    result.v = py
  else:
    result.u = px / paint.extent[0].float32
    result.v = py / paint.extent[1].float32

proc backend(userPtr: pointer): ptr KoiWgpuBackend =
  cast[ptr KoiWgpuBackend](userPtr)
