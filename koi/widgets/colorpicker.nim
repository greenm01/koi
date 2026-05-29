import nanovg

import koi/types
import koi/core
import koi/drawing
import koi/layout
import koi/rect
import koi/input
import koi/defaults
import koi/internal/widget_behavior
import koi/widgets/button
import koi/widgets/popup
import koi/utils

proc drawColorSwatchWithSlot(
    slot: LayoutSlot, id: ItemId, color: Color, interactive: bool = true
): bool =
  alias(ui, g_uiState)

  if interactive and isHit(
      slot.previousBounds.x, slot.previousBounds.y, slot.previousBounds.w,
      slot.previousBounds.h,
    ):
    captureSimpleWidget(id, disabled = false)

  if interactive:
    let behavior = simpleWidgetBehavior(id, disabled = false)
    result = behavior.clicked

  addLayoutDrawLayer(ui.currentLayer, slot.nodeId, vg, bounds):
    let
      sw = 1.0
      (rx, ry, rw, rh) = snapToGrid(bounds.x, bounds.y, bounds.w, bounds.h, sw)
      cr = 5.0
      colorWidth = rw * 0.5

    vg.fillColor(color.withAlpha(1.0))
    vg.beginPath()
    vg.roundedRect(rx, ry, colorWidth, rh, cr, 0, 0, cr)
    vg.fill()

    vg.fillColor(color)
    vg.beginPath()
    vg.roundedRect(rx + colorWidth, ry, rw - colorWidth, rh, 0, cr, cr, 0)
    vg.fill()

    vg.strokeColor(gray(0.1))
    vg.strokeWidth(sw)
    vg.beginPath()
    vg.roundedRect(rx, ry, rw, rh, cr)
    vg.stroke()

proc drawColorSwatch(id: ItemId, x, y, w, h: float, color: Color): bool =
  let (x, y) = addDrawOffset(x, y)
  let slot = layoutSlot(id, rect(x, y, w, h))
  drawColorSwatchWithSlot(slot, id, color)

proc color*(id: ItemId, x, y, w, h: float, color_out: var Color) =
  discard drawColorSwatch(id, x, y, w, h, color_out)

proc colorPicker*(id: ItemId, x, y, w, h: float, color: var Color) =
  color(id, x, y, w, h, color)

proc colorCombo*(
    id: ItemId,
    x, y, w, h: float,
    color: var Color,
    label: string = "",
    style: ColorComboStyle = borrowDefaultColorComboStyle(),
): bool =
  let oldColor = color
  let (sx, sy) = addDrawOffset(x, y)
  let buttonSlot = layoutSlot(id, rect(sx, sy, w, h))
  if buttonWithSlot(buttonSlot, id, label, "", false, style = style.button):
    openPopup(id)

  let swatchPad = max(3.0, h * 0.18)
  let swatchSize = max(0.0, h - swatchPad * 2)
  let previewId = hashId($id & ":preview")
  let previewSlot = layoutFollowerSlot(
    previewId,
    rect(sx + swatchPad, sy + swatchPad, swatchSize, swatchSize),
    buttonSlot.nodeId,
    lfkInsetFixed,
    followInset = padding(swatchPad, 0, swatchPad, 0),
  )
  discard drawColorSwatchWithSlot(
    previewSlot,
    previewId,
    color,
    interactive = false,
  )

  let popupId = hashId($id & ":popup")
  if isPopupOpen(id):
    let popupSlot = layoutFollowerSlot(
      popupId,
      rect(sx, sy + h, style.popupWidth, style.popupHeight),
      buttonSlot.nodeId,
      lfkDropdownPopup,
    )
    if beginPopupWithSlot(id, popupSlot, style.popup):
      try:
        let presets = [
          gray(0.0),
          gray(1.0),
          rgb(0.88, 0.18, 0.16),
          rgb(0.95, 0.63, 0.12),
          rgb(0.95, 0.86, 0.20),
          rgb(0.18, 0.62, 0.24),
          rgb(0.16, 0.45, 0.82),
          rgb(0.55, 0.22, 0.78),
          gray(0.0, 0.0),
        ]
        var
          px = style.popupPad
          py = style.popupPad
        for i, preset in presets:
          if px + style.swatchSize > style.popupWidth - style.popupPad:
            px = style.popupPad
            py += style.swatchSize + style.swatchGap
          if drawColorSwatch(
            hashId($id & ":preset:" & $i),
            px,
            py,
            style.swatchSize,
            style.swatchSize,
            preset,
          ):
            color = preset
            closePopup()
          px += style.swatchSize + style.swatchGap
      finally:
        endPopup()

  result =
    color.r != oldColor.r or color.g != oldColor.g or color.b != oldColor.b or
    color.a != oldColor.a

template color*(x, y, w, h: float, color: var Color) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)
  color(id, x, y, w, h, color)

template color*(col: var Color) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)
  autoLayoutPre()
  color(
    id,
    g_uiState.autoLayoutState.x,
    autoLayoutNextY(),
    autoLayoutNextItemWidth(),
    autoLayoutNextItemHeight(),
    col,
  )
  autoLayoutPost()

template colorPicker*(x, y, w, h: float, color: var Color) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)
  colorPicker(id, x, y, w, h, color)

template colorPicker*(color: var Color) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)
  autoLayoutPre()
  colorPicker(
    id,
    g_uiState.autoLayoutState.x,
    autoLayoutNextY(),
    autoLayoutNextItemWidth(),
    autoLayoutNextItemHeight(),
    color,
  )
  autoLayoutPost()

template colorCombo*(
    x, y, w, h: float,
    color: var Color,
    label: string = "",
    style: ColorComboStyle = borrowDefaultColorComboStyle(),
): bool =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line, label)
  colorCombo(id, x, y, w, h, color, label, style)

template colorCombo*(
    color: var Color,
    label: string = "",
    style: ColorComboStyle = borrowDefaultColorComboStyle(),
): bool =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line, label)
  autoLayoutPre()
  let changed = colorCombo(
    id,
    g_uiState.autoLayoutState.x,
    autoLayoutNextY(),
    autoLayoutNextItemWidth(),
    autoLayoutNextItemHeight(),
    color,
    label,
    style,
  )
  autoLayoutPost()
  changed
