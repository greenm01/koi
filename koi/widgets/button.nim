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

proc drawButtonImageLabel(
    vg: NVGContext,
    id: ItemId,
    x, y, w, h: float,
    label: string,
    state: WidgetState,
    style: ButtonStyle,
    paint: Paint,
) =
  alias(s, style)
  DefaultButtonDrawProc(vg, id, x, y, w, h, "", state, style)

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
  let slot = layoutSlot(id, rect(x, y, w, h))

  # Hit testing
  if isHit(
    slot.previousBounds.x, slot.previousBounds.y, slot.previousBounds.w,
    slot.previousBounds.h,
  ):
    captureSimpleWidget(id, disabled)

  let behavior = simpleWidgetBehavior(id, disabled)
  result = behavior.clicked

  addLayoutDrawLayer(ui.currentLayer, slot.nodeId, vg, bounds):
    let drawProc = if drawProc.isSome: drawProc.get else: DefaultButtonDrawProc

    drawProc(
      vg, id, bounds.x, bounds.y, bounds.w, bounds.h, label, behavior.state, style
    )

  if isHot(id):
    handleTooltip(id, tooltip)

proc buttonImageLabel*(
    id: ItemId,
    x, y, w, h: float,
    paint: Paint,
    label: string,
    tooltip: string = "",
    disabled: bool = false,
    style: ButtonStyle = borrowDefaultButtonStyle(),
): bool =
  let drawProc: ButtonDrawProc = proc(
      vg: NVGContext,
      id: ItemId,
      x, y, w, h: float,
      label: string,
      state: WidgetState,
      style: ButtonStyle,
  ) =
    drawButtonImageLabel(vg, id, x, y, w, h, label, state, style, paint)

  button(id, x, y, w, h, label, tooltip, disabled, drawProc.some, style)

proc buttonImage*(
    id: ItemId,
    x, y, w, h: float,
    paint: Paint,
    tooltip: string = "",
    disabled: bool = false,
    style: ButtonStyle = borrowDefaultButtonStyle(),
): bool =
  buttonImageLabel(id, x, y, w, h, paint, "", tooltip, disabled, style)

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

template buttonImageLabel*(
    x, y, w, h: float,
    paint: Paint,
    label: string,
    tooltip: string = "",
    disabled: bool = false,
    style: ButtonStyle = borrowDefaultButtonStyle(),
): bool =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line, label)

  buttonImageLabel(id, x, y, w, h, paint, label, tooltip, disabled, style)

template buttonImage*(
    x, y, w, h: float,
    paint: Paint,
    tooltip: string = "",
    disabled: bool = false,
    style: ButtonStyle = borrowDefaultButtonStyle(),
): bool =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)

  buttonImage(id, x, y, w, h, paint, tooltip, disabled, style)

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

template buttonImageLabel*(
    paint: Paint,
    label: string,
    tooltip: string = "",
    disabled: bool = false,
    style: ButtonStyle = borrowDefaultButtonStyle(),
): bool =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line, label)

  autoLayoutPre()
  let res = buttonImageLabel(
    id,
    g_uiState.autoLayoutState.x,
    autoLayoutNextY(),
    autoLayoutNextItemWidth(),
    autoLayoutNextItemHeight(),
    paint,
    label,
    tooltip,
    disabled,
    style,
  )
  autoLayoutPost()
  res

template buttonImage*(
    paint: Paint,
    tooltip: string = "",
    disabled: bool = false,
    style: ButtonStyle = borrowDefaultButtonStyle(),
): bool =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)

  autoLayoutPre()
  let res = buttonImage(
    id,
    g_uiState.autoLayoutState.x,
    autoLayoutNextY(),
    autoLayoutNextItemWidth(),
    autoLayoutNextItemHeight(),
    paint,
    tooltip,
    disabled,
    style,
  )
  autoLayoutPost()
  res
