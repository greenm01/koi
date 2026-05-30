proc drawColorSwatchWithSlot(
    slot: LayoutSlot,
    id: ItemId,
    color: Color,
    interactive: bool = true,
    disabled: bool = false,
): bool =
  alias(ui, g_uiState)

  if interactive and
      isHit(
        slot.previousBounds.x, slot.previousBounds.y, slot.previousBounds.w,
        slot.previousBounds.h,
      ):
    captureSimpleWidget(id, disabled)

  if interactive:
    let behavior = simpleWidgetBehavior(id, disabled)
    result = behavior.clicked

  addLayoutDrawLayer(ui.currentLayer, slot.nodeId, vg, bounds):
    let
      sw = 1.0
      (rx, ry, rw, rh) = snapToGrid(bounds.x, bounds.y, bounds.w, bounds.h, sw)
      cr = 5.0
      colorWidth = rw * 0.5

    vg.fillColor(color.withAlpha(1.0))
    vg.beginPath()
    vg.roundedRect(rx, ry, colorWidth, rh, cr, 0, 0, cr)
    vg.fill()

    vg.fillColor(color)
    vg.beginPath()
    vg.roundedRect(rx + colorWidth, ry, rw - colorWidth, rh, 0, cr, cr, 0)
    vg.fill()

    vg.strokeColor(gray(0.1))
    vg.strokeWidth(sw)
    vg.beginPath()
    vg.roundedRect(rx, ry, rw, rh, cr)
    vg.stroke()

proc drawColorSwatch(
    id: ItemId, x, y, w, h: float, color: Color, disabled: bool = false
): bool =
  let (x, y) = addDrawOffset(x, y)
  let slot = layoutSlot(id, rect(x, y, w, h))
  drawColorSwatchWithSlot(slot, id, color, disabled = disabled)

