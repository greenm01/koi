import std/math
import std/tables

import nanovg
import glfw

import koi/types
import koi/core
import koi/drawing
import koi/layout
import koi/rect
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
  menuBarIndex = 0
  menuItemX = 0.0
  menuItemY = 0.0
  menuItemW = 0.0
  menuItemIndex = 0
  menuKeyboardActivate = false
  menuItemsOwnerId: ItemId = 0
  menuItemDisabledPrevByMenu: Table[ItemId, seq[bool]]
  menuItemDisabledCurr: seq[bool]
  activeMenuStyle = borrowDefaultMenuStyle()

func nextFocusableMenuItem(disabled: openArray[bool], start, step: int): int =
  if disabled.len == 0:
    return 0

  var item = start + step
  while item >= 0 and item <= disabled.high:
    if not disabled[item]:
      return item
    item += step

  start.clamp(0, disabled.high)

proc beginMenuItems(popupW: float, style: MenuStyle) =
  alias(mt, g_uiState.menuTraversalState)
  if isActive(g_uiState.popupState.activeItem):
    g_uiState.activeItem = 0
  menuItemX = style.popupPad
  menuItemY = style.popupPad
  menuItemW = max(0.0, popupW - style.popupPad * 2)
  menuItemIndex = 0
  menuKeyboardActivate = false
  menuItemDisabledCurr = @[]
  menuItemsOwnerId = g_uiState.popupState.activeItem
  activeMenuStyle = style
  let menuItemDisabledPrev = menuItemDisabledPrevByMenu.getOrDefault(menuItemsOwnerId)
  if g_uiState.hasEvent and not g_uiState.eventHandled and
      g_uiState.currEvent.kind == ekKey and g_uiState.currEvent.action in {kaDown}:
    case g_uiState.currEvent.key
    of keyUp, keyKp8:
      mt.activeItem = nextFocusableMenuItem(menuItemDisabledPrev, mt.activeItem, -1)
      markEventHandled()
    of keyDown, keyKp2:
      mt.activeItem = nextFocusableMenuItem(menuItemDisabledPrev, mt.activeItem, 1)
      markEventHandled()
    of keyEnter, keyKpEnter:
      menuKeyboardActivate = true
      markEventHandled()
    else:
      discard

proc endMenuItems() =
  alias(mt, g_uiState.menuTraversalState)
  mt.itemCount = menuItemIndex.Natural
  if menuItemIndex > 0:
    mt.activeItem = mt.activeItem.clamp(0, menuItemIndex - 1)
    if menuItemDisabledCurr.len == menuItemIndex and menuItemDisabledCurr[mt.activeItem]:
      let nextItem = nextFocusableMenuItem(menuItemDisabledCurr, -1, 1)
      mt.activeItem =
        if nextItem >= 0 and nextItem <= menuItemDisabledCurr.high and
            not menuItemDisabledCurr[nextItem]: nextItem else: 0
  else:
    mt.activeItem = 0
  menuItemDisabledPrevByMenu[menuItemsOwnerId] = menuItemDisabledCurr

proc beginMenuBar*(x, y, w, h: float, style: MenuStyle = borrowDefaultMenuStyle()) =
  alias(ui, g_uiState)
  alias(mt, ui.menuTraversalState)

  menuBarActive = true
  menuBarX = x
  menuBarY = y
  menuBarH = h
  menuBarCursorX = x
  menuBarIndex = 0
  mt.moved = 0
  activeMenuStyle = style

  if ui.hasEvent and not ui.eventHandled and ui.currEvent.kind == ekKey and
      ui.currEvent.action in {kaDown}:
    case ui.currEvent.key
    of keyEscape:
      mt.activeMenu = 0
      mt.activeMenuIndex = 0
      mt.activeItem = 0
      closePopup()
      markEventHandled()
    of keyLeft, keyKp4:
      mt.moved = -1
      markEventHandled()
    of keyRight, keyKp6:
      mt.moved = 1
      markEventHandled()
    of keyDown, keyKp2:
      if mt.activeMenu != 0:
        mt.activeItem = 0
        markEventHandled()
    else:
      discard

  let (sx, sy) = addDrawOffset(x, y)
  let slot = layoutDrawSlot(0, rect(sx, sy, w, h))

  addLayoutDrawLayer(ui.currentLayer, slot.nodeId, vg, bounds):
    vg.fillColor(style.barFillColor)
    vg.beginPath()
    vg.rect(bounds.x, bounds.y, bounds.w, bounds.h)
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
  alias(mt, g_uiState.menuTraversalState)
  let itemIndex = menuItemIndex
  menuItemDisabledCurr.add(disabled)
  var selected = itemIndex == mt.activeItem
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
  if not disabled and selected and menuKeyboardActivate:
    result = true
  menuItemY += style.menuItemHeight
  inc(menuItemIndex)
  if result:
    mt.activeMenu = 0
    closePopup()

template menuItem*(label: string, disabled: bool = false, tooltip: string = ""): bool =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line, label)
  menuItem(id, label, disabled, tooltip)

