import std/options
import std/math
import std/tables

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
import koi/widgets/popup
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
    style: DropDownStyle = borrowDefaultDropDownStyle(),
    itemPaints: seq[Paint] = @[],
) =
  assert selectedItem_out.ord <= items.high
  var selectedItem = selectedItem_out.clamp(T.low, T.high)

  alias(ui, g_uiState)
  alias(s, style)

  let (x, y) = addDrawOffset(x, y)
  let buttonSlot = layoutSlot(id, rect(x, y, w, h))
  let buttonBounds = buttonSlot.previousBounds

  var
    itemListX, itemListY, itemListW, itemListH: float
    maxDisplayItems = items.len
    scrollBarVisible = false
    hoverItem = -1
    itemListNodeId = NullLayoutNodeId

  discard ui.itemState.hasKeyOrPut(id, DropDownStateVars())
  var ds = cast[DropDownStateVars](ui.itemState[id])

  let
    numItems = items.len
    itemHeight = h # TODO just temporarily
    popupListId = hashId($id & ":popupList")
    scrollBarId = hashId($id & ":scrollBar")

  proc closeDropDown() =
    ds.state = dsClosed
    ds.activeItem = 0
    ds.keyboardItem = -1
    closePopup()
    ui.focusCaptured = false

  if ds.state == dsClosed:
    if isHit(buttonBounds.x, buttonBounds.y, buttonBounds.w, buttonBounds.h):
      markHot(id)
      if not disabled and ui.mbLeftDown and hasNoActiveItem():
        markActive(id)
        ds.state = dsOpenLMBPressed
        ds.activeItem = id
        ds.keyboardItem = ord(selectedItem)
        openPopup(id)
        ui.focusCaptured = true

  # We 'fall through' to the open state to avoid a 1-frame delay when clicking
  # the button
  if ds.activeItem == id and isPopupOpen(id) and ds.state >= dsOpenLMBPressed:
    if ds.keyboardItem < 0:
      ds.keyboardItem = ord(selectedItem)

    # Calculate the position of the box around the drop-down items
    var maxItemWidth = 0.0

    for i in items:
      let tw =
        measureLayoutText(i, s.item.fontSize, s.item.fontFace, LayoutInfinity).prefWidth
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

    # Handle keyboard navigation before mouse hover can override it.
    if ui.hasEvent and (not ui.eventHandled) and ui.currEvent.kind == ekKey and
        ui.currEvent.action in {kaDown}:
      let pageStep = max(maxDisplayItems, 1)
      case ui.currEvent.key
      of keyEscape:
        markEventHandled()
        closeDropDown()
      of keyUp, keyKp8:
        ds.keyboardItem = dropDownKeyboardItem(ds.keyboardItem, numItems, -1)
        markEventHandled()
      of keyDown, keyKp2:
        ds.keyboardItem = dropDownKeyboardItem(ds.keyboardItem, numItems, 1)
        markEventHandled()
      of keyHome, keyKp7:
        ds.keyboardItem = 0
        markEventHandled()
      of keyEnd, keyKp1:
        ds.keyboardItem = numItems - 1
        markEventHandled()
      of keyPageUp, keyKp9:
        ds.keyboardItem = dropDownKeyboardItem(ds.keyboardItem, numItems, -pageStep)
        markEventHandled()
      of keyPageDown, keyKp3:
        ds.keyboardItem = dropDownKeyboardItem(ds.keyboardItem, numItems, pageStep)
        markEventHandled()
      of keyEnter, keyKpEnter:
        if ds.keyboardItem >= 0:
          selectedItem = T(ds.keyboardItem)
        markEventHandled()
        closeDropDown()
      else:
        discard

    let (itemListX, itemListY, itemListW, itemListH) =
      snapToGrid(itemListX, itemListY, itemListW, itemListH, s.itemListStrokeWidth)
    let
      itemListSlot = layoutFollowerSlot(
        popupListId,
        rect(itemListX, itemListY, itemListW, itemListH),
        buttonSlot.nodeId,
        lfkDropdownPopup,
        followAlign = s.itemListAlign,
        windowPad = WindowEdgePad,
      )
      itemListBounds = itemListSlot.previousBounds
    itemListNodeId = itemListSlot.nodeId

    # Hit testing
    let
      insideButton =
        mouseInside(buttonBounds.x, buttonBounds.y, buttonBounds.w, buttonBounds.h)
      insideItemList = mouseInside(
        itemListBounds.x, itemListBounds.y, itemListBounds.w, itemListBounds.h
      )

    # Handle scrollwheel
    if scrollBarVisible:
      let scrollBarEndVal = max(items.len.float - maxDisplayItems.float, 0)

      if insideItemList and ui.hasEvent and not ui.eventHandled and
          ui.currEvent.kind == ekScroll:
        ds.displayStartItem =
          (ds.displayStartItem - ui.currEvent.oy).clamp(0, scrollBarEndVal)
        markEventHandled()
    else:
      ds.displayStartItem = 0

    ds.displayStartItem = scrollStartForActiveItem(
      ds.keyboardItem, ds.displayStartItem.Natural, maxDisplayItems.Natural,
      numItems.Natural,
    ).float

    if insideButton or insideItemList:
      markHot(id)
      markActive(id)
    elif ui.mbLeftDown:
      closeDropDown()

    if insideItemList:
      if not scrollBarVisible or (
        scrollBarVisible and
        ui.mx < itemListBounds.x + itemListBounds.w - s.scrollBarWidth
      ):
        hoverItem = dropDownHoverItem(
          ui.my, itemListBounds.y, s.itemListPadVert, itemHeight,
          ds.displayStartItem.Natural, maxDisplayItems.Natural, numItems.Natural,
        )
        if hoverItem >= 0:
          ds.keyboardItem = hoverItem

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
  addLayoutDrawLayer(ui.currentLayer, buttonSlot.nodeId, vg, bounds):
    let sw = s.buttonStrokeWidth
    let (x, y, w, h) = snapToGrid(bounds.x, bounds.y, bounds.w, bounds.h, sw)

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

    let
      selectedIndex = ord(selectedItem)
      itemText = items[selectedIndex]
      hasImage =
        selectedIndex < itemPaints.len and itemPaints[selectedIndex].image != NoImage

    if hasImage:
      let
        imagePad = max(3.0, min(w, h) * 0.18)
        imageSize = max(0.0, min(h - imagePad * 2, w - imagePad * 2))
        imageX = x + imagePad
        imageY = y + (h - imageSize) * 0.5
      vg.drawImage(imageX, imageY, imageSize, imageSize, itemPaints[selectedIndex])
      vg.drawLabel(
        imageX + imageSize,
        y,
        max(0.0, w - (imageX - x) - imageSize),
        h,
        itemText,
        state,
        s.label,
      )
    else:
      vg.drawLabel(x, y, w, h, itemText, state, s.label)

  # Drop-down items
  if isActive(id) and isPopupOpen(id) and ds.state >= dsOpenLMBPressed and
      not itemListNodeId.isNull:
    addLayoutDrawLayer(layerPopup, itemListNodeId, vg, bounds):
      drawShadow(vg, bounds.x, bounds.y, bounds.w, bounds.h, s.shadow)

      # Draw item list box
      vg.fillColor(s.itemListFillColor)
      vg.strokeColor(s.itemListStrokeColor)
      vg.strokeWidth(s.itemListStrokeWidth)

      vg.beginPath()
      vg.roundedRect(bounds.x, bounds.y, bounds.w, bounds.h, s.itemListCornerRadius)
      vg.fill()
      vg.stroke()

      # Draw items
      var
        ix = bounds.x + s.itemListPadHoriz
        iy = bounds.y + s.itemListPadVert

      let start = ds.displayStartItem.Natural

      for i in start ..< (start + maxDisplayItems):
        var state = wsNormal
        if i == hoverItem or (hoverItem < 0 and i == ds.keyboardItem):
          vg.beginPath()
          vg.rect(bounds.x, iy, bounds.w, h)
          vg.fillColor(s.itemBackgroundColorHover)
          vg.fill()
          state = wsHover

        if i < itemPaints.len and itemPaints[i].image != NoImage:
          let
            imagePad = max(3.0, min(bounds.w, h) * 0.18)
            imageSize = max(0.0, min(h - imagePad * 2, bounds.w - imagePad * 2))
            imageX = ix
            imageY = iy + (h - imageSize) * 0.5
          vg.drawImage(imageX, imageY, imageSize, imageSize, itemPaints[i])
          vg.drawLabel(
            imageX + imageSize, iy, bounds.w - imageSize, h, items[i], state, s.item
          )
        else:
          vg.drawLabel(ix, iy, bounds.w, h, items[i], state, s.item)

        iy += itemHeight

  # Scrollbar
  if isActive(id) and isPopupOpen(id) and scrollBarVisible:
    # Display scroll bar
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

    let scrollSlot = layoutFollowerSlot(
      scrollBarId,
      rect(
        itemListX + itemListW - s.scrollBarWidth, itemListY, s.scrollBarWidth, itemListH
      ),
      itemListNodeId,
      lfkVerticalScrollBar,
    )
    vertScrollBarWithSlot(
      scrollSlot,
      scrollBarId,
      0,
      endVal,
      ds.displayStartItem,
      thumbSize = thumbSize,
      clickStep = 2,
      style = s.scrollBarStyle,
    )

    if ui.hotItem == scrollBarId:
      ui.hotItem = scrollBarId
    else:
      ui.hotItem = oldHotItem

    if ui.activeItem == scrollBarId:
      ui.activeItem = scrollBarId
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
    style: DropDownStyle = borrowDefaultDropDownStyle(),
    itemPaints: seq[Paint] = @[],
) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)

  dropDown(id, x, y, w, h, items, selectedItem, tooltip, disabled, style, itemPaints)

template dropDown*[T](
    items: seq[string],
    selectedItem: var T,
    tooltip: string = "",
    disabled: bool = false,
    style: DropDownStyle = borrowDefaultDropDownStyle(),
    itemPaints: seq[Paint] = @[],
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
    itemPaints,
  )

  autoLayoutPost()

template dropDown*[E: enum](
    x, y, w, h: float,
    selectedItem: var E,
    tooltip: string = "",
    disabled: bool = false,
    style: DropDownStyle = borrowDefaultDropDownStyle(),
    itemPaints: seq[Paint] = @[],
) =
  let
    i = instantiationInfo(fullPaths = true)
    id = nextId(i.filename, i.line)
    items = enumToSeq[E]()

  dropDown(id, x, y, w, h, items, selectedItem, tooltip, disabled, style, itemPaints)

template dropDown*[E: enum](
    selectedItem: var E,
    tooltip: string = "",
    disabled: bool = false,
    style: DropDownStyle = borrowDefaultDropDownStyle(),
    itemPaints: seq[Paint] = @[],
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
    itemPaints,
  )

  autoLayoutPost()
