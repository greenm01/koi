proc vertScrollBarWithSlot*(
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
    thumbH = scrollBarThumbLength(
      hitBounds.h, s.thumbPad, s.thumbMinSize, thumbSize, startVal, endVal
    )
    thumbMinY = hitBounds.y + s.thumbPad
    thumbMaxY = hitBounds.y + hitBounds.h - s.thumbPad - thumbH

  func calcThumbY(value: float): float =
    scrollBarThumbFromValue(value, startVal, endVal, thumbMinY, thumbMaxY)

  let thumbY = calcThumbY(value)

  # Hit testing
  let hit =
    if allowFocusCaptured:
      mouseInside(hitBounds.x, hitBounds.y, hitBounds.w, hitBounds.h)
    else:
      isHit(hitBounds.x, hitBounds.y, hitBounds.w, hitBounds.h)

  discard captureDragWidget(
    id, hit, allowActiveCapture = allowFocusCaptured, disabled = disabled
  )

  let insideThumb = mouseInside(hitBounds.x, thumbY, hitBounds.w, thumbH)

  # New thumb position & value calculation
  var
    newThumbY = thumbY
    newValue = value

  if not disabled:
    let next = updateScrollBarInteraction(
      sbaVertical, id, startVal, endVal, value, clickStep, thumbY, thumbH, thumbMinY,
      thumbMaxY, insideThumb,
    )
    newValue = next.value
    newThumbY = next.thumbPos

  value_out = newValue

  # Draw scrollbar
  addLayoutDrawLayer(ui.currentLayer, slot.nodeId, vg, bounds):
    let dx = abs(bounds.x - ui.mx)
    let withinY = ui.my >= bounds.y and ui.my <= bounds.y + bounds.h

    if not s.autoFade or (
      s.autoFade and dx < s.autoFadeDistance and withinY and
      (not ui.focusCaptured or allowFocusCaptured)
    ):
      let state = dragWidgetState(id, disabled)

      var sw = s.trackStrokeWidth
      var (x, y, w, h) = snapToGrid(bounds.x, bounds.y, bounds.w, bounds.h, sw)
      let
        drawThumbW = w - s.thumbPad * 2
        drawThumbH = scrollBarThumbLength(
          h, s.thumbPad, s.thumbMinSize, thumbSize, startVal, endVal
        )
        drawThumbMinY = y + s.thumbPad
        drawThumbMaxY = y + h - s.thumbPad - drawThumbH
        drawThumbY = scrollBarThumbFromValue(
          newValue, startVal, endVal, drawThumbMinY, drawThumbMaxY
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
            min(dx, s.autoFadeDistance) / s.autoFadeDistance,
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
        x + s.thumbPad, drawThumbY, drawThumbW, drawThumbH, s.thumbCornerRadius
      )
      vg.fill()
      vg.stroke()

      vg.globalAlpha(1.0)

  if isHot(id):
    handleTooltip(id, tooltip)

# vertScrollBar()

proc vertScrollBar*(
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
  vertScrollBarWithSlot(
    slot, id, startVal, endVal, value_out, tooltip, thumbSize, clickStep, style,
    allowFocusCaptured, disabled,
  )