proc colorWheel(id: ItemId, x, y, w, h: float, hue, sat, val: var float) =
  alias(ui, g_uiState)
  alias(cs, ui.colorPickerState)

  let (x, y) = addDrawOffset(x, y)
  let slot = layoutSlot(id, rect(x, y, w, h))
  let hitBounds = slot.previousBounds

  func hueFromWheelAngle(a: float): float =
    let aa =
      if a > 0:
        a
      else:
        2 * PI + a
    (aa / (2 * PI) + 0.5) mod 1.0

  func edge(ax, ay, bx, by, px, py: float): float =
    (px - ax) * (by - ay) - (py - ay) * (bx - ax)

  proc wheelGeometry(
      bounds: Rect
  ): tuple[cx, cy, r0, r1, blackX, blackY, whiteX, whiteY, colorX, colorY: float] =
    result.cx = bounds.x + bounds.w * 0.5
    result.cy = bounds.y + bounds.h * 0.5
    result.r1 = min(bounds.w, bounds.h) * 0.5
    result.r0 = result.r1 - result.r1 * 0.20
    result.blackX = result.cx + result.r0 * cos(5 * PI / 6)
    result.blackY = result.cy + result.r0 * sin(5 * PI / 6)
    result.whiteX = result.cx + result.r0 * cos(PI / 6)
    result.whiteY = result.cy + result.r0 * sin(PI / 6)
    result.colorX = result.cx + result.r0 * cos(1.5 * PI)
    result.colorY = result.cy + result.r0 * sin(1.5 * PI)

  let geom = wheelGeometry(hitBounds)

  proc wheelAngleFromCursor(): float =
    arctan2(ui.my - geom.cy, ui.mx - geom.cx)

  proc cursorInHueRing(): bool =
    let distance = hypot(ui.mx - geom.cx, ui.my - geom.cy)
    distance >= geom.r0 and distance <= geom.r1

  proc triangleBarycentric(px, py: float): tuple[black, white, color: float] =
    let denom =
      edge(geom.blackX, geom.blackY, geom.whiteX, geom.whiteY, geom.colorX, geom.colorY)
    if abs(denom) < 0.000001:
      return (0.0, 0.0, 0.0)
    result.black =
      edge(geom.whiteX, geom.whiteY, geom.colorX, geom.colorY, px, py) / denom
    result.white =
      edge(geom.colorX, geom.colorY, geom.blackX, geom.blackY, px, py) / denom
    result.color =
      edge(geom.blackX, geom.blackY, geom.whiteX, geom.whiteY, px, py) / denom

  proc cursorInTriangle(): bool =
    let b = triangleBarycentric(ui.mx, ui.my)
    b.black >= 0 and b.white >= 0 and b.color >= 0

  proc triangleCursorValues(): tuple[sat, val: float] =
    var b = triangleBarycentric(ui.mx, ui.my)
    b.black = max(0.0, b.black)
    b.white = max(0.0, b.white)
    b.color = max(0.0, b.color)

    let total = b.black + b.white + b.color
    if total <= 0.000001:
      return (0.0, 0.0)
    b.black /= total
    b.white /= total
    b.color /= total

    result.val = clamp(b.white + b.color, 0.0, 1.0)
    result.sat =
      if result.val <= 0.000001:
        0.0
      else:
        clamp(b.color / result.val, 0.0, 1.0)

  if isHit(hitBounds.x, hitBounds.y, hitBounds.w, hitBounds.h):
    markHot(id)

  if cs.mouseMode == cmmNormal and isHot(id) and ui.mbLeftDown and hasNoActiveItem():
    if cursorInHueRing():
      hue = hueFromWheelAngle(wheelAngleFromCursor())
      cs.mouseMode = cmmDragWheel
      markActive(id)
      ui.focusCaptured = true
    elif cursorInTriangle():
      (sat, val) = triangleCursorValues()
      cs.mouseMode = cmmDragTriangle
      markActive(id)
      ui.focusCaptured = true
    else:
      cs.mouseMode = cmmLMBDown
      markActive(id)
  elif cs.mouseMode == cmmLMBDown:
    if not ui.mbLeftDown:
      cs.mouseMode = cmmNormal

  if cs.mouseMode == cmmDragWheel:
    if not ui.mbLeftDown:
      cs.mouseMode = cmmNormal
      ui.focusCaptured = false
    else:
      hue = hueFromWheelAngle(wheelAngleFromCursor())
  elif cs.mouseMode == cmmDragTriangle:
    if not ui.mbLeftDown:
      cs.mouseMode = cmmNormal
      ui.focusCaptured = false
    else:
      (sat, val) = triangleCursorValues()

  let
    drawHue = hue
    drawSat = sat
    drawVal = val

  addLayoutDrawLayer(ui.currentLayer, slot.nodeId, vg, bounds):
    let
      (cx, cy, r0, r1, x1, y1, x2, y2, x3, y3) = wheelGeometry(bounds)
      da = 0.5 / r1

    template trianglePath() =
      vg.beginPath()
      vg.moveTo(x1, y1)
      vg.lineTo(x2, y2)
      vg.lineTo(x3, y3)
      vg.closePath()

    vg.strokeColor(black())
    vg.strokeWidth(1.0)
    trianglePath()

    var paint = vg.linearGradient(x3, y3, x2, y2, hsla(drawHue, 1.0, 0.5, 1.0), white())
    vg.fillPaint(paint)
    vg.fill()

    paint = vg.linearGradient(
      x1, y1, x3 + (x2 - x3) * 0.5, y3 + (y2 - y3) * 0.5, black(), black(0)
    )
    trianglePath()
    vg.fillPaint(paint)
    vg.fill()

    let
      markerBlack = 1.0 - drawVal
      markerColor = drawVal * drawSat
      markerWhite = drawVal * (1.0 - drawSat)
      markerX = x1 * markerBlack + x2 * markerWhite + x3 * markerColor
      markerY = y1 * markerBlack + y2 * markerWhite + y3 * markerColor

    vg.strokeWidth(1.0)
    vg.beginPath()
    vg.circle(markerX, markerY, 5)
    vg.strokeColor(black(0.8))
    vg.stroke()
    vg.beginPath()
    vg.circle(markerX, markerY, 4)
    vg.strokeColor(white(0.8))
    vg.stroke()

    const Segments = 6
    for i in 0 ..< Segments:
      let
        a0 = float(i) / Segments * 2 * PI - da
        a1 = (float(i) + 1.0) / Segments * 2 * PI + da

      vg.beginPath()
      vg.arc(cx, cy, r0, a0, a1, pwCW)
      vg.arc(cx, cy, r1, a1, a0, pwCCW)
      vg.closePath()

      let
        r = r0 + r1
        ax = cx + cos(a0) * r * 0.5
        ay = cy + sin(a0) * r * 0.5
        bx = cx + cos(a1) * r * 0.5
        by = cy + sin(a1) * r * 0.5
        paint = vg.linearGradient(
          ax,
          ay,
          bx,
          by,
          hsla(0.5 + a0 / (2 * PI), 1.0, 0.50, 1.00),
          hsla(0.5 + a1 / (2 * PI), 1.0, 0.50, 1.00),
        )
      vg.fillPaint(paint)
      vg.fill()

    vg.save()
    vg.translate(cx, cy)
    vg.rotate(PI + drawHue * 2 * PI)
    let hueMarkerX = (r0 + r1) * 0.5
    vg.strokeWidth(1.0)
    vg.beginPath()
    vg.circle(hueMarkerX, 0, 5)
    vg.strokeColor(black(0.8))
    vg.stroke()
    vg.beginPath()
    vg.circle(hueMarkerX, 0, 4)
    vg.strokeColor(white(0.8))
    vg.stroke()
    vg.restore()
