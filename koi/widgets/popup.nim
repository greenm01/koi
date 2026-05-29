import nanovg
import glfw

import koi/types
import koi/core
import koi/drawing
import koi/input
import koi/defaults
import koi/internal/algorithms
import koi/utils

proc openPopup*(id: ItemId) =
  alias(ui, g_uiState)
  alias(ps, ui.popupState)

  ps.activeItem = id
  ps.state = psOpenLMBDown
  ps.closed = false
  markActive(id)
  ui.focusCaptured = true

proc closePopup*() =
  alias(ui, g_uiState)
  alias(ps, ui.popupState)

  ps.activeItem = 0
  ps.state = psOpenLMBDown
  ps.closed = true
  if ui.activeItem != 0:
    ui.activeItem = 0
  ui.focusCaptured = false

proc isPopupOpen*(id: ItemId): bool =
  g_uiState.popupState.activeItem == id and not g_uiState.popupState.closed

proc beginPopup*(
    id: ItemId, x, y, w, h: float, style: PopupStyle = borrowDefaultPopupStyle()
): bool =
  alias(ui, g_uiState)
  alias(ps, ui.popupState)

  if not isPopupOpen(id):
    return false

  let (x, y) = addDrawOffset(x, y)

  if ui.hasEvent and not ui.eventHandled and ui.currEvent.kind == ekKey and
      ui.currEvent.action == kaDown and ui.currEvent.key == keyEscape:
    markEventHandled()
    closePopup()
    return false

  if ps.state == psOpenLMBDown:
    if not ui.mbLeftDown:
      ps.state = psOpen
  elif ui.mbLeftDown and
      popupShouldAutoClose(
        ui.mx, ui.my, x, y, w, h, style.autoCloseBorder, style.autoClose
      ):
    closePopup()
    return false

  ps.prevLayer = ui.currentLayer
  ps.prevHitClip = ui.hitClipRect
  ps.prevFocusCaptured = ui.focusCaptured
  ui.currentLayer = layerPopup
  ui.focusCaptured = false
  hitClip(x, y, w, h)

  addDrawLayer(layerPopup, vg):
    drawShadow(vg, x, y, w, h, style.shadow)
    let (rx, ry, rw, rh) = snapToGrid(x, y, w, h, style.backgroundStrokeWidth)
    vg.fillColor(style.backgroundFillColor)
    vg.strokeColor(style.backgroundStrokeColor)
    vg.strokeWidth(style.backgroundStrokeWidth)
    vg.beginPath()
    vg.roundedRect(rx, ry, rw, rh, style.backgroundCornerRadius)
    vg.fill()
    vg.stroke()

  pushDrawOffset(DrawOffset(ox: x, oy: y))
  result = true

proc endPopup*() =
  alias(ui, g_uiState)
  alias(ps, ui.popupState)

  popDrawOffset()
  ui.hitClipRect = ps.prevHitClip
  ui.currentLayer = ps.prevLayer
  if ps.activeItem != 0:
    ui.focusCaptured = true
  else:
    ui.focusCaptured = ps.prevFocusCaptured

template popup*(id: ItemId, x, y, w, h: float, body: untyped) =
  if beginPopup(id, x, y, w, h):
    try:
      body
    finally:
      endPopup()

template popup*(id: ItemId, x, y, w, h: float, style: PopupStyle, body: untyped) =
  if beginPopup(id, x, y, w, h, style):
    try:
      body
    finally:
      endPopup()
