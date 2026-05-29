import std/tables

import nanovg

import koi/types
import koi/core
import koi/drawing
import koi/input
import koi/defaults
import koi/widgets/button
import koi/widgets/popup
import koi/widgets/selectable
import koi/utils

type ContextMenuState = ref object of RootObj
  anchorX*: float
  anchorY*: float

var
  menuBarActive = false
  menuBarX = 0.0
  menuBarY = 0.0
  menuBarH = 0.0
  menuBarCursorX = 0.0
  menuItemX = 0.0
  menuItemY = 0.0
  menuItemW = 0.0
  activeMenuStyle = borrowDefaultMenuStyle()

proc beginMenuItems(popupW: float, style: MenuStyle) =
  if isActive(g_uiState.popupState.activeItem):
    g_uiState.activeItem = 0
  menuItemX = style.popupPad
  menuItemY = style.popupPad
  menuItemW = max(0.0, popupW - style.popupPad * 2)
  activeMenuStyle = style

proc beginMenuBar*(x, y, w, h: float, style: MenuStyle = borrowDefaultMenuStyle()) =
  alias(ui, g_uiState)

  menuBarActive = true
  menuBarX = x
  menuBarY = y
  menuBarH = h
  menuBarCursorX = x
  activeMenuStyle = style

  let (sx, sy) = addDrawOffset(x, y)
  addDrawLayer(ui.currentLayer, vg):
    vg.fillColor(style.barFillColor)
    vg.beginPath()
    vg.rect(sx, sy, w, h)
    vg.fill()

proc endMenuBar*() =
  menuBarActive = false

template menuBar*(x, y, w, h: float, body: untyped) =
  beginMenuBar(x, y, w, h)
  try:
    body
  finally:
    endMenuBar()

template menuBar*(x, y, w, h: float, style: MenuStyle, body: untyped) =
  beginMenuBar(x, y, w, h, style)
  try:
    body
  finally:
    endMenuBar()

proc menuItem*(
    id: ItemId,
    label: string,
    disabled: bool = false,
    tooltip: string = "",
    style: MenuStyle = activeMenuStyle,
): bool =
  var selected = false
  result = selectable(
    id,
    menuItemX,
    menuItemY,
    menuItemW,
    style.menuItemHeight,
    label,
    selected,
    tooltip,
    disabled,
    style = style.item,
  )
  menuItemY += style.menuItemHeight
  if result:
    closePopup()

template menuItem*(label: string, disabled: bool = false, tooltip: string = ""): bool =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line, label)
  menuItem(id, label, disabled, tooltip)

template menu*(label: string, popupW, popupH: float, body: untyped) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line, label)
  let style = activeMenuStyle
  let buttonX = menuBarCursorX
  let buttonW = style.menuButtonWidth

  if button(buttonX, menuBarY, buttonW, menuBarH, label, style = style.button):
    openPopup(id)

  menuBarCursorX += buttonW

  if beginPopup(id, buttonX, menuBarY + menuBarH, popupW, popupH, style.popup):
    beginMenuItems(popupW, style)
    try:
      body
    finally:
      endPopup()

proc contextMenuState(id: ItemId): ContextMenuState =
  alias(ui, g_uiState)
  discard ui.itemState.hasKeyOrPut(id, ContextMenuState())
  cast[ContextMenuState](ui.itemState[id])

proc beginContextMenu*(
    id: ItemId,
    x, y, w, h, popupW, popupH: float,
    style: MenuStyle = borrowDefaultMenuStyle(),
): bool =
  alias(ui, g_uiState)

  let (sx, sy) = addDrawOffset(x, y)
  let state = contextMenuState(id)

  if ui.mbRightDown and hasNoActiveItem() and isHit(sx, sy, w, h):
    let offset = drawOffset()
    state.anchorX = ui.mx - offset.ox
    state.anchorY = ui.my - offset.oy
    openPopup(id)

  if beginPopup(id, state.anchorX, state.anchorY, popupW, popupH, style.popup):
    beginMenuItems(popupW, style)
    result = true

proc endContextMenu*() =
  endPopup()

template contextMenu*(id: ItemId, x, y, w, h, popupW, popupH: float, body: untyped) =
  if beginContextMenu(id, x, y, w, h, popupW, popupH):
    try:
      body
    finally:
      endContextMenu()

template contextMenu*(x, y, w, h, popupW, popupH: float, body: untyped) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)
  contextMenu(id, x, y, w, h, popupW, popupH):
    body
