import std/options
import std/math
import std/strutils

import nanovg
import glfw

import koi/types
import koi/core
import koi/drawing
import koi/layout
import koi/input
import koi/defaults
import koi/widgets/common
import koi/widgets/textfield
import koi/utils

const
  SliderFineDragDivisor      = 10.0
  SliderUltraFineDragDivisor = 100.0

# {{{ horizSlider()

proc horizSlider*(id:         ItemId,
                  x, y, w, h: float,
                  startVal:   float,
                  endVal:     float,
                  value_out:  var float,
                  grouping:   WidgetGrouping = wgNone,
                  label:      string = "",
                  tooltip:    string = "",
                  style:      SliderStyle = getDefaultSliderStyle()) =

  alias(ui, g_uiState)
  alias(sl, ui.sliderState)
  alias(s, style)

  var value = value_out.clampToRange(startVal, endVal)

  let (x, y) = addDrawOffset(x, y)

  # Hit testing
  if isHit(x, y, w, h):
    setHot(id)
    if ui.mbLeftDown and hasNoActiveItem():
      setActive(id)
      sl.state = ssDefault
      sl.oldValue = value
      sl.cursorMoved = false

  var
    newValue = value
    isEditing = (sl.editModeItem == id)

  if isActive(id):
    case sl.state
    of ssDefault:
      if ui.mbLeftDown:
        if abs(ui.mx - ui.lastmx) > 0.1 or abs(ui.my - ui.lastmy) > 0.1:
          sl.cursorMoved = true

        if sl.cursorMoved:
          if shiftDown():
            disableCursor()
            sl.state = ssDragHidden
            sl.cursorPosX = ui.mx
            sl.cursorPosY = ui.my
            ui.widgetMouseDrag = true
          else:
            let t = invLerp(x + s.trackPad, x + w - s.trackPad, ui.mx)
            newValue = lerp(startVal, endVal, t)
        
        # Transition to edit mode on double click or simple click without move
        if isDoubleClick():
          sl.editModeItem = id
          sl.textFieldId = hashId(lastIdString() & ":textField")
          sl.valueText = value.formatFloat(ffDecimal, s.valuePrecision)
          sl.state = ssEditValue

      else: # LMB released
        if not sl.cursorMoved:
          discard
        sl.state = ssDefault

    of ssDragHidden:
      if shiftDown():
        let d = if altDown(): SliderUltraFineDragDivisor
                else:         SliderFineDragDivisor
        let dx = (ui.dx - ui.x0) / d
        let range = abs(endVal - startVal)
        newValue = (value + (dx / (w - s.trackPad*2)) * range).clampToRange(startVal, endVal)
        ui.x0 = ui.dx
        sl.cursorPosX = (sl.cursorPosX + dx).clamp(x + s.trackPad, x + w - s.trackPad)
      else:
        sl.state = ssDefault
        showCursor()
        setCursorPosX(sl.cursorPosX)
        ui.dx = sl.cursorPosX
        ui.x0 = sl.cursorPosX

    of ssEditValue:
      discard

    of ssCancel:
      newValue = sl.oldValue
      sl.state = ssDefault

  if sl.editModeItem == id:
    let oldVal = sl.valueText
    textField(sl.textFieldId, x, y, w, h, sl.valueText, activate = (sl.state == ssEditValue), style = nil) # TODO handle style
    if sl.valueText != oldVal:
      try:
        newValue = sl.valueText.parseFloat().clampToRange(startVal, endVal)
      except ValueError:
        discard
    
    if not isActive(sl.textFieldId):
      sl.editModeItem = 0
      sl.state = ssDefault

  value_out = newValue

  # Draw slider
  if sl.editModeItem != id:
    addDrawLayer(ui.currentLayer, vg):
      let state = if   isHot(id) and hasNoActiveItem(): wsHover
                  elif isActive(id): wsDown
                  else: wsNormal

      var sw = s.trackStrokeWidth
      var (rx, ry, rw, rh) = snapToGrid(x, y, w, h, sw)

      let (trackFillColor, trackStrokeColor) =
        case state
        of wsHover: (s.trackFillColorHover, s.trackStrokeColorHover)
        of wsDown:  (s.trackFillColorDown,  s.trackStrokeColorDown)
        else:       (s.trackFillColor,      s.trackStrokeColor)

      # Draw track
      vg.fillColor(trackFillColor)
      vg.strokeColor(trackStrokeColor)
      vg.strokeWidth(sw)
      vg.beginPath()
      vg.roundedRect(rx, ry, rw, rh, s.trackCornerRadius)
      vg.fill()
      vg.stroke()

      # Draw handle
      let
        handleW = 10.0 # TODO style
        handleMinX = rx + s.trackPad
        handleMaxX = rx + rw - s.trackPad - handleW
        t = invLerp(startVal, endVal, newValue)
        handleX = lerp(handleMinX, handleMaxX, t)

      vg.fillColor(s.sliderColor)
      vg.beginPath()
      vg.roundedRect(handleX, ry + s.trackPad, handleW, rh - s.trackPad*2, s.valueCornerRadius)
      vg.fill()

      # Draw label
      if label != "":
        vg.drawLabel(rx, ry, rw, rh, label, state, s.label)
      
      let valText = newValue.formatFloat(ffDecimal, s.valuePrecision) & s.valueSuffix
      vg.drawLabel(rx, ry, rw, rh, valText, state, s.value)

  if isHot(id):
    handleTooltip(id, tooltip)

