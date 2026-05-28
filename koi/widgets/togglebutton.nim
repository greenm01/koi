import std/options

import nanovg

import koi/types
import koi/core
import koi/drawing
import koi/layout
import koi/input
import koi/defaults
import koi/widgets/common
import koi/utils

type
  ToggleButtonDrawProc* = proc (vg: NVGContext,
                                id: ItemId, x, y, w, h: float, label: string,
                                state: WidgetState, style: ToggleButtonStyle)


let DefaultToggleButtonDrawProc*: ToggleButtonDrawProc =
  proc (vg: NVGContext,
        id: ItemId, x, y, w, h: float, label: string,
        state: WidgetState, style: ToggleButtonStyle) =

    alias(s, style)

    var (fillColor, strokeColor) = case state
      of wsNormal:
        (s.fillColor, s.strokeColor)
      of wsHover:
        (s.fillColorHover, s.strokeColorHover)
      of wsDown, wsActiveDown:
        (s.fillColorDown, s.strokeColorDown)
      of wsActive:
        (s.fillColorActive, s.strokeColorActive)
      of wsActiveHover:
        (s.fillColorActiveHover, s.strokeColorActiveHover)
      of wsDisabled:
        (s.fillColorDisabled, s.strokeColorDisabled)

    let sw = s.strokeWidth
    let (x, y, w, h) = snapToGrid(x, y, w, h, sw)

    vg.fillColor(fillColor)
    vg.strokeColor(strokeColor)
    vg.strokeWidth(sw)
    vg.beginPath()
    vg.roundedRect(x, y, w, h, s.cornerRadius)
    vg.fill()
    vg.stroke()

    var labelStyle = case state
      of wsActive, wsActiveHover, wsActiveDown: s.labelActive
      else: s.label

    vg.drawLabel(x, y, w, h, label, state, labelStyle)

proc toggleButton*(
  id:          ItemId,
  x, y, w, h:  float,
  active_out:  var bool,
  label:       string,
  labelActive: string = "",
  tooltip:     string,
  disabled:    bool = false,
  drawProc:    Option[ToggleButtonDrawProc] = ToggleButtonDrawProc.none,
  style:       ToggleButtonStyle = getDefaultToggleButtonStyle()) =

  var active = active_out

  alias(ui, g_uiState)

  let (x, y) = addDrawOffset(x, y)

  # Hit testing
  if isHit(x, y, w, h):
    setHot(id)
    if not disabled and ui.mbLeftDown and hasNoActiveItem():
      setActive(id)

  # LMB released over active widget means it was clicked
  active = if not ui.mbLeftDown and isHot(id) and isActive(id): not active
           else: active

  active_out = active

  addDrawLayer(ui.currentLayer, vg):
    let state = if disabled: wsDisabled
                elif isHot(id) and hasNoActiveItem():
                  if active: wsActiveHover else: wsHover
                elif isHot(id) and isActive(id): wsDown
                else:
                  if active: wsActive else: wsNormal

    let drawProc = if drawProc.isSome: drawProc.get
                   else: DefaultToggleButtonDrawProc

    let displayLabel = if active and labelActive != "": labelActive
                       else: label

    drawProc(vg, id, x, y, w, h, displayLabel, state, style)


  if isHot(id):
    handleTooltip(id, tooltip)

template toggleButton*(
  x, y, w, h:  float,
  active_out:  var bool,
  label:       string,
  labelActive: string = "",
  tooltip:     string = "",
  disabled:    bool = false,
  drawProc:    Option[ToggleButtonDrawProc] = ToggleButtonDrawProc.none,
  style:       ToggleButtonStyle = getDefaultToggleButtonStyle()) =

  let i = instantiationInfo(fullPaths=true)
  let id = getNextId(i.filename, i.line)

  toggleButton(id, x, y, w, h, active_out, label, labelActive, tooltip,
               disabled, drawProc, style)


template toggleButton*(
  active_out:  var bool,
  label:       string,
  labelActive: string = "",
  tooltip:     string = "",
  disabled:    bool = false,
  drawProc:    Option[ToggleButtonDrawProc] = ToggleButtonDrawProc.none,
  style:       ToggleButtonStyle = getDefaultToggleButtonStyle()) =

  let i = instantiationInfo(fullPaths=true)
  let id = getNextId(i.filename, i.line)

  autoLayoutPre()

  toggleButton(id,
               g_uiState.autoLayoutState.x, autoLayoutNextY(),
               autoLayoutNextItemWidth(), autoLayoutNextItemHeight(),
               active_out, label, labelActive, tooltip, disabled, drawProc,
               style)

  autoLayoutPost()
