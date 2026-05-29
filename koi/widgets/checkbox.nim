import std/options

import nanovg

import koi/types
import koi/core
import koi/drawing
import koi/layout
import koi/rect
import koi/input
import koi/defaults
import koi/internal/widget_behavior
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
    style: CheckBoxStyle = borrowDefaultCheckBoxStyle(),
) =
  var checked = checked_out

  alias(ui, g_uiState)

  let (x, y) = addDrawOffset(x, y)
  let slot = layoutSlot(id, rect(x, y, w, w))

  # Hit testing
  if isHit(
    slot.previousBounds.x, slot.previousBounds.y, slot.previousBounds.w,
    slot.previousBounds.h,
  ):
    captureSimpleWidget(id, disabled)

  let behavior = selectableWidgetBehavior(id, disabled, checked)
  if behavior.clicked:
    checked = not checked

  checked_out = checked

  addLayoutDrawLayer(ui.currentLayer, slot.nodeId, vg, bounds):
    let drawProc = if drawProc.isSome: drawProc.get else: DefaultCheckBoxDrawProc

    drawProc(vg, id, bounds.x, bounds.y, bounds.w, checked, behavior.state, style)

  if isHot(id):
    handleTooltip(id, tooltip)

template checkBox*(
    x, y, w: float,
    active: var bool,
    tooltip: string = "",
    disabled: bool = false,
    drawProc: Option[CheckBoxDrawProc] = CheckBoxDrawProc.none,
    style: CheckBoxStyle = borrowDefaultCheckBoxStyle(),
) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)

  checkbox(id, x, y, w, active, tooltip, disabled, drawProc, style)

template checkBox*(
    active: var bool,
    tooltip: string = "",
    disabled: bool = false,
    drawProc: Option[CheckBoxDrawProc] = CheckBoxDrawProc.none,
    style: CheckBoxStyle = borrowDefaultCheckBoxStyle(),
) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)

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
