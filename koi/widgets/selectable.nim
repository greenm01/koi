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

type SelectableDrawProc* = proc(
  vg: NVGContext,
  id: ItemId,
  x, y, w, h: float,
  label: string,
  selected: bool,
  state: WidgetState,
  style: SelectableStyle,
)

let DefaultSelectableDrawProc*: SelectableDrawProc = proc(
    vg: NVGContext,
    id: ItemId,
    x, y, w, h: float,
    label: string,
    selected: bool,
    state: WidgetState,
    style: SelectableStyle,
) =
  alias(s, style)

  let sw = s.strokeWidth
  let (x, y, w, h) = snapToGrid(x, y, w, h, sw)

  let (fillColor, strokeColor) =
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

  vg.fillColor(fillColor)
  vg.strokeColor(strokeColor)
  vg.strokeWidth(sw)
  vg.beginPath()
  vg.roundedRect(x, y, w, h, s.cornerRadius)
  vg.fill()
  vg.stroke()

  vg.drawLabel(x, y, w, h, label, state, s.label)

proc selectable*(
    id: ItemId,
    x, y, w, h: float,
    label: string,
    selected_out: var bool,
    tooltip: string = "",
    disabled: bool = false,
    drawProc: Option[SelectableDrawProc] = SelectableDrawProc.none,
    style: SelectableStyle = borrowDefaultSelectableStyle(),
): bool =
  alias(ui, g_uiState)

  var selected = selected_out
  let (x, y) = addDrawOffset(x, y)

  if isHit(x, y, w, h):
    captureSimpleWidget(id, disabled)

  let behavior = selectableWidgetBehavior(id, disabled, selected)
  if behavior.clicked:
    selected = not selected
    result = true

  selected_out = selected

  addDrawLayer(ui.currentLayer, vg):
    let drawProc = if drawProc.isSome: drawProc.get else: DefaultSelectableDrawProc
    drawProc(vg, id, x, y, w, h, label, selected, behavior.state, style)

  if isHot(id):
    handleTooltip(id, tooltip)

template selectable*(
    x, y, w, h: float,
    label: string,
    selected: var bool,
    tooltip: string = "",
    disabled: bool = false,
    drawProc: Option[SelectableDrawProc] = SelectableDrawProc.none,
    style: SelectableStyle = borrowDefaultSelectableStyle(),
): bool =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line, label)

  selectable(id, x, y, w, h, label, selected, tooltip, disabled, drawProc, style)

template selectable*(
    label: string,
    selected: var bool,
    tooltip: string = "",
    disabled: bool = false,
    drawProc: Option[SelectableDrawProc] = SelectableDrawProc.none,
    style: SelectableStyle = borrowDefaultSelectableStyle(),
): bool =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line, label)

  autoLayoutPre()
  let res = selectable(
    id,
    g_uiState.autoLayoutState.x,
    autoLayoutNextY(),
    autoLayoutNextItemWidth(),
    autoLayoutNextItemHeight(),
    label,
    selected,
    tooltip,
    disabled,
    drawProc,
    style,
  )
  autoLayoutPost()
  res
