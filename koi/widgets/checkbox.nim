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

type CheckBoxDrawProc* = proc(
  vg: NVGContext,
  id: ItemId,
  x, y, w: float,
  checked: bool,
  state: WidgetState,
  style: CheckBoxStyle,
)

let DefaultCheckBoxDrawProc*: CheckBoxDrawProc = proc(
    vg: NVGContext,
    id: ItemId,
    x, y, w: float,
    checked: bool,
    state: WidgetState,
    style: CheckBoxStyle,
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
  let (x, y, w, _) = snapToGrid(x, y, w, w, sw)

  vg.fillColor(fillColor)
  vg.strokeColor(strokeColor)
  vg.strokeWidth(sw)
  vg.beginPath()
  vg.roundedRect(x, y, w, w, s.cornerRadius)
  vg.fill()
  vg.stroke()

  let icon = if checked: s.iconActive else: s.iconInactive

  if icon != "":
    vg.drawLabel(x, y, w, w, icon, state, s.icon)

proc checkBox*(
    id: ItemId,
    x, y, w: float,
    checked_out: var bool,
    tooltip: string,
    disabled: bool = false,
    drawProc: Option[CheckBoxDrawProc] = CheckBoxDrawProc.none,
    style: CheckBoxStyle = getDefaultCheckBoxStyle(),
) =
  var checked = checked_out

  alias(ui, g_uiState)

  let (x, y) = addDrawOffset(x, y)

  # Hit testing
  if isHit(x, y, w, w):
    setHot(id)
    if not disabled and ui.mbLeftDown and hasNoActiveItem():
      setActive(id)

  # LMB released over active widget means it was clicked
  checked =
    if not ui.mbLeftDown and isHot(id) and isActive(id):
      not checked
    else:
      checked

  checked_out = checked

  addDrawLayer(ui.currentLayer, vg):
    let state =
      if disabled:
        wsDisabled
      elif isHot(id) and hasNoActiveItem():
        if checked: wsActiveHover else: wsHover
      elif isHot(id) and isActive(id):
        wsDown
      else:
        if checked: wsActive else: wsNormal

    let drawProc = if drawProc.isSome: drawProc.get else: DefaultCheckBoxDrawProc

    drawProc(vg, id, x, y, w, checked, state, style)

  if isHot(id):
    handleTooltip(id, tooltip)

template checkBox*(
    x, y, w: float,
    active: var bool,
    tooltip: string = "",
    disabled: bool = false,
    drawProc: Option[CheckBoxDrawProc] = CheckBoxDrawProc.none,
    style: CheckBoxStyle = getDefaultCheckBoxStyle(),
) =
  let i = instantiationInfo(fullPaths = true)
  let id = getNextId(i.filename, i.line)

  checkbox(id, x, y, w, active, tooltip, disabled, drawProc, style)

template checkBox*(
    active: var bool,
    tooltip: string = "",
    disabled: bool = false,
    drawProc: Option[CheckBoxDrawProc] = CheckBoxDrawProc.none,
    style: CheckBoxStyle = getDefaultCheckBoxStyle(),
) =
  let i = instantiationInfo(fullPaths = true)
  let id = getNextId(i.filename, i.line)

  autoLayoutPre()

  checkbox(
    id,
    g_uiState.autoLayoutState.x,
    autoLayoutNextY(),
    autoLayoutNextItemHeight(),
    active,
    tooltip,
    disabled,
    drawProc,
    style,
  )

  autoLayoutPost()
