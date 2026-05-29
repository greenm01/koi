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

proc drawSelectableImageLabel(
    vg: NVGContext,
    id: ItemId,
    x, y, w, h: float,
    label: string,
    selected: bool,
    state: WidgetState,
    style: SelectableStyle,
    paint: Paint,
) =
  alias(s, style)
  DefaultSelectableDrawProc(vg, id, x, y, w, h, "", selected, state, style)

  let hasImage = paint.image != NoImage
  if hasImage:
    let
      imagePad = max(3.0, min(w, h) * 0.18)
      imageSize = max(0.0, min(h - imagePad * 2, w - imagePad * 2))
      imageX =
        if label.len == 0:
          x + (w - imageSize) * 0.5
        else:
          x + imagePad
      imageY = y + (h - imageSize) * 0.5
    vg.drawImage(imageX, imageY, imageSize, imageSize, paint)

    if label.len > 0:
      vg.drawLabel(
        imageX + imageSize,
        y,
        max(0.0, w - (imageX - x) - imageSize),
        h,
        label,
        state,
        s.label,
      )
  elif label.len > 0:
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
  let slot = layoutSlot(id, rect(x, y, w, h))

  if isHit(
    slot.previousBounds.x, slot.previousBounds.y, slot.previousBounds.w,
    slot.previousBounds.h,
  ):
    captureSimpleWidget(id, disabled)

  let behavior = selectableWidgetBehavior(id, disabled, selected)
  if behavior.clicked:
    selected = not selected
    result = true

  selected_out = selected

  addLayoutDrawLayer(ui.currentLayer, slot.nodeId, vg, bounds):
    let drawProc = if drawProc.isSome: drawProc.get else: DefaultSelectableDrawProc
    drawProc(
      vg, id, bounds.x, bounds.y, bounds.w, bounds.h, label, selected, behavior.state,
      style,
    )

  if isHot(id):
    handleTooltip(id, tooltip)

proc selectableImageLabel*(
    id: ItemId,
    x, y, w, h: float,
    paint: Paint,
    label: string,
    selected_out: var bool,
    tooltip: string = "",
    disabled: bool = false,
    style: SelectableStyle = borrowDefaultSelectableStyle(),
): bool =
  let drawProc: SelectableDrawProc = proc(
      vg: NVGContext,
      id: ItemId,
      x, y, w, h: float,
      label: string,
      selected: bool,
      state: WidgetState,
      style: SelectableStyle,
  ) =
    drawSelectableImageLabel(vg, id, x, y, w, h, label, selected, state, style, paint)

  selectable(
    id, x, y, w, h, label, selected_out, tooltip, disabled, drawProc.some, style
  )

proc selectableImage*(
    id: ItemId,
    x, y, w, h: float,
    paint: Paint,
    selected_out: var bool,
    tooltip: string = "",
    disabled: bool = false,
    style: SelectableStyle = borrowDefaultSelectableStyle(),
): bool =
  selectableImageLabel(
    id, x, y, w, h, paint, "", selected_out, tooltip, disabled, style
  )

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

template selectableImageLabel*(
    x, y, w, h: float,
    paint: Paint,
    label: string,
    selected: var bool,
    tooltip: string = "",
    disabled: bool = false,
    style: SelectableStyle = borrowDefaultSelectableStyle(),
): bool =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line, label)

  selectableImageLabel(id, x, y, w, h, paint, label, selected, tooltip, disabled, style)

template selectableImage*(
    x, y, w, h: float,
    paint: Paint,
    selected: var bool,
    tooltip: string = "",
    disabled: bool = false,
    style: SelectableStyle = borrowDefaultSelectableStyle(),
): bool =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)

  selectableImage(id, x, y, w, h, paint, selected, tooltip, disabled, style)

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

template selectableImageLabel*(
    paint: Paint,
    label: string,
    selected: var bool,
    tooltip: string = "",
    disabled: bool = false,
    style: SelectableStyle = borrowDefaultSelectableStyle(),
): bool =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line, label)

  autoLayoutPre()
  let res = selectableImageLabel(
    id,
    g_uiState.autoLayoutState.x,
    autoLayoutNextY(),
    autoLayoutNextItemWidth(),
    autoLayoutNextItemHeight(),
    paint,
    label,
    selected,
    tooltip,
    disabled,
    style,
  )
  autoLayoutPost()
  res

template selectableImage*(
    paint: Paint,
    selected: var bool,
    tooltip: string = "",
    disabled: bool = false,
    style: SelectableStyle = borrowDefaultSelectableStyle(),
): bool =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)

  autoLayoutPre()
  let res = selectableImage(
    id,
    g_uiState.autoLayoutState.x,
    autoLayoutNextY(),
    autoLayoutNextItemWidth(),
    autoLayoutNextItemHeight(),
    paint,
    selected,
    tooltip,
    disabled,
    style,
  )
  autoLayoutPost()
  res
