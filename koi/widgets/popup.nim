import nanovg
import glfw

import koi/types
import koi/core
import koi/drawing
import koi/layout
import koi/rect
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

proc beginPopupWithSlot*(
    id: ItemId, slot: LayoutSlot, style: PopupStyle = borrowDefaultPopupStyle()
): bool =
  alias(ui, g_uiState)
  alias(ps, ui.popupState)

  if not isPopupOpen(id):
    return false

  let hitBounds = slot.previousBounds

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
        ui.mx,
        ui.my,
        hitBounds.x,
        hitBounds.y,
        hitBounds.w,
        hitBounds.h,
        style.autoCloseBorder,
        style.autoClose,
      ):
    closePopup()
    return false

  ps.prevLayer = ui.currentLayer
  ps.prevHitClip = ui.hitClipRect
  ps.prevFocusCaptured = ui.focusCaptured
  ps.prevActiveSlotParent = int32(ui.autoLayoutState.activeSlotParent)
  ps.prevActiveSlotUsed = ui.autoLayoutState.activeSlotUsed
  ui.currentLayer = layerPopup
  ui.focusCaptured = false
  ui.autoLayoutState.activeSlotParent = NullLayoutNodeId
  ui.autoLayoutState.activeSlotUsed = false
  hitClip(hitBounds.x, hitBounds.y, hitBounds.w, hitBounds.h)

  addLayoutDrawLayer(layerPopup, slot.nodeId, vg, bounds):
    drawShadow(vg, bounds.x, bounds.y, bounds.w, bounds.h, style.shadow)
    let (rx, ry, rw, rh) =
      snapToGrid(bounds.x, bounds.y, bounds.w, bounds.h, style.backgroundStrokeWidth)
    vg.fillColor(style.backgroundFillColor)
    vg.strokeColor(style.backgroundStrokeColor)
    vg.strokeWidth(style.backgroundStrokeWidth)
    vg.beginPath()
    vg.roundedRect(rx, ry, rw, rh, style.backgroundCornerRadius)
    vg.fill()
    vg.stroke()

  pushDrawOffset(DrawOffset(ox: slot.bounds.x, oy: slot.bounds.y))
  result = true

proc beginPopup*(
    id: ItemId, x, y, w, h: float, style: PopupStyle = borrowDefaultPopupStyle()
): bool =
  if not isPopupOpen(id):
    return false

  let (x, y) = addDrawOffset(x, y)
  let slot = layoutSlot(id, rect(x, y, w, h))
  beginPopupWithSlot(id, slot, style)

proc endPopup*() =
  alias(ui, g_uiState)
  alias(ps, ui.popupState)

  popDrawOffset()
  ui.hitClipRect = ps.prevHitClip
  ui.currentLayer = ps.prevLayer
  ui.autoLayoutState.activeSlotParent = LayoutNodeId(ps.prevActiveSlotParent)
  ui.autoLayoutState.activeSlotUsed = ps.prevActiveSlotUsed
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
