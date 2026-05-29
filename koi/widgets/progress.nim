import std/options

import nanovg

import koi/types
import koi/core
import koi/drawing
import koi/layout
import koi/rect
import koi/input
import koi/defaults
import koi/internal/algorithms
import koi/widgets/common
import koi/utils

type ProgressDrawProc* = proc(
  vg: NVGContext,
  id: ItemId,
  x, y, w, h: float,
  value, maxValue: float,
  label: string,
  state: WidgetState,
  style: ProgressStyle,
)

let DefaultProgressDrawProc*: ProgressDrawProc = proc(
    vg: NVGContext,
    id: ItemId,
    x, y, w, h: float,
    value, maxValue: float,
    label: string,
    state: WidgetState,
    style: ProgressStyle,
) =
  alias(s, style)

  let sw = s.strokeWidth
  let (x, y, w, h) = snapToGrid(x, y, w, h, sw)
  let fillW = w * progressFraction(value, maxValue)
  let disabled = state == wsDisabled

  vg.fillColor(if disabled: s.fillColorDisabled else: s.fillColor)
  vg.strokeColor(if disabled: s.strokeColorDisabled else: s.strokeColor)
  vg.strokeWidth(sw)
  vg.beginPath()
  vg.roundedRect(x, y, w, h, s.cornerRadius)
  vg.fill()

  if fillW > 0:
    vg.fillColor(if disabled: s.valueColorDisabled else: s.valueColor)
    vg.beginPath()
    vg.roundedRect(x, y, fillW, h, s.cornerRadius)
    vg.fill()

  vg.beginPath()
  vg.roundedRect(x, y, w, h, s.cornerRadius)
  vg.stroke()

  if label != "":
    vg.drawLabel(x, y, w, h, label, state, s.label)

proc progress*(
    id: ItemId,
    x, y, w, h: float,
    value, maxValue: float,
    label: string = "",
    tooltip: string = "",
    drawProc: Option[ProgressDrawProc] = ProgressDrawProc.none,
    style: ProgressStyle = borrowDefaultProgressStyle(),
    disabled: bool = false,
) =
  alias(ui, g_uiState)

  let (x, y) = addDrawOffset(x, y)
  let slot = layoutSlot(id, rect(x, y, w, h))

  if tooltip != "" and
      isHit(
        slot.previousBounds.x, slot.previousBounds.y, slot.previousBounds.w,
        slot.previousBounds.h,
      ):
    markHot(id)

  addLayoutDrawLayer(ui.currentLayer, slot.nodeId, vg, bounds):
    let drawProc = if drawProc.isSome: drawProc.get else: DefaultProgressDrawProc
    let state = if disabled: wsDisabled else: wsNormal
    drawProc(
      vg, id, bounds.x, bounds.y, bounds.w, bounds.h, value, maxValue, label, state,
      style,
    )

  if isHot(id):
    handleTooltip(id, tooltip)

template progress*(
    x, y, w, h: float,
    value, maxValue: float,
    label: string = "",
    tooltip: string = "",
    drawProc: Option[ProgressDrawProc] = ProgressDrawProc.none,
    style: ProgressStyle = borrowDefaultProgressStyle(),
    disabled: bool = false,
) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)
  progress(id, x, y, w, h, value, maxValue, label, tooltip, drawProc, style, disabled)

template progress*(
    value, maxValue: float,
    label: string = "",
    tooltip: string = "",
    drawProc: Option[ProgressDrawProc] = ProgressDrawProc.none,
    style: ProgressStyle = borrowDefaultProgressStyle(),
    disabled: bool = false,
) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)

  autoLayoutPre()
  progress(
    id,
    g_uiState.autoLayoutState.x,
    autoLayoutNextY(),
    autoLayoutNextItemWidth(),
    autoLayoutNextItemHeight(),
    value,
    maxValue,
    label,
    tooltip,
    drawProc,
    style,
    disabled,
  )
  autoLayoutPost()