proc menuItemImageLabel*(
    id: ItemId,
    paint: Paint,
    label: string,
    disabled: bool = false,
    tooltip: string = "",
    style: MenuStyle = activeMenuStyle,
): bool =
  alias(mt, g_uiState.menuTraversalState)
  let itemIndex = menuItemIndex
  menuItemDisabledCurr.add(disabled)
  var selected = itemIndex == mt.activeItem
  result = selectableImageLabel(
    id,
    menuItemX,
    menuItemY,
    menuItemW,
    style.menuItemHeight,
    paint,
    label,
    selected,
    tooltip,
    disabled,
    style = style.item,
  )
  if not disabled and selected and menuKeyboardActivate:
    result = true
  menuItemY += style.menuItemHeight
  inc(menuItemIndex)
  if result:
    mt.activeMenu = 0
    closePopup()

proc menuItemImage*(
    id: ItemId,
    paint: Paint,
    disabled: bool = false,
    tooltip: string = "",
    style: MenuStyle = activeMenuStyle,
): bool =
  menuItemImageLabel(id, paint, "", disabled, tooltip, style)

proc menuSeparator*(style: MenuStyle = activeMenuStyle) =
  alias(ui, g_uiState)
  let
    h = max(6.0, style.menuItemHeight * 0.35)
    (sx, sy) = addDrawOffset(menuItemX, menuItemY)
    slot = layoutDrawSlot(0, rect(sx, sy, menuItemW, h))
  menuItemDisabledCurr.add(true)

  addLayoutDrawLayer(ui.currentLayer, slot.nodeId, vg, bounds):
    vg.strokeColor(style.item.strokeColorHover)
    vg.strokeWidth(1)
    vg.beginPath()
    vg.horizLine(bounds.x + 6, bounds.y + bounds.h * 0.5, max(0.0, bounds.w - 12))
    vg.stroke()

  menuItemY += h
  inc(menuItemIndex)

proc menuLabel*(label: string, style: MenuStyle = activeMenuStyle) =
  alias(ui, g_uiState)
  let (sx, sy) = addDrawOffset(menuItemX, menuItemY)
  let slot = layoutDrawSlot(0, rect(sx, sy, menuItemW, style.menuItemHeight))
  menuItemDisabledCurr.add(true)

  addLayoutDrawLayer(ui.currentLayer, slot.nodeId, vg, bounds):
    vg.drawLabel(
      bounds.x, bounds.y, bounds.w, bounds.h, label, wsDisabled, style.item.label
    )

  menuItemY += style.menuItemHeight
  inc(menuItemIndex)

template menuItemImageLabel*(
    paint: Paint, label: string, disabled: bool = false, tooltip: string = ""
): bool =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line, label)
  menuItemImageLabel(id, paint, label, disabled, tooltip)

template menuItemImage*(
    paint: Paint, disabled: bool = false, tooltip: string = ""
): bool =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)
  menuItemImage(id, paint, disabled, tooltip)

template menuImpl(label: string, popupW, popupH: float, disabled: bool, body: untyped) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line, label)
  let popupId = hashId($id & ":popup")
  let style = activeMenuStyle
  let buttonX = menuBarCursorX
  let buttonW = style.menuButtonWidth
  let headerIndex = menuBarIndex
  let (buttonSx, buttonSy) = addDrawOffset(buttonX, menuBarY)
  let buttonSlot = layoutSlot(id, rect(buttonSx, buttonSy, buttonW, menuBarH))

  if not disabled and g_uiState.menuTraversalState.activeMenu != 0 and
      g_uiState.menuTraversalState.activeMenuIndex + g_uiState.menuTraversalState.moved ==
      headerIndex:
    g_uiState.menuTraversalState.activeMenu = id
    g_uiState.menuTraversalState.activeMenuIndex = headerIndex
    g_uiState.menuTraversalState.activeItem = 0
    openPopup(id)

  if buttonWithSlot(buttonSlot, id, label, "", disabled, style = style.button):
    g_uiState.menuTraversalState.activeMenu = id
    g_uiState.menuTraversalState.activeMenuIndex = headerIndex
    g_uiState.menuTraversalState.activeItem = 0
    openPopup(id)

  menuBarCursorX += buttonW
  inc(menuBarIndex)

  if disabled and isPopupOpen(id):
    closePopup()

  if not disabled and isPopupOpen(id):
    let popupSlot = layoutFollowerSlot(
      popupId,
      rect(buttonSx, buttonSy + menuBarH, popupW, popupH),
      buttonSlot.nodeId,
      lfkDropdownPopup,
    )
    if beginPopupWithSlot(id, popupSlot, style.popup):
      g_uiState.menuTraversalState.activeMenu = id
      g_uiState.menuTraversalState.activeMenuIndex = headerIndex
      beginMenuItems(popupW, style)
      try:
        body
      finally:
        endMenuItems()
        endPopup()

template menu*(label: string, popupW, popupH: float, body: untyped) =
  menuImpl(label, popupW, popupH, disabled = false):
    body

template menu*(label: string, popupW, popupH: float, disabled: bool, body: untyped) =
  menuImpl(label, popupW, popupH, disabled):
    body

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
  endMenuItems()
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
