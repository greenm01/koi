import std/options
import std/math
import std/tables

import nanovg
import glfw

import koi/types
import koi/core
import koi/drawing
import koi/layout
import koi/input
import koi/defaults
import koi/widgets/common
import koi/widgets/scrollbar
import koi/utils

const WindowEdgePad = 10.0

# dropDown()
proc dropDown*[T](
    id: ItemId,
    x, y, w, h: float,
    items: seq[string],
    selectedItem_out: var T,
    tooltip: string,
    disabled: bool,
    style: DropDownStyle = defaultDropDownStyle(),
) =
  assert selectedItem_out.ord <= items.high
  var selectedItem = selectedItem_out.clamp(T.low, T.high)

  alias(ui, g_uiState)
  alias(s, style)

  let (x, y) = addDrawOffset(x, y)

  var
    itemListX, itemListY, itemListW, itemListH: float
    maxDisplayItems = items.len
    scrollBarVisible = false
    hoverItem = -1

  discard ui.itemState.hasKeyOrPut(id, DropDownStateVars())
  var ds = cast[DropDownStateVars](ui.itemState[id])

  let
    numItems = items.len
    itemHeight = h # TODO just temporarily

  proc closeDropDown() =
    ds.state = dsClosed
    ds.activeItem = 0
    ui.focusCaptured = false

  if ds.state == dsClosed:
    if isHit(x, y, w, h):
      markHot(id)
      if not disabled and ui.mbLeftDown and hasNoActiveItem():
        markActive(id)
        ds.state = dsOpenLMBPressed
        ds.activeItem = id
        ui.focusCaptured = true

  # We 'fall through' to the open state to avoid a 1-frame delay when clicking
  # the button
  if ds.activeItem == id and ds.state >= dsOpenLMBPressed:
    # Handle ESC
    if ui.hasEvent and (not ui.eventHandled) and ui.currEvent.kind == ekKey and
        ui.currEvent.action in {kaDown}:
      if ui.currEvent.key == keyEscape:
        markEventHandled()
        closeDropDown()

    # Calculate the position of the box around the drop-down items
    var maxItemWidth = 0.0

    g_nvgContext.useFont(s.item.fontSize)

    for i in items:
      let tw = g_nvgContext.textWidth(i)
      maxItemWidth = max(tw, maxItemWidth)

    itemListW = max(maxItemWidth + s.itemListPadHoriz * 2, w)
    let fullItemListH = float(items.len) * itemHeight + s.itemListPadVert * 2

    (itemListX, itemListY) =
      fitRectWithinWindow(itemListW, fullItemListH, x, y, w, h, s.itemListAlign)

    # Crop item list to the window
    let fullyFitsUpward = y + h + fullItemListH + WindowEdgePad <= ui.winHeight
    let fullYfitsDownward = y - fullItemListH - WindowEdgePad >= 0

    if fullyFitsUpward:
      itemListY = y + h
      itemListH = fullItemListH
    elif fullyFitsDownward:
      itemListY = y - fullItemListH
      itemListH = fullItemListH
    else:
      func calcMaxDisplayItems(spaceY: float): Natural =
        max(floor((spaceY - WindowEdgePad - s.itemListPadVert * 2) / itemHeight), 0).Natural

      func calcItemListH(numItems: Natural): float =
        numItems.float * itemHeight + s.itemListPadVert * 2

      let maxDownwardSpace = ui.winHeight - (y + h)
      let maxUpwardSpace = y

      if maxDownwardSpace > maxUpwardSpace:
        maxDisplayItems = calcMaxDisplayItems(maxDownwardSpace)
        itemListH = calcItemListH(maxDisplayItems)
        itemListY = y + h
      else:
        maxDisplayItems = calcMaxDisplayItems(maxUpwardSpace)
        itemListH = calcItemListH(maxDisplayItems)
        itemListY = y - itemListH

    scrollBarVisible = maxDisplayItems < items.len
    if scrollBarVisible:
      itemListW += s.scrollBarWidth
      let (x, _) =
        fitRectWithinWindow(itemListW, fullItemListH, x, y, w, h, s.itemListAlign)
      itemListX = x

    let (itemListX, itemListY, itemListW, itemListH) =
      snapToGrid(itemListX, itemListY, itemListW, itemListH, s.itemListStrokeWidth)

    # Handle scrollwheel
    if scrollBarVisible:
      let scrollBarEndVal = max(items.len.float - maxDisplayItems.float, 0)

      if ui.hasEvent and ui.currEvent.kind == ekScroll:
        ds.displayStartItem =
          (ds.displayStartItem - ui.currEvent.oy).clamp(0, scrollBarEndVal)
        markEventHandled()
    else:
      ds.displayStartItem = 0

    # Hit testing
    let
      insideButton = mouseInside(x, y, w, h)
      insideItemList = mouseInside(itemListX, itemListY, itemListW, itemListH)

    if insideButton or insideItemList:
      markHot(id)
      markActive(id)
    else:
      closeDropDown()

    if insideItemList:
      if not scrollBarVisible or
          (scrollBarVisible and ui.mx < itemListX + itemListW - s.scrollBarWidth):
        hoverItem =
          min(((ui.my - itemListY - s.itemListPadVert) / itemHeight).int, numItems - 1) +
          ds.displayStartItem.Natural

    # LMB released inside the box selects the item under the cursor and closes
    # the dropDown
    if ds.state == dsOpenLMBPressed:
      if not ui.mbLeftDown:
        if hoverItem >= 0:
          selectedItem = T(hoverItem)
          closeDropDown()
        else:
          ds.state = dsOpen
    else:
      if ui.mbLeftDown:
        if hoverItem >= 0:
          selectedItem = T(hoverItem)
          closeDropDown()
        elif insideButton:
          closeDropDown()

  selectedItem_out = selectedItem

  let state =
    if disabled:
      wsDisabled
    elif isHot(id) and hasNoActiveItem():
      wsHover
    elif isHot(id) and isActive(id):
      wsDown
    else:
      wsNormal

  # Drop-down button
  addDrawLayer(ui.currentLayer, vg):
    let sw = s.buttonStrokeWidth
    let (x, y, w, h) = snapToGrid(x, y, w, h, sw)

    let (fillColor, strokeColor) =
      case state
      of wsNormal, wsActive, wsActiveHover:
        (s.buttonFillColor, s.buttonStrokeColor)
      of wsHover:
        (s.buttonFillColorHover, s.buttonStrokeColorHover)
      of wsDown, wsActiveDown:
        (s.buttonFillColorDown, s.buttonStrokeColorDown)
      of wsDisabled:
        (s.buttonFillColorDisabled, s.buttonStrokeColorDisabled)

    vg.fillColor(fillColor)
    vg.strokeColor(strokeColor)
    vg.strokeWidth(sw)

    vg.beginPath()
    vg.roundedRect(x, y, w, h, s.buttonCornerRadius)
    vg.fill()
    vg.stroke()

    let itemText = items[ord(selectedItem)]

    vg.drawLabel(x, y, w, h, itemText, state, s.label)

  # Drop-down items
  if isActive(id) and ds.state >= dsOpenLMBPressed:
    addDrawLayer(layerPopup, vg):
      drawShadow(vg, itemListX, itemListY, itemListW, itemListH, s.shadow)

      # Draw item list box
      vg.fillColor(s.itemListFillColor)
      vg.strokeColor(s.itemListStrokeColor)
      vg.strokeWidth(s.itemListStrokeWidth)

      vg.beginPath()
      vg.roundedRect(itemListX, itemListY, itemListW, itemListH, s.itemListCornerRadius)
      vg.fill()
      vg.stroke()

      # Draw items
      var
        ix = itemListX + s.itemListPadHoriz
        iy = itemListY + s.itemListPadVert

      let start = ds.displayStartItem.Natural

      for i in start ..< (start + maxDisplayItems):
        var state = wsNormal
        if i == hoverItem:
          vg.beginPath()
          vg.rect(itemListX, iy, itemListW, h)
          vg.fillColor(s.itemBackgroundColorHover)
          vg.fill()
          state = wsHover

        vg.drawLabel(ix, iy, itemListW, h, items[i], state, s.item)

        iy += itemHeight

  # Scrollbar
  if isActive(id) and scrollBarVisible:
    # Display scroll bar
    let sbId = hashId(lastIdString() & ":scrollBar")

    let endVal = max(items.len.float - maxDisplayItems.float, 0)
    let thumbSize =
      maxDisplayItems.float *
      ((items.len.float - maxDisplayItems.float) / items.len.float)

    let oldHotItem = ui.hotItem
    let oldActiveItem = ui.activeItem
    let oldFocusCaptured = ui.focusCaptured
    let oldCurrentLayer = ui.currentLayer

    ui.activeItem = 0
    ui.focusCaptured = false
    ui.currentLayer = layerPopup

    let (xo, yo) = (0.0, 0.0) # We need to handle this correctly if needed

    vertScrollBar(
      sbId,
      x = (itemListX + itemListW - s.scrollBarWidth),
      y = itemListY,
      w = s.scrollBarWidth,
      h = itemListH,
      startVal = 0,
      endVal = endVal,
      ds.displayStartItem,
      thumbSize = thumbSize,
      clickStep = 2,
      style = s.scrollBarStyle,
    )

    if ui.hotItem == sbId:
      ui.hotItem = sbId
    else:
      ui.hotItem = oldHotItem

    if ui.activeItem == sbId:
      ui.activeItem = sbId
    else:
      ui.activeItem = oldActiveItem

    ui.focusCaptured = oldFocusCaptured
    ui.currentLayer = oldCurrentLayer

  if isHot(id):
    handleTooltip(id, tooltip)

