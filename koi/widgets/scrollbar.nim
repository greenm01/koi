import std/math

import nanovg
import glfw

import koi/types
import koi/core
import koi/drawing
import koi/layout
import koi/input
import koi/defaults
import koi/widgets/common
import koi/utils

const
  ScrollBarFineDragDivisor = 10.0
  ScrollBarUltraFineDragDivisor = 100.0
  ScrollBarTrackClickRepeatDelay = 0.3
  ScrollBarTrackClickRepeatTimeout = 0.05

# horizScrollBar()

# Must be kept in sync with vertScrollBar!
proc horizScrollBar*(
    id: ItemId,
    x, y, w, h: float,
    startVal: float,
    endVal: float,
    value_out: var float,
    tooltip: string = "",
    thumbSize: float = -1.0,
    clickStep: float = -1.0,
    style: ScrollBarStyle = getDefaultScrollBarStyle(),
) =
  alias(ui, g_uiState)
  alias(sb, ui.scrollBarState)
  alias(s, style)

  var value = value_out.clampToRange(startVal, endVal)

  var thumbSize = if thumbSize > abs(startVal - endVal): -1.0 else: thumbSize
  let clickStep = if clickStep > abs(startVal - endVal): -1.0 else: clickStep

  let (x, y) = addDrawOffset(x, y)

  # Calculate current thumb position
  if thumbSize < 0:
    thumbSize = 0.000001

  let
    thumbW =
      max((w - s.thumbPad * 2) / (abs(startVal - endVal) / thumbSize), s.thumbMinSize)

    thumbH = h - s.thumbPad * 2
    thumbMinX = x + s.thumbPad
    thumbMaxX = x + w - s.thumbPad - thumbW

  func calcThumbX(val: float): float =
    let t = invLerp(startVal, endVal, val)
    lerp(thumbMinX, thumbMaxX, t)

  let thumbX = calcThumbX(value)

  # Hit testing
  if isHit(x, y, w, h):
    setHot(id)
    if ui.mbLeftDown and hasNoActiveItem():
      setActive(id)

  let insideThumb = mouseInside(thumbX, y, thumbW, h)

  # New thumb position & value calculation
  var
    newThumbX = thumbX
    newValue = value

  func calcNewValue(newThumbX: float): float =
    let t = invLerp(thumbMinX, thumbMaxX, newThumbX)
    lerp(startVal, endVal, t)

  proc calcNewValueTrackClick(newValue: float): float =
    let clickStep =
      if clickStep < 0:
        abs(startVal - endVal) * 0.1
      else:
        clickStep

    let (s, e) =
      if startVal < endVal:
        (startVal, endVal)
      else:
        (endVal, startVal)
    clamp(newValue + sb.clickDir * clickStep, s, e)

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
        ui.t0 = core.getTime()
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
        setCursorPosX(ui.dragX)
        ui.dx = ui.dragX
        ui.x0 = ui.dragX
    of sbsTrackClickFirst:
      newValue = calcNewValueTrackClick(newValue)
      newThumbX = calcThumbX(newValue)

      sb.state = sbsTrackClickDelay
      ui.t0 = core.getTime()
      setFramesLeft()
    of sbsTrackClickDelay:
      if core.getTime() - ui.t0 > ScrollBarTrackClickRepeatDelay:
        sb.state = sbsTrackClickRepeat
      setFramesLeft()
    of sbsTrackClickRepeat:
      if isHot(id):
        if core.getTime() - ui.t0 > ScrollBarTrackClickRepeatTimeout:
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

          ui.t0 = core.getTime()
      else:
        ui.t0 = core.getTime()
      setFramesLeft()

  value_out = newValue

  # Draw scrollbar
  addDrawLayer(ui.currentLayer, vg):
    let dy = abs(y - ui.my)
    let withinX = ui.mx >= x and ui.mx <= x + w

    if not s.autoFade or
        (s.autoFade and dy < s.autoFadeDistance and withinX and not ui.focusCaptured):
      let state =
        if isHot(id) and hasNoActiveItem():
          wsHover
        elif isActive(id):
          wsDown
        else:
          wsNormal

      var sw = s.trackStrokeWidth
      var (x, y, w, h) = snapToGrid(x, y, w, h, sw)

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
      vg.roundedRect(newThumbX, y + s.thumbPad, thumbW, thumbH, s.thumbCornerRadius)
      vg.fill()
      vg.stroke()

      vg.globalAlpha(1.0)

  if isHot(id):
    handleTooltip(id, tooltip)

# vertScrollBar()

