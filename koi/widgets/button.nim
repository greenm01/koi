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

type ButtonDrawProc* = proc(
  vg: NVGContext,
  id: ItemId,
  x, y, w, h: float,
  label: string,
  state: WidgetState,
  style: ButtonStyle,
)

let DefaultButtonDrawProc*: ButtonDrawProc = proc(
    vg: NVGContext,
    id: ItemId,
    x, y, w, h: float,
    label: string,
    state: WidgetState,
    style: ButtonStyle,
) =
  alias(s, style)

  let sw = s.strokeWidth
  let (x, y, w, h) = snapToGrid(x, y, w, h, sw)

  let (fillColor, strokeColor) =
    case state
    of wsNormal, wsActive, wsActiveHover:
      (s.fillColor, s.strokeColor)
    of wsHover:
      (s.fillColorHover, s.strokeColorHover)
    of wsDown, wsActiveDown:
      (s.fillColorDown, s.strokeColorDown)
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

proc button*(
    id: ItemId,
    x, y, w, h: float,
    label: string,
    tooltip: string,
    disabled: bool,
    drawProc: Option[ButtonDrawProc] = ButtonDrawProc.none,
    style: ButtonStyle = borrowDefaultButtonStyle(),
): bool =
  alias(ui, g_uiState)

  let (x, y) = addDrawOffset(x, y)

  # Hit testing
  if isHit(x, y, w, h):
    captureSimpleWidget(id, disabled)

  let behavior = simpleWidgetBehavior(id, disabled)
  result = behavior.clicked

  addDrawLayer(ui.currentLayer, vg):
    let drawProc = if drawProc.isSome: drawProc.get else: DefaultButtonDrawProc

    drawProc(vg, id, x, y, w, h, label, behavior.state, style)

  if isHot(id):
    handleTooltip(id, tooltip)

template button*(
    x, y, w, h: float,
    label: string,
    tooltip: string = "",
    disabled: bool = false,
    drawProc: Option[ButtonDrawProc] = ButtonDrawProc.none,
    style: ButtonStyle = borrowDefaultButtonStyle(),
): bool =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)

  button(id, x, y, w, h, label, tooltip, disabled, drawProc, style)

template button*(
    label: string,
    tooltip: string = "",
    disabled: bool = false,
    drawProc: Option[ButtonDrawProc] = ButtonDrawProc.none,
    style: ButtonStyle = borrowDefaultButtonStyle(),
): bool =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)

  autoLayoutPre()

  let res = button(
    id,
    g_uiState.autoLayoutState.x,
    autoLayoutNextY(),
    autoLayoutNextItemWidth(),
    autoLayoutNextItemHeight(),
    label,
    tooltip,
    disabled,
    drawProc,
    style,
  )

  autoLayoutPost()
  res