# }}}

proc vertSlider*(id:         ItemId,
                 x, y, w, h: float,
                 startVal:   float,
                 endVal:     float,
                 value_out:  var float,
                 tooltip:    string = "",
                 style:      SliderStyle = getDefaultSliderStyle()) =

  alias(ui, g_uiState)
  alias(sl, ui.sliderState)
  alias(s, style)

  var value = value_out.clampToRange(startVal, endVal)
  let (x, y) = addDrawOffset(x, y)

  let
    posMinY = y + h - s.trackPad
    posMaxY = y + s.trackPad

  func calcPosY(val: float): float =
    let t = invLerp(startVal, endVal, val)
    lerp(posMinY, posMaxY, t)

  let posY = calcPosY(value)

  if isHit(x, y, w, h):
    setHot(id)
    if ui.mbLeftDown and hasNoActiveItem():
      setActive(id)

  var newPosY = posY

  if isActive(id):
    case sl.state
    of ssDefault:
      ui.y0 = ui.my
      ui.dragX = -1.0
      ui.dragY = ui.my
      ui.widgetMouseDrag = true
      sl.oldValue = value
      disableCursor()
      sl.state = ssDragHidden

    of ssDragHidden:
      setHot(id)

      let d = if shiftDown():
        if altDown(): SliderUltraFineDragDivisor
        else:         SliderFineDragDivisor
      else: 1.0

      let dy = (ui.dy - ui.y0) / d
      newPosY = clamp(posY + dy, posMaxY, posMinY)
      let t = invLerp(posMinY, posMaxY, newPosY)
      value = lerp(startVal, endVal, t)
      ui.y0 = ui.dy

      sl.cursorPosY = if s.cursorFollowsValue: newPosY
                      else: ui.dragY

    of ssEditValue:
      discard

    of ssCancel:
      value = sl.oldValue
      if not ui.mbLeftDown:
        sl.state = ssDefault

  value_out = value

  addDrawLayer(ui.currentLayer, vg):
    let state = if isHot(id) and hasNoActiveItem(): wsHover
                elif isActive(id): wsDown
                else: wsNormal

    var sw = s.trackStrokeWidth
    var (rx, ry, rw, rh) = snapToGrid(x, y, w, h, sw)

    let (trackFillColor, trackStrokeColor, sliderColor) =
      case state
      of wsHover:
        (s.trackFillColorHover, s.trackStrokeColorHover, s.sliderColorHover)
      of wsDown, wsActiveDown:
        (s.trackFillColorDown, s.trackStrokeColorDown, s.sliderColorDown)
      else:
        (s.trackFillColor, s.trackStrokeColor, s.sliderColor)

    vg.fillColor(trackFillColor)
    vg.beginPath()
    vg.roundedRect(rx, ry, rw, rh, s.trackCornerRadius)
    vg.fill()

    let
      vx = rx + s.trackPad
      vy = newPosY
      vw = rw - s.trackPad*2
      vh = ry + rh - newPosY - s.trackPad

    vg.fillColor(sliderColor)
    vg.beginPath()
    vg.roundedRect(vx, vy, vw, vh, s.valueCornerRadius)
    vg.fill()

    vg.strokeColor(trackStrokeColor)
    vg.strokeWidth(sw)
    vg.beginPath()
    vg.roundedRect(rx, ry, rw, rh, s.trackCornerRadius)
    vg.stroke()

  if isHot(id):
    handleTooltip(id, tooltip)

# }}}

proc sliderPost*() =
  alias(ui, g_uiState)
  alias(sl, ui.sliderState)

  if not ui.mbLeftDown:
    ui.widgetMouseDrag = false

# {{{ Templates

template horizSlider*(x, y, w, h: float,
                     startVal, endVal: float,
                     value: var float,
                     grouping: WidgetGrouping = wgNone,
                     label: string = "",
                     tooltip: string = "",
                     style: SliderStyle = getDefaultSliderStyle()) =
  let i = instantiationInfo(fullPaths=true)
  let id = getNextId(i.filename, i.line)
  horizSlider(id, x, y, w, h, startVal, endVal, value, grouping, label, tooltip, style)

template horizSlider*(startVal, endVal: float,
                     value: var float,
                     grouping: WidgetGrouping = wgNone,
                     label: string = "",
                     tooltip: string = "",
                     style: SliderStyle = getDefaultSliderStyle()) =
  let i = instantiationInfo(fullPaths=true)
  let id = getNextId(i.filename, i.line)
  autoLayoutPre()
  horizSlider(id, g_uiState.autoLayoutState.x, autoLayoutNextY(),
              autoLayoutNextItemWidth(), autoLayoutNextItemHeight(),
              startVal, endVal, value, grouping, label, tooltip, style)
  autoLayoutPost()

template vertSlider*(x, y, w, h: float,
                     startVal, endVal: float,
                     value: var float,
                     tooltip: string = "",
                     style: SliderStyle = getDefaultSliderStyle()) =
  let i = instantiationInfo(fullPaths=true)
  let id = getNextId(i.filename, i.line)
  vertSlider(id, x, y, w, h, startVal, endVal, value, tooltip, style)

# }}}
