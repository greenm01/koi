import std/math

import nanovg

import koi/types
import koi/core
import koi/drawing
import koi/layout
import koi/rect
import koi/input
import koi/defaults
import koi/internal/algorithms
import koi/internal/widget_behavior
import koi/widgets/common
import koi/utils

const
  ScrollBarFineDragDivisor = 10.0
  ScrollBarUltraFineDragDivisor = 100.0
  ScrollBarTrackClickRepeatDelay = 0.3
  ScrollBarTrackClickRepeatTimeout = 0.05

type ScrollBarAxis = enum
  sbaHorizontal
  sbaVertical

func axisMouse(ui: UIState, axis: ScrollBarAxis): float =
  case axis
  of sbaHorizontal: ui.mx
  of sbaVertical: ui.my

func axisDrag(ui: UIState, axis: ScrollBarAxis): float =
  case axis
  of sbaHorizontal: ui.dx
  of sbaVertical: ui.dy

func axisDragOrigin(ui: UIState, axis: ScrollBarAxis): float =
  case axis
  of sbaHorizontal: ui.x0
  of sbaVertical: ui.y0

proc setAxisDragOrigin(ui: var UIState, axis: ScrollBarAxis, value: float) =
  case axis
  of sbaHorizontal:
    ui.x0 = value
  of sbaVertical:
    ui.y0 = value

proc setAxisDragCursor(
    ui: var UIState, axis: ScrollBarAxis, thumbPos, thumbLength: float
) =
  case axis
  of sbaHorizontal:
    ui.dragX = thumbPos + thumbLength * 0.5
    ui.dragY = -1.0
  of sbaVertical:
    ui.dragX = -1.0
    ui.dragY = thumbPos + thumbLength * 0.5

proc restoreAxisCursor(ui: var UIState, axis: ScrollBarAxis) =
  case axis
  of sbaHorizontal:
    cursorPosX(ui.dragX)
    ui.dx = ui.dragX
    ui.x0 = ui.dragX
  of sbaVertical:
    cursorPosY(ui.dragY)
    ui.dy = ui.dragY
    ui.y0 = ui.dragY

proc updateScrollBarInteraction(
    axis: ScrollBarAxis,
    id: ItemId,
    startVal, endVal, value, clickStep: float,
    thumbPos, thumbLength, thumbMin, thumbMax: float,
    insideThumb: bool,
): tuple[value, thumbPos: float] =
  alias(ui, g_uiState)
  alias(sb, ui.scrollBarState)
  result = (value, thumbPos)

  if not isActive(id):
    return

  case sb.state
  of sbsDefault:
    if insideThumb:
      ui.setAxisDragOrigin(axis, ui.axisMouse(axis))
      if shiftDown():
        disableCursor()
        sb.state = sbsDragHidden
      else:
        sb.state = sbsDragNormal
      ui.widgetMouseDrag = true
    else:
      sb.clickDir =
        scrollBarTrackClickDir(startVal, endVal, ui.axisMouse(axis), thumbPos)
      sb.state = sbsTrackClickFirst
      ui.t0 = core.currentTime()
  of sbsDragNormal:
    if shiftDown():
      disableCursor()
      sb.state = sbsDragHidden
    else:
      let delta = ui.axisDrag(axis) - ui.axisDragOrigin(axis)
      result.thumbPos = clamp(thumbPos + delta, thumbMin, thumbMax)
      result.value =
        scrollBarValueFromThumb(result.thumbPos, thumbMin, thumbMax, startVal, endVal)
      ui.setAxisDragOrigin(
        axis, clamp(ui.axisDrag(axis), thumbMin, thumbMax + thumbLength)
      )
  of sbsDragHidden:
    if axis == sbaVertical:
      markHot(id)

    if shiftDown():
      let d = if altDown(): ScrollBarUltraFineDragDivisor else: ScrollBarFineDragDivisor
      let delta = (ui.axisDrag(axis) - ui.axisDragOrigin(axis)) / d
      result.thumbPos = clamp(thumbPos + delta, thumbMin, thumbMax)
      result.value =
        scrollBarValueFromThumb(result.thumbPos, thumbMin, thumbMax, startVal, endVal)
      ui.setAxisDragOrigin(axis, ui.axisDrag(axis))
      ui.setAxisDragCursor(axis, result.thumbPos, thumbLength)
    else:
      sb.state = sbsDragNormal
      showCursor()
      ui.restoreAxisCursor(axis)
  of sbsTrackClickFirst:
    result.value =
      scrollBarTrackClickValue(value, startVal, endVal, sb.clickDir, clickStep)
    result.thumbPos =
      scrollBarThumbFromValue(result.value, startVal, endVal, thumbMin, thumbMax)
    sb.state = sbsTrackClickDelay
    ui.t0 = core.currentTime()
    requestFrames()
  of sbsTrackClickDelay:
    if core.currentTime() - ui.t0 > ScrollBarTrackClickRepeatDelay:
      sb.state = sbsTrackClickRepeat
    requestFrames()
  of sbsTrackClickRepeat:
    if isHot(id):
      if core.currentTime() - ui.t0 > ScrollBarTrackClickRepeatTimeout:
        result = scrollBarRepeatTrackClick(
          value,
          startVal,
          endVal,
          sb.clickDir,
          clickStep,
          thumbPos,
          thumbLength,
          thumbMin,
          thumbMax,
          ui.axisMouse(axis),
        )
        ui.t0 = core.currentTime()
    else:
      ui.t0 = core.currentTime()
    requestFrames()

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

proc scrollBarPost*() =
  alias(ui, g_uiState)
  alias(sb, ui.scrollBarState)

  if not ui.mbLeftDown:
    sb.state = sbsDefault
    ui.widgetMouseDrag = false

# Templates

template horizScrollBar*(
    x, y, w, h: float,
    startVal, endVal: float,
    value: var float,
    tooltip: string = "",
    thumbSize: float = -1.0,
    clickStep: float = -1.0,
    style: ScrollBarStyle = borrowDefaultScrollBarStyle(),
    allowFocusCaptured: bool = false,
    disabled: bool = false,
) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)

  horizScrollBar(
    id, x, y, w, h, startVal, endVal, value, tooltip, thumbSize, clickStep, style,
    allowFocusCaptured, disabled,
  )

template vertScrollBar*(
    x, y, w, h: float,
    startVal, endVal: float,
    value: var float,
    tooltip: string = "",
    thumbSize: float = -1.0,
    clickStep: float = -1.0,
    style: ScrollBarStyle = borrowDefaultScrollBarStyle(),
    allowFocusCaptured: bool = false,
    disabled: bool = false,
) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)

  vertScrollBar(
    id, x, y, w, h, startVal, endVal, value, tooltip, thumbSize, clickStep, style,
    allowFocusCaptured, disabled,
  )
