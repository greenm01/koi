proc horizScrollBarWithSlot*(
    slot: LayoutSlot,
    id: ItemId,
    startVal: float,
    endVal: float,
    value_out: var float,
    tooltip: string = "",
    thumbSize: float = -1.0,
    clickStep: float = -1.0,
    style: ScrollBarStyle = borrowDefaultScrollBarStyle(),
    allowFocusCaptured: bool = false,
    disabled: bool = false,
) =
  alias(ui, g_uiState)
  alias(s, style)

  var value = value_out.clampToRange(startVal, endVal)

  let valueRange = scrollBarRange(startVal, endVal)
  let thumbSize = effectiveScrollBarThumbSize(thumbSize, startVal, endVal)
  let clickStep = if clickStep > valueRange: -1.0 else: clickStep

  let hitBounds = slot.previousBounds

  # Calculate current thumb position
  let
    thumbW = scrollBarThumbLength(
      hitBounds.w, s.thumbPad, s.thumbMinSize, thumbSize, startVal, endVal
    )
    thumbMinX = hitBounds.x + s.thumbPad
    thumbMaxX = hitBounds.x + hitBounds.w - s.thumbPad - thumbW

  func calcThumbX(val: float): float =
    scrollBarThumbFromValue(val, startVal, endVal, thumbMinX, thumbMaxX)

  let thumbX = calcThumbX(value)

  # Hit testing
  let hit =
    if allowFocusCaptured:
      mouseInside(hitBounds.x, hitBounds.y, hitBounds.w, hitBounds.h)
    else:
      isHit(hitBounds.x, hitBounds.y, hitBounds.w, hitBounds.h)

  discard captureDragWidget(
    id, hit, allowActiveCapture = allowFocusCaptured, disabled = disabled
  )

  let insideThumb = mouseInside(thumbX, hitBounds.y, thumbW, hitBounds.h)

  # New thumb position & value calculation
  var
    newThumbX = thumbX
    newValue = value

  if not disabled:
    let next = updateScrollBarInteraction(
      sbaHorizontal, id, startVal, endVal, value, clickStep, thumbX, thumbW, thumbMinX,
      thumbMaxX, insideThumb,
    )
    newValue = next.value
    newThumbX = next.thumbPos

  value_out = newValue

  # Draw scrollbar
  addLayoutDrawLayer(ui.currentLayer, slot.nodeId, vg, bounds):
    let dy = abs(bounds.y - ui.my)
    let withinX = ui.mx >= bounds.x and ui.mx <= bounds.x + bounds.w

    if not s.autoFade or (
      s.autoFade and dy < s.autoFadeDistance and withinX and
      (not ui.focusCaptured or allowFocusCaptured)
    ):
      let state = dragWidgetState(id, disabled)

      var sw = s.trackStrokeWidth
      var (x, y, w, h) = snapToGrid(bounds.x, bounds.y, bounds.w, bounds.h, sw)
      let
        drawThumbW = scrollBarThumbLength(
          w, s.thumbPad, s.thumbMinSize, thumbSize, startVal, endVal
        )
        drawThumbH = h - s.thumbPad * 2
        drawThumbMinX = x + s.thumbPad
        drawThumbMaxX = x + w - s.thumbPad - drawThumbW
        drawThumbX = scrollBarThumbFromValue(
          newValue, startVal, endVal, drawThumbMinX, drawThumbMaxX
        )

      let (trackFillColor, trackStrokeColor, thumbFillColor, thumbStrokeColor) =
        case state
        of wsHover:
          (
            s.trackFillColorHover, s.trackStrokeColorHover, s.thumbFillColorHover,
            s.thumbStrokeColorHover,
          )
        of wsDown, wsActiveDown:
          (
            s.trackFillColorDown, s.trackStrokeColorDown, s.thumbFillColorDown,
            s.thumbStrokeColorDown,
          )
        else:
          (s.trackFillColor, s.trackStrokeColor, s.thumbFillColor, s.thumbStrokeColor)

      let ga =
        if s.autoFade:
          lerp(
            s.autoFadeEndAlpha,
            s.autoFadeStartAlpha,
            min(dy, s.autoFadeDistance) / s.autoFadeDistance,
          )
        else:
          1.0

      vg.globalAlpha(ga)

      # Draw track
      vg.fillColor(trackFillColor)
      vg.strokeColor(trackStrokeColor)
      vg.strokeWidth(sw)

      vg.beginPath()
      vg.roundedRect(x, y, w, h, s.trackCornerRadius)
      vg.fill()
      vg.stroke()

      # Draw thumb
      sw = s.thumbStrokeWidth
      (x, y, w, h) = snapToGrid(x, y, w, h, sw)

      vg.fillColor(thumbFillColor)
      vg.strokeColor(thumbStrokeColor)
      vg.strokeWidth(sw)

      vg.beginPath()
      vg.roundedRect(
        drawThumbX, y + s.thumbPad, drawThumbW, drawThumbH, s.thumbCornerRadius
      )
      vg.fill()
      vg.stroke()

      vg.globalAlpha(1.0)

  if isHot(id):
    handleTooltip(id, tooltip)

# horizScrollBar()

proc horizScrollBar*(
    id: ItemId,
    x, y, w, h: float,
    startVal: float,
    endVal: float,
    value_out: var float,
    tooltip: string = "",
    thumbSize: float = -1.0,
    clickStep: float = -1.0,
    style: ScrollBarStyle = borrowDefaultScrollBarStyle(),
    allowFocusCaptured: bool = false,
    disabled: bool = false,
) =
  let (x, y) = addDrawOffset(x, y)
  let slot = layoutSlot(id, rect(x, y, w, h))
  horizScrollBarWithSlot(
    slot, id, startVal, endVal, value_out, tooltip, thumbSize, clickStep, style,
    allowFocusCaptured, disabled,
  )

# Must be kept in sync with horizScrollBar!
