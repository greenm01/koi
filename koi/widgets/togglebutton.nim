import std/options

import nanovg

import koi/types
import koi/core
import koi/drawing
import koi/layout
import koi/input
import koi/defaults
import koi/internal/widget_behavior
import koi/widgets/common
import koi/utils

type ToggleButtonDrawProc* = proc(
  vg: NVGContext,
  id: ItemId,
  x, y, w, h: float,
  label: string,
  state: WidgetState,
  style: ToggleButtonStyle,
)

let DefaultToggleButtonDrawProc*: ToggleButtonDrawProc = proc(
    vg: NVGContext,
    id: ItemId,
    x, y, w, h: float,
    label: string,
    state: WidgetState,
    style: ToggleButtonStyle,
) =
  alias(s, style)

  var (fillColor, strokeColor) =
    case state
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

  var labelStyle =
    case state
    of wsActive, wsActiveHover, wsActiveDown: s.labelActive
    else: s.label

  vg.drawLabel(x, y, w, h, label, state, labelStyle)

proc toggleButton*(
    id: ItemId,
    x, y, w, h: float,
    active_out: var bool,
    label: string,
    labelActive: string = "",
    tooltip: string,
    disabled: bool = false,
    drawProc: Option[ToggleButtonDrawProc] = ToggleButtonDrawProc.none,
    style: ToggleButtonStyle = borrowDefaultToggleButtonStyle(),
) =
  var active = active_out

  alias(ui, g_uiState)

  let (x, y) = addDrawOffset(x, y)

  # Hit testing
  if isHit(x, y, w, h):
    captureSimpleWidget(id, disabled)

  let behavior = selectableWidgetBehavior(id, disabled, active)
  if behavior.clicked:
    active = not active

  active_out = active

  addDrawLayer(ui.currentLayer, vg):
    let drawProc = if drawProc.isSome: drawProc.get else: DefaultToggleButtonDrawProc

    let displayLabel = if active and labelActive != "": labelActive else: label

    drawProc(vg, id, x, y, w, h, displayLabel, behavior.state, style)

  if isHot(id):
    handleTooltip(id, tooltip)

template toggleButton*(
    x, y, w, h: float,
    active_out: var bool,
    label: string,
    labelActive: string = "",
    tooltip: string = "",
    disabled: bool = false,
    drawProc: Option[ToggleButtonDrawProc] = ToggleButtonDrawProc.none,
    style: ToggleButtonStyle = borrowDefaultToggleButtonStyle(),
) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)

  toggleButton(
    id, x, y, w, h, active_out, label, labelActive, tooltip, disabled, drawProc, style
  )

template toggleButton*(
    active_out: var bool,
    label: string,
    labelActive: string = "",
    tooltip: string = "",
    disabled: bool = false,
    drawProc: Option[ToggleButtonDrawProc] = ToggleButtonDrawProc.none,
    style: ToggleButtonStyle = borrowDefaultToggleButtonStyle(),
) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)

  autoLayoutPre()

  toggleButton(
    id,
    g_uiState.autoLayoutState.x,
    autoLayoutNextY(),
    autoLayoutNextItemWidth(),
    autoLayoutNextItemHeight(),
    active_out,
    label,
    labelActive,
    tooltip,
    disabled,
    drawProc,
    style,
  )

  autoLayoutPost()