# DropDown templates

template dropDown*[T](
    x, y, w, h: float,
    items: seq[string],
    selectedItem: var T,
    tooltip: string = "",
    disabled: bool = false,
    style: DropDownStyle = defaultDropDownStyle(),
) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)

  dropDown(id, x, y, w, h, items, selectedItem, tooltip, disabled, style)

template dropDown*[T](
    items: seq[string],
    selectedItem: var T,
    tooltip: string = "",
    disabled: bool = false,
    style: DropDownStyle = defaultDropDownStyle(),
) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)

  autoLayoutPre()

  dropDown(
    id,
    g_uiState.autoLayoutState.x,
    autoLayoutNextY(),
    autoLayoutNextItemWidth(),
    autoLayoutNextItemHeight(),
    items,
    selectedItem,
    tooltip,
    disabled,
    style,
  )

  autoLayoutPost()

template dropDown*[E: enum](
    x, y, w, h: float,
    selectedItem: var E,
    tooltip: string = "",
    disabled: bool = false,
    style: DropDownStyle = defaultDropDownStyle(),
) =
  let
    i = instantiationInfo(fullPaths = true)
    id = nextId(i.filename, i.line)
    items = enumToSeq[E]()

  dropDown(id, x, y, w, h, items, selectedItem, tooltip, disabled, style)

template dropDown*[E: enum](
    selectedItem: var E,
    tooltip: string = "",
    disabled: bool = false,
    style: DropDownStyle = defaultDropDownStyle(),
) =
  let
    i = instantiationInfo(fullPaths = true)
    id = nextId(i.filename, i.line)
    items = enumToSeq[E]()

  autoLayoutPre()

  dropDown(
    id,
    g_uiState.autoLayoutState.x,
    autoLayoutNextY(),
    autoLayoutNextItemWidth(),
    autoLayoutNextItemHeight(),
    items,
    selectedItem,
    tooltip,
    disabled,
    style,
  )

  autoLayoutPost()