# Must be kept in sync with horizScrollBar!
proc vertScrollBar*(
    id: ItemId,
    x, y, w, h: float,
    startVal: float,
    endVal: float,
    value_out: var float,
    tooltip: string = "",
    thumbSize: float = -1.0,
    clickStep: float = -1.0,
    style: ScrollBarStyle = getDefaultScrollBarStyle(),
) =
  alias(ui, g_uiState)
  alias(sb, ui.scrollBarState)
  alias(s, style)

  var value = value_out.clampToRange(startVal, endVal)

  var thumbSize = if thumbSize > abs(startVal - endVal): -1.0 else: thumbSize
  let clickStep = if clickStep > abs(startVal - endVal): -1.0 else: clickStep

  let (x, y) = addDrawOffset(x, y)

  # Calculate current thumb position
  if thumbSize < 0:
    thumbSize = 0.000001

  let
    thumbW = w - s.thumbPad * 2

    thumbH =
      max((h - s.thumbPad * 2) / (abs(startVal - endVal) / thumbSize), s.thumbMinSize)

    thumbMinY = y + s.thumbPad
    thumbMaxY = y + h - s.thumbPad - thumbH

  func calcThumbY(value: float): float =
    let t = invLerp(startVal, endVal, value)
    lerp(thumbMinY, thumbMaxY, t)

  let thumbY = calcThumbY(value)

  # Hit testing
  if isHit(x, y, w, h):
    setHot(id)
    if ui.mbLeftDown and hasNoActiveItem():
      setActive(id)

  let insideThumb = mouseInside(x, thumbY, w, thumbH)

  # New thumb position & value calculation
  var
    newThumbY = thumbY
    newValue = value

  func calcNewValue(newThumbY: float): float =
    let t = invLerp(thumbMinY, thumbMaxY, newThumbY)
    lerp(startVal, endVal, t)

  proc calcNewValueTrackClick(): float =
    let clickStep =
      if clickStep < 0:
        abs(startVal - endVal) * 0.1
      else:
        clickStep

    let (s, e) =
      if startVal < endVal:
        (startVal, endVal)
      else:
        (endVal, startVal)
    clamp(newValue + sb.clickDir * clickStep, s, e)

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
        ui.t0 = core.getTime()
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
      setHot(id)

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
        setCursorPosY(ui.dragY)
        ui.dy = ui.dragY
        ui.y0 = ui.dragY
    of sbsTrackClickFirst:
      newValue = calcNewValueTrackClick()
      newThumbY = calcThumbY(newValue)

      sb.state = sbsTrackClickDelay
      ui.t0 = core.getTime()
      setFramesLeft()
    of sbsTrackClickDelay:
      if core.getTime() - ui.t0 > ScrollBarTrackClickRepeatDelay:
        sb.state = sbsTrackClickRepeat
      setFramesLeft()
    of sbsTrackClickRepeat:
      if isHot(id):
        if core.getTime() - ui.t0 > ScrollBarTrackClickRepeatTimeout:
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

          ui.t0 = core.getTime()
      else:
        ui.t0 = core.getTime()
      setFramesLeft()

  value_out = newValue

  # Draw scrollbar
  addDrawLayer(ui.currentLayer, vg):
    let dx = abs(x - ui.mx)
    let withinY = ui.my >= y and ui.my <= y + h

    if not s.autoFade or
        (s.autoFade and dx < s.autoFadeDistance and withinY and not ui.focusCaptured):
      let state =
        if isHot(id) and hasNoActiveItem():
          wsHover
        elif isActive(id):
          wsDown
        else:
          wsNormal

      var sw = s.trackStrokeWidth
      var (x, y, w, h) = snapToGrid(x, y, w, h, sw)

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
      vg.roundedRect(x + s.thumbPad, newThumbY, thumbW, thumbH, s.thumbCornerRadius)
      vg.fill()
      vg.stroke()

      vg.globalAlpha(1.0)

  if isHot(id):
    handleTooltip(id, tooltip)

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
    style: ScrollBarStyle = getDefaultScrollBarStyle(),
) =
  let i = instantiationInfo(fullPaths = true)
  let id = getNextId(i.filename, i.line)

  horizScrollBar(
    id, x, y, w, h, startVal, endVal, value, tooltip, thumbSize, clickStep, style
  )

template vertScrollBar*(
    x, y, w, h: float,
    startVal, endVal: float,
    value: var float,
    tooltip: string = "",
    thumbSize: float = -1.0,
    clickStep: float = -1.0,
    style: ScrollBarStyle = getDefaultScrollBarStyle(),
) =
  let i = instantiationInfo(fullPaths = true)
  let id = getNextId(i.filename, i.line)

  vertScrollBar(
    id, x, y, w, h, startVal, endVal, value, tooltip, thumbSize, clickStep, style
  )
