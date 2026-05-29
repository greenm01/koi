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
) =
  alias(ui, g_uiState)
  alias(sb, ui.scrollBarState)
  alias(s, style)

  var value = value_out.clampToRange(startVal, endVal)

  let valueRange = scrollBarRange(startVal, endVal)
  let thumbSize = effectiveScrollBarThumbSize(thumbSize, startVal, endVal)
  let clickStep = if clickStep > valueRange: -1.0 else: clickStep

  let hitBounds = slot.previousBounds

  # Calculate current thumb position
  let
    thumbW =
      scrollBarThumbLength(
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

  discard captureDragWidget(id, hit, allowActiveCapture = allowFocusCaptured)

  let insideThumb = mouseInside(thumbX, hitBounds.y, thumbW, hitBounds.h)

  # New thumb position & value calculation
  var
    newThumbX = thumbX
    newValue = value

  func calcNewValue(newThumbX: float): float =
    scrollBarValueFromThumb(newThumbX, thumbMinX, thumbMaxX, startVal, endVal)

  proc calcNewValueTrackClick(newValue: float): float =
    scrollBarTrackClickValue(newValue, startVal, endVal, sb.clickDir, clickStep)

  if isActive(id):
    case sb.state
    of sbsDefault:
      if insideThumb:
        ui.x0 = ui.mx
        if shiftDown():
          disableCursor()
          sb.state = sbsDragHidden
        else:
          sb.state = sbsDragNormal
        ui.widgetMouseDrag = true
      else:
        let s = sgn(endVal - startVal).float
        if ui.mx < thumbX:
          sb.clickDir = -1 * s
        else:
          sb.clickDir = 1 * s
        sb.state = sbsTrackClickFirst
        ui.t0 = core.currentTime()
    of sbsDragNormal:
      if shiftDown():
        disableCursor()
        sb.state = sbsDragHidden
      else:
        let dx = ui.dx - ui.x0

        newThumbX = clamp(thumbX + dx, thumbMinX, thumbMaxX)
        newValue = calcNewValue(newThumbX)

        ui.x0 = clamp(ui.dx, thumbMinX, thumbMaxX + thumbW)
    of sbsDragHidden:
      if shiftDown():
        let d =
          if altDown(): ScrollBarUltraFineDragDivisor else: ScrollBarFineDragDivisor
        let dx = (ui.dx - ui.x0) / d

        newThumbX = clamp(thumbX + dx, thumbMinX, thumbMaxX)
        newValue = calcNewValue(newThumbX)

        ui.x0 = ui.dx
        ui.dragX = newThumbX + thumbW * 0.5
        ui.dragY = -1.0
      else:
        sb.state = sbsDragNormal
        showCursor()
        cursorPosX(ui.dragX)
        ui.dx = ui.dragX
        ui.x0 = ui.dragX
    of sbsTrackClickFirst:
      newValue = calcNewValueTrackClick(newValue)
      newThumbX = calcThumbX(newValue)

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
          newValue = calcNewValueTrackClick(newValue)
          newThumbX = calcThumbX(newValue)

          if sb.clickDir * sgn(endVal - startVal).float > 0:
            if newThumbX + thumbW > ui.mx:
              newThumbX = thumbX
              newValue = value
          else:
            if newThumbX < ui.mx:
              newThumbX = thumbX
              newValue = value

          ui.t0 = core.currentTime()
      else:
        ui.t0 = core.currentTime()
      requestFrames()

  value_out = newValue

  # Draw scrollbar
  addLayoutDrawLayer(ui.currentLayer, slot.nodeId, vg, bounds):
    let dy = abs(bounds.y - ui.my)
    let withinX = ui.mx >= bounds.x and ui.mx <= bounds.x + bounds.w

    if not s.autoFade or (
      s.autoFade and dy < s.autoFadeDistance and withinX and
      (not ui.focusCaptured or allowFocusCaptured)
    ):
      let state = dragWidgetState(id)

      var sw = s.trackStrokeWidth
      var (x, y, w, h) =
        snapToGrid(bounds.x, bounds.y, bounds.w, bounds.h, sw)
      let
        drawThumbW =
          scrollBarThumbLength(
            w, s.thumbPad, s.thumbMinSize, thumbSize, startVal, endVal
          )
        drawThumbH = h - s.thumbPad * 2
        drawThumbMinX = x + s.thumbPad
        drawThumbMaxX = x + w - s.thumbPad - drawThumbW
        drawThumbX =
          scrollBarThumbFromValue(
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
) =
  let (x, y) = addDrawOffset(x, y)
  let slot = layoutSlot(id, rect(x, y, w, h))
  horizScrollBarWithSlot(
    slot, id, startVal, endVal, value_out, tooltip, thumbSize, clickStep, style,
    allowFocusCaptured,
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
) =
  alias(ui, g_uiState)
  alias(sb, ui.scrollBarState)
  alias(s, style)

  var value = value_out.clampToRange(startVal, endVal)

  let valueRange = scrollBarRange(startVal, endVal)
  let thumbSize = effectiveScrollBarThumbSize(thumbSize, startVal, endVal)
  let clickStep = if clickStep > valueRange: -1.0 else: clickStep

  let hitBounds = slot.previousBounds

  # Calculate current thumb position
  let
    thumbH =
      scrollBarThumbLength(
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

  discard captureDragWidget(id, hit, allowActiveCapture = allowFocusCaptured)

  let insideThumb = mouseInside(hitBounds.x, thumbY, hitBounds.w, thumbH)

  # New thumb position & value calculation
  var
    newThumbY = thumbY
    newValue = value

  func calcNewValue(newThumbY: float): float =
    scrollBarValueFromThumb(newThumbY, thumbMinY, thumbMaxY, startVal, endVal)

  proc calcNewValueTrackClick(): float =
    scrollBarTrackClickValue(newValue, startVal, endVal, sb.clickDir, clickStep)

  if isActive(id):
    case sb.state
    of sbsDefault:
      if insideThumb:
        ui.y0 = ui.my
        if shiftDown():
          disableCursor()
          sb.state = sbsDragHidden
        else:
          sb.state = sbsDragNormal
        ui.widgetMouseDrag = true
      else:
        let s = sgn(endVal - startVal).float
        if ui.my < thumbY:
          sb.clickDir = -1 * s
        else:
          sb.clickDir = 1 * s
        sb.state = sbsTrackClickFirst
        ui.t0 = core.currentTime()
    of sbsDragNormal:
      if shiftDown():
        disableCursor()
        sb.state = sbsDragHidden
      else:
        let dy = ui.dy - ui.y0

        newThumbY = clamp(thumbY + dy, thumbMinY, thumbMaxY)
        newValue = calcNewValue(newThumbY)

        ui.y0 = clamp(ui.dy, thumbMinY, thumbMaxY + thumbH)
    of sbsDragHidden:
      markHot(id)

      if shiftDown():
        let d =
          if altDown(): ScrollBarUltraFineDragDivisor else: ScrollBarFineDragDivisor
        let dy = (ui.dy - ui.y0) / d

        newThumbY = clamp(thumbY + dy, thumbMinY, thumbMaxY)
        newValue = calcNewValue(newThumbY)

        ui.y0 = ui.dy
        ui.dragX = -1.0
        ui.dragY = newThumbY + thumbH * 0.5
      else:
        sb.state = sbsDragNormal
        showCursor()
        cursorPosY(ui.dragY)
        ui.dy = ui.dragY
        ui.y0 = ui.dragY
    of sbsTrackClickFirst:
      newValue = calcNewValueTrackClick()
      newThumbY = calcThumbY(newValue)

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
          newValue = calcNewValueTrackClick()
          newThumbY = calcThumbY(newValue)

          if sb.clickDir * sgn(endVal - startVal).float > 0:
            if newThumbY + thumbH > ui.my:
              newThumbY = thumbY
              newValue = value
          else:
            if newThumbY < ui.my:
              newThumbY = thumbY
              newValue = value

          ui.t0 = core.currentTime()
      else:
        ui.t0 = core.currentTime()
      requestFrames()

  value_out = newValue

  # Draw scrollbar
  addLayoutDrawLayer(ui.currentLayer, slot.nodeId, vg, bounds):
    let dx = abs(bounds.x - ui.mx)
    let withinY = ui.my >= bounds.y and ui.my <= bounds.y + bounds.h

    if not s.autoFade or (
      s.autoFade and dx < s.autoFadeDistance and withinY and
      (not ui.focusCaptured or allowFocusCaptured)
    ):
      let state = dragWidgetState(id)

      var sw = s.trackStrokeWidth
      var (x, y, w, h) =
        snapToGrid(bounds.x, bounds.y, bounds.w, bounds.h, sw)
      let
        drawThumbW = w - s.thumbPad * 2
        drawThumbH =
          scrollBarThumbLength(
            h, s.thumbPad, s.thumbMinSize, thumbSize, startVal, endVal
          )
        drawThumbMinY = y + s.thumbPad
        drawThumbMaxY = y + h - s.thumbPad - drawThumbH
        drawThumbY =
          scrollBarThumbFromValue(
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
) =
  let (x, y) = addDrawOffset(x, y)
  let slot = layoutSlot(id, rect(x, y, w, h))
  vertScrollBarWithSlot(
    slot, id, startVal, endVal, value_out, tooltip, thumbSize, clickStep, style,
    allowFocusCaptured,
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
) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)

  horizScrollBar(
    id, x, y, w, h, startVal, endVal, value, tooltip, thumbSize, clickStep, style,
    allowFocusCaptured,
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
) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)

  vertScrollBar(
    id, x, y, w, h, startVal, endVal, value, tooltip, thumbSize, clickStep, style,
    allowFocusCaptured,
  )
