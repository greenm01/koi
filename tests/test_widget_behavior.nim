import std/options
import std/tables
import std/unittest

import glfw
import nanovg

import koi/core
import koi/defaults
import koi/drawing
import koi/input
import koi/internal/widget_behavior
import koi/layout
import koi/rect
import koi/types
import koi/widgets/button
import koi/widgets/chart
import koi/widgets/checkbox
import koi/widgets/colorpicker
import koi/widgets/common
import koi/widgets/dropdown
import koi/widgets/groupbox
import koi/widgets/image
import koi/widgets/label
import koi/widgets/listview
import koi/widgets/dialog
import koi/widgets/menu
import koi/widgets/popup
import koi/widgets/progress
import koi/widgets/property
import koi/widgets/radiobuttons
import koi/widgets/section
import koi/widgets/selectable
import koi/widgets/scrollview
import koi/widgets/scrollbar
import koi/widgets/slider
import koi/widgets/table
import koi/widgets/textarea
import koi/widgets/textfield
import koi/widgets/togglebutton

template checkRect(actual, expected: Rect) =
  check actual.x == expected.x
  check actual.y == expected.y
  check actual.w == expected.w
  check actual.h == expected.h

proc resetUi() =
  g_uiState = UIState.default
  g_uiState.winWidth = 100
  g_uiState.winHeight = 100
  g_uiState.hitClipRect = rect(0, 0, 100, 100)
  g_uiState.drawOffsetStack = @[DrawOffset(ox: 0, oy: 0)]
  g_drawLayers.init()

suite "popup behavior":
  test "popup open begin and end preserve captured focus":
    resetUi()

    openPopup(30)
    check isPopupOpen(30)
    check isActive(30)
    check g_uiState.focusCaptured

    g_uiState.mbLeftDown = false
    check beginPopup(30, 10, 10, 30, 30)
    check currentLayer() == layerPopup
    checkRect(g_uiState.hitClipRect, rect(10, 10, 30, 30))

    endPopup()
    check currentLayer() == layerDefault
    check g_uiState.focusCaptured

    closePopup()
    check not isPopupOpen(30)
    check not g_uiState.focusCaptured

  test "popup closes on escape":
    resetUi()

    openPopup(30)
    g_uiState.hasEvent = true
    g_uiState.currEvent = Event(kind: ekKey, key: keyEscape, action: kaDown, mods: {})

    check not beginPopup(30, 10, 10, 30, 30)
    check not isPopupOpen(30)
    check eventHandled()

  test "popup closes on outside click after first release":
    resetUi()

    openPopup(30)
    g_uiState.mbLeftDown = false
    check beginPopup(30, 10, 10, 30, 30)
    endPopup()

    g_uiState.mx = 95
    g_uiState.my = 95
    g_uiState.mbLeftDown = true

    check not beginPopup(30, 10, 10, 30, 30)
    check not isPopupOpen(30)

  test "popup closed from its body releases captured focus":
    resetUi()

    openPopup(30)
    g_uiState.mbLeftDown = false
    check beginPopup(30, 10, 10, 30, 30)
    check not g_uiState.focusCaptured

    closePopup()
    endPopup()

    check not isPopupOpen(30)
    check not g_uiState.focusCaptured

  test "popup hit clipping uses a previous solved rect":
    resetUi()
    g_uiState.layoutRects[31] = rect(40, 40, 20, 10)

    openPopup(31)
    g_uiState.mbLeftDown = false

    check beginPopup(31, 0, 0, 10, 10)
    checkRect(g_uiState.hitClipRect, rect(40, 40, 20, 10))
    check g_uiState.layoutArena.nodes.len == 1
    check g_drawLayers.layers[ord(layerPopup)].len == 1

    endPopup()

  test "popup auto close uses a previous solved rect":
    resetUi()
    g_uiState.layoutRects[32] = rect(40, 40, 20, 20)
    let style = borrowDefaultPopupStyle().deepCopy
    style.autoCloseBorder = 0

    openPopup(32)
    g_uiState.popupState.state = psOpen
    g_uiState.mx = 15
    g_uiState.my = 15
    g_uiState.mbLeftDown = true

    check not beginPopup(32, 10, 10, 20, 20, style)
    check not isPopupOpen(32)

  test "popup body children are scoped to the solved popup rect":
    resetUi()

    openPopup(60)
    g_uiState.mbLeftDown = false

    beginFrameLayout()
    let targetSlot = layoutSlot(61, rect(90, 80, 5, 5))
    let popupSlot =
      layoutFollowerSlot(62, rect(90, 85, 30, 20), targetSlot.nodeId, lfkDropdownPopup)
    var childSlot = LayoutSlot(nodeId: NullLayoutNodeId)
    if beginPopupWithSlot(60, popupSlot):
      childSlot = layoutDrawSlot(63, rect(92, 88, 4, 4))
      endPopup()
    finishFrameLayout()

    check not childSlot.nodeId.isNull
    check int32(g_uiState.layoutArena.nodes[childSlot.nodeId.int].parent) ==
      int32(popupSlot.nodeId)
    checkRect(g_uiState.layoutRects[62], rect(60, 60, 30, 20))
    checkRect(g_uiState.layoutRects[63], rect(62, 63, 4, 4))

suite "menu behavior":
  test "menu bar registers a draw-only layout node":
    resetUi()

    beginMenuBar(0, 0, 80, 10)

    check g_uiState.layoutArena.nodes.len == 1
    check g_drawLayers.layers[ord(layerDefault)].len == 1

    endMenuBar()

  test "menu labels and separators register draw-only layout nodes":
    resetUi()

    openPopup(40)
    g_uiState.mbLeftDown = false
    check beginContextMenu(40, 0, 0, 30, 30, 100, 80)
    menuLabel("Section")
    menuSeparator()

    check g_uiState.layoutArena.nodes.len == 3
    check g_drawLayers.layers[ord(layerPopup)].len == 3

    endContextMenu()

  test "context menu opens from right click inside bounds":
    resetUi()

    g_uiState.mx = 16
    g_uiState.my = 16
    g_uiState.mbRightDown = true

    check beginContextMenu(40, 0, 0, 30, 30, 100, 60)
    check isPopupOpen(40)
    endContextMenu()

  test "context menu ignores right click outside bounds":
    resetUi()

    g_uiState.mx = 50
    g_uiState.my = 50
    g_uiState.mbRightDown = true

    check not beginContextMenu(40, 0, 0, 30, 30, 100, 60)
    check not isPopupOpen(40)

  test "menu item click closes popup":
    resetUi()

    g_uiState.mx = 16
    g_uiState.my = 16
    g_uiState.mbRightDown = true
    check beginContextMenu(40, 0, 0, 30, 30, 100, 60)
    endContextMenu()

    g_uiState.hotItem = 0
    g_uiState.mbRightDown = false
    g_uiState.mbLeftDown = true
    g_uiState.mx = 22
    g_uiState.my = 22
    check beginContextMenu(40, 0, 0, 30, 30, 100, 60)
    check not menuItem(41, "Action")
    endContextMenu()

    g_uiState.hotItem = 0
    g_uiState.mbLeftDown = false
    g_uiState.mx = 22
    g_uiState.my = 22
    check beginContextMenu(40, 0, 0, 30, 30, 100, 60)
    check menuItem(41, "Action")
    check not isPopupOpen(40)
    endContextMenu()

  test "menu item activates from keyboard enter":
    resetUi()

    g_uiState.mx = 16
    g_uiState.my = 16
    g_uiState.mbRightDown = true
    check beginContextMenu(40, 0, 0, 30, 30, 100, 60)
    endContextMenu()

    g_uiState.mbRightDown = false
    g_uiState.hasEvent = true
    g_uiState.currEvent = Event(kind: ekKey, key: keyEnter, action: kaDown, mods: {})
    g_uiState.menuTraversalState.activeItem = 0

    check beginContextMenu(40, 0, 0, 30, 30, 100, 60)
    check menuItem(41, "Action")
    check eventHandled()
    check not isPopupOpen(40)
    endContextMenu()

  test "menu keyboard traversal skips disabled and separator rows":
    resetUi()

    openPopup(40)
    g_uiState.mbLeftDown = false
    check beginContextMenu(40, 0, 0, 30, 30, 100, 80)
    discard menuItem(41, "Disabled", disabled = true)
    menuSeparator()
    check not menuItem(42, "Action")
    endContextMenu()
    check g_uiState.menuTraversalState.activeItem == 2

    g_uiState.hasEvent = true
    g_uiState.currEvent = Event(kind: ekKey, key: keyEnter, action: kaDown, mods: {})
    check beginContextMenu(40, 0, 0, 30, 30, 100, 80)
    discard menuItem(41, "Disabled", disabled = true)
    menuSeparator()
    check menuItem(42, "Action")
    check eventHandled()
    check not isPopupOpen(40)
    endContextMenu()

  test "open menu bar popup follows solved menu button rect":
    resetUi()
    g_uiState.winWidth = 240
    g_uiState.winHeight = 120

    useNextId("menu-layout-test")
    let
      menuId = hashId("menu-layout-test")
      popupId = hashId($menuId & ":popup")
    openPopup(menuId)
    g_uiState.mbLeftDown = false

    beginFrameLayout()
    beginMenuBar(10, 10, 120, 24)
    menu("File", 80, 40):
      menuLabel("Open")
    endMenuBar()
    finishFrameLayout()

    var buttonNode = NullLayoutNodeId
    var popupNode = NullLayoutNodeId
    for node in g_uiState.layoutArena.nodes:
      if node.itemId == menuId:
        buttonNode = node.id
      elif node.itemId == popupId:
        popupNode = node.id

    check not buttonNode.isNull
    check not popupNode.isNull
    check g_uiState.layoutArena.nodes[popupNode.int].placement.kind == lpkFollow
    check g_uiState.layoutArena.nodes[popupNode.int].placement.followKind ==
      lfkDropdownPopup
    check int32(g_uiState.layoutArena.nodes[popupNode.int].placement.target) ==
      int32(buttonNode)
    check g_uiState.layoutRects.hasKey(menuId)
    check g_uiState.layoutRects.hasKey(popupId)

    let
      buttonRect = g_uiState.layoutRects[menuId]
      popupRect = g_uiState.layoutRects[popupId]
    check popupRect.x == buttonRect.x
    check popupRect.y == buttonRect.y + buttonRect.h
    check popupRect != buttonRect

suite "image widget behavior":
  test "image button with an empty paint keeps normal click behavior":
    resetUi()
    var paint = Paint()

    g_uiState.mx = 5
    g_uiState.my = 5
    g_uiState.mbLeftDown = true
    check not buttonImageLabel(50, 0, 0, 30, 20, paint, "Image")
    check isActive(50)

    g_uiState.hotItem = 0
    g_uiState.mbLeftDown = false
    check buttonImageLabel(50, 0, 0, 30, 20, paint, "Image")

  test "manual image drawing registers a draw-only layout node":
    resetUi()
    var paint = Paint()

    image(0, 0, 20, 10, paint)

    check g_uiState.layoutArena.nodes.len == 1
    check g_drawLayers.layers[ord(layerDefault)].len == 1

  test "auto-layout image registers under active rows":
    resetUi()
    var params = DefaultAutoLayoutParams
    params.itemsPerRow = 1
    params.rowWidth = 20
    params.leftPad = 0
    params.rightPad = 0
    params.rowPad = 0
    params.sectionPad = 0
    params.defaultRowHeight = 10
    params.defaultItemHeight = 10
    initAutoLayout(params)
    beginFrameLayout()

    var paint = Paint()
    autoLayoutPre()
    let imageRow = g_uiState.autoLayoutState.autoRow
    image(
      51,
      g_uiState.autoLayoutState.x,
      autoLayoutNextY(),
      autoLayoutNextItemWidth(),
      autoLayoutNextItemHeight(),
      paint,
    )
    autoLayoutPost()

    check int32(g_uiState.layoutArena.nodes[3].parent) == int32(imageRow)

suite "layout-integrated widget behavior":
  test "label registers a text node and queues solved-rect drawing":
    resetUi()

    label(23, 0, 0, 40, 12, "Text")

    check g_uiState.layoutArena.nodes.len == 1
    check g_uiState.layoutArena.nodes[0].kind == lnkText
    check g_uiState.layoutArena.nodes[0].text == "Text"
    check g_drawLayers.layers[ord(layerDefault)].len == 1

  test "button hit testing uses a previous solved rect when present":
    resetUi()
    g_uiState.layoutRects[20] = rect(40, 40, 20, 20)
    g_uiState.mx = 45
    g_uiState.my = 45
    g_uiState.mbLeftDown = true

    discard button(20, 0, 0, 10, 10, "Button", "", disabled = false)

    check isHot(20)
    check isActive(20)
    check g_drawLayers.layers[ord(layerDefault)].len == 1

  test "button hit testing falls back to the current rect on first frame":
    resetUi()
    g_uiState.mx = 5
    g_uiState.my = 5
    g_uiState.mbLeftDown = true

    discard button(21, 0, 0, 10, 10, "Button", "", disabled = false)

    check isHot(21)
    check isActive(21)

  test "progress tooltip hit testing uses a previous solved rect":
    resetUi()
    g_uiState.layoutRects[22] = rect(30, 30, 20, 20)
    g_uiState.mx = 35
    g_uiState.my = 35

    progress(22, 0, 0, 10, 10, 1, 2, tooltip = "Value")

    check isHot(22)
    check g_drawLayers.layers[ord(layerDefault)].len == 1

  test "checkbox hit testing uses a previous solved rect":
    resetUi()
    var checked = false
    g_uiState.layoutRects[26] = rect(40, 40, 20, 20)
    g_uiState.mx = 45
    g_uiState.my = 45
    g_uiState.mbLeftDown = true

    checkBox(26, 0, 0, 10, checked, "", disabled = false)

    check isHot(26)
    check isActive(26)
    check g_drawLayers.layers[ord(layerDefault)].len == 1

  test "checkbox toggles on mouse release while hot and active":
    resetUi()
    var checked = false
    g_uiState.layoutRects[260] = rect(40, 40, 20, 20)
    g_uiState.mx = 45
    g_uiState.my = 45
    g_uiState.mbLeftDown = true

    checkBox(260, 0, 0, 10, checked, "", disabled = false)
    check not checked
    check isActive(260)

    g_uiState.hotItem = 0
    g_uiState.mbLeftDown = false
    checkBox(260, 0, 0, 10, checked, "", disabled = false)

    check checked

  test "toggle button queues drawing with the current layout rect":
    resetUi()
    var active = false
    var drawn = rect(0, 0, 0, 0)
    let drawProc: ToggleButtonDrawProc = proc(
        vg: NVGContext,
        id: ItemId,
        x, y, w, h: float,
        label: string,
        state: WidgetState,
        style: ToggleButtonStyle,
    ) =
      drawn = rect(x, y, w, h)

    toggleButton(
      27,
      3,
      4,
      30,
      12,
      active,
      "Off",
      "On",
      "",
      disabled = false,
      drawProc = drawProc.some,
    )
    g_drawLayers.draw(g_nvgContext)

    checkRect(drawn, rect(3, 4, 30, 12))

  test "selectable hit testing uses a previous solved rect":
    resetUi()
    var selected = false
    g_uiState.layoutRects[28] = rect(40, 40, 20, 20)
    g_uiState.mx = 45
    g_uiState.my = 45
    g_uiState.mbLeftDown = true

    discard selectable(28, 0, 0, 10, 10, "Item", selected)

    check isHot(28)
    check isActive(28)

  test "radio grid registers one bounding layout slot":
    resetUi()
    type Choice = enum
      c0
      c1
      c2

    var activeButtons = @[c0]
    radioButtons(
      29,
      0,
      0,
      10,
      5,
      @["A", "B", "C"],
      activeButtons,
      multiselect = false,
      allowNoSelection = false,
      layout = RadioButtonsLayout(kind: rblGridHoriz, itemsPerRow: 2),
    )

    check g_uiState.layoutArena.nodes.len == 1
    checkRect(g_uiState.layoutArena.nodes[0].rect, rect(0, 0, 20, 10))

  test "radio grid hit testing uses the previous bounding slot":
    resetUi()
    type Choice = enum
      c0
      c1
      c2

    var activeButtons = @[c0]
    g_uiState.layoutRects[30] = rect(40, 40, 20, 10)
    g_uiState.mx = 45
    g_uiState.my = 47
    g_uiState.mbLeftDown = true

    radioButtons(
      30,
      0,
      0,
      10,
      5,
      @["A", "B", "C"],
      activeButtons,
      multiselect = false,
      allowNoSelection = false,
      layout = RadioButtonsLayout(kind: rblGridHoriz, itemsPerRow: 2),
    )

    check isHot(30)
    check isActive(30)
    check g_uiState.radioButtonState.activeItem == 2

  test "section header hit testing uses a previous solved rect":
    resetUi()
    var expanded = false
    initAutoLayout(DefaultAutoLayoutParams)
    let id = hashId("section-header")
    g_uiState.layoutRects[id] = rect(40, 40, 30, 20)
    g_uiState.mx = 45
    g_uiState.my = 45
    g_uiState.mbLeftDown = true

    useNextId("section-header")
    check not sectionHeader("Header", expanded)

    check isHot(id)
    check isActive(id)

  test "section header toggles on mouse release while hot and active":
    resetUi()
    var expanded = false
    initAutoLayout(DefaultAutoLayoutParams)
    let id = hashId("section-header-toggle")
    g_uiState.layoutRects[id] = rect(40, 40, 30, 20)
    g_uiState.mx = 45
    g_uiState.my = 45
    g_uiState.mbLeftDown = true

    useNextId("section-header-toggle")
    check not sectionHeader("Header", expanded)
    check not expanded
    check isActive(id)

    g_uiState.hotItem = 0
    g_uiState.mbLeftDown = false
    useNextId("section-header-toggle")
    check sectionHeader("Header", expanded)
    check expanded

  test "color swatch hit testing uses a previous solved rect":
    resetUi()
    var c = rgb(0.2, 0.4, 0.6)
    g_uiState.layoutRects[31] = rect(40, 40, 20, 20)
    g_uiState.mx = 45
    g_uiState.my = 45
    g_uiState.mbLeftDown = true

    color(31, 0, 0, 10, 10, c)

    check isHot(31)
    check isActive(31)

  test "closed auto-layout color combo preview follows button without row content":
    resetUi()
    var params = DefaultAutoLayoutParams
    params.itemsPerRow = 1
    params.rowWidth = 60
    params.leftPad = 0
    params.rightPad = 0
    params.rowPad = 0
    params.sectionPad = 0
    params.defaultRowHeight = 20
    params.defaultItemHeight = 20
    initAutoLayout(params)
    beginFrameLayout()

    let comboId: ItemId = 33
    let previewId = hashId($comboId & ":preview")
    var c = rgb(0.2, 0.4, 0.6)
    autoLayoutPre()
    let comboRow = g_uiState.autoLayoutState.autoRow
    discard colorCombo(
      comboId,
      g_uiState.autoLayoutState.x,
      autoLayoutNextY(),
      autoLayoutNextItemWidth(),
      autoLayoutNextItemHeight(),
      c,
      "Accent",
    )
    autoLayoutPost()
    finishFrameLayout()

    var rowChildren = 0
    var comboNode = NullLayoutNodeId
    var previewNode = NullLayoutNodeId
    for node in g_uiState.layoutArena.nodes:
      if int32(node.parent) == int32(comboRow):
        inc rowChildren
      if node.itemId == comboId:
        comboNode = node.id
      if node.itemId == previewId:
        previewNode = node.id

    check rowChildren == 1
    check not comboNode.isNull
    check not previewNode.isNull
    check g_uiState.layoutArena.nodes[previewNode.int].placement.kind == lpkFollow
    check g_uiState.layoutArena.nodes[previewNode.int].placement.followKind ==
      lfkInsetFixed
    check int32(g_uiState.layoutArena.nodes[previewNode.int].placement.target) ==
      int32(comboNode)

  test "auto-layout int property editor registers one row child":
    resetUi()
    var params = DefaultAutoLayoutParams
    params.itemsPerRow = 1
    params.rowWidth = 120
    params.leftPad = 0
    params.rightPad = 0
    params.rowPad = 0
    params.sectionPad = 0
    params.defaultRowHeight = 20
    params.defaultItemHeight = 20
    initAutoLayout(params)
    beginFrameLayout()

    let propertyId: ItemId = 34
    let
      labelId = hashId($propertyId & ":label")
      decId = hashId($propertyId & ":dec")
      textId = hashId($propertyId & ":text")
      incId = hashId($propertyId & ":inc")
    var value = 5
    autoLayoutPre()
    let propertyRow = g_uiState.autoLayoutState.autoRow
    discard intProperty(
      propertyId,
      g_uiState.autoLayoutState.x,
      autoLayoutNextY(),
      autoLayoutNextItemWidth(),
      autoLayoutNextItemHeight(),
      "Count",
      0,
      10,
      1,
      value,
    )
    autoLayoutPost()
    finishFrameLayout()

    var rowChildren = 0
    var propertyNode = NullLayoutNodeId
    var labelNode = NullLayoutNodeId
    var decNode = NullLayoutNodeId
    var textNode = NullLayoutNodeId
    var incNode = NullLayoutNodeId
    for node in g_uiState.layoutArena.nodes:
      if int32(node.parent) == int32(propertyRow):
        inc rowChildren
      if node.itemId == propertyId:
        propertyNode = node.id
      elif node.itemId == labelId:
        labelNode = node.id
      elif node.itemId == decId:
        decNode = node.id
      elif node.itemId == textId:
        textNode = node.id
      elif node.itemId == incId:
        incNode = node.id

    check rowChildren == 1
    check not propertyNode.isNull
    check not labelNode.isNull
    check not decNode.isNull
    check not textNode.isNull
    check not incNode.isNull
    check g_uiState.layoutArena.nodes[propertyNode.int].kind == lnkContainer
    check int32(g_uiState.layoutArena.nodes[labelNode.int].parent) == int32(
      propertyNode
    )
    check int32(g_uiState.layoutArena.nodes[decNode.int].parent) == int32(propertyNode)
    check int32(g_uiState.layoutArena.nodes[textNode.int].parent) == int32(propertyNode)
    check int32(g_uiState.layoutArena.nodes[incNode.int].parent) == int32(propertyNode)
    check g_uiState.layoutArena.nodes[textNode.int].width.kind == lskGrow
    check g_uiState.layoutArena.nodes[labelNode.int].width.kind == lskFixed
    check g_uiState.layoutArena.nodes[decNode.int].width.kind == lskFixed
    check g_uiState.layoutArena.nodes[incNode.int].width.kind == lskFixed

  test "auto-layout float property editor registers one row child":
    resetUi()
    var params = DefaultAutoLayoutParams
    params.itemsPerRow = 1
    params.rowWidth = 120
    params.leftPad = 0
    params.rightPad = 0
    params.rowPad = 0
    params.sectionPad = 0
    params.defaultRowHeight = 20
    params.defaultItemHeight = 20
    initAutoLayout(params)
    beginFrameLayout()

    let propertyId: ItemId = 35
    var value = 0.5
    autoLayoutPre()
    let propertyRow = g_uiState.autoLayoutState.autoRow
    discard floatProperty(
      propertyId,
      g_uiState.autoLayoutState.x,
      autoLayoutNextY(),
      autoLayoutNextItemWidth(),
      autoLayoutNextItemHeight(),
      "Scale",
      0.0,
      1.0,
      0.1,
      value,
    )
    autoLayoutPost()
    finishFrameLayout()

    var rowChildren = 0
    var propertyNode = NullLayoutNodeId
    var textNode = NullLayoutNodeId
    for node in g_uiState.layoutArena.nodes:
      if int32(node.parent) == int32(propertyRow):
        inc rowChildren
      if node.itemId == propertyId:
        propertyNode = node.id
      elif node.itemId == hashId($propertyId & ":text"):
        textNode = node.id

    check rowChildren == 1
    check not propertyNode.isNull
    check not textNode.isNull
    check int32(g_uiState.layoutArena.nodes[textNode.int].parent) == int32(propertyNode)
    check g_uiState.layoutArena.nodes[textNode.int].width.kind == lskGrow

  test "property editor buttons hit test against previous child rects":
    resetUi()
    let
      propertyId: ItemId = 36
      incId = hashId($propertyId & ":inc")
    var value = 5
    g_uiState.layoutRects[incId] = rect(40, 40, 20, 10)
    g_uiState.mx = 45
    g_uiState.my = 45
    g_uiState.mbLeftDown = true

    discard intProperty(propertyId, 0, 0, 100, 20, "Count", 0, 10, 1, value)

    check isHot(incId)
    check isActive(incId)

  test "horizontal slider hit testing uses a previous solved rect":
    resetUi()
    var value = 0.0
    g_uiState.layoutRects[32] = rect(40, 40, 20, 10)
    g_uiState.mx = 45
    g_uiState.my = 45
    g_uiState.mbLeftDown = true

    horizSlider(32, 0, 0, 10, 10, 0, 100, value)

    check isHot(32)
    check isActive(32)
    check g_drawLayers.layers[ord(layerDefault)].len == 1

  test "vertical slider hover testing uses a previous solved rect":
    resetUi()
    var value = 0.0
    g_uiState.layoutRects[33] = rect(40, 40, 10, 20)
    g_uiState.mx = 45
    g_uiState.my = 45

    vertSlider(33, 0, 0, 10, 10, 0, 100, value)

    check isHot(33)
    check not isActive(33)
    check g_drawLayers.layers[ord(layerDefault)].len == 1

  test "horizontal scrollbar hit testing uses a previous solved rect":
    resetUi()
    var value = 0.0
    g_uiState.layoutRects[34] = rect(40, 40, 40, 10)
    g_uiState.mx = 45
    g_uiState.my = 45
    g_uiState.mbLeftDown = true

    horizScrollBar(34, 0, 0, 20, 10, 0, 100, value)

    check isHot(34)
    check isActive(34)
    check g_drawLayers.layers[ord(layerDefault)].len == 1

  test "vertical scrollbar hit testing uses a previous solved rect":
    resetUi()
    var value = 0.0
    g_uiState.layoutRects[35] = rect(40, 40, 10, 40)
    g_uiState.mx = 45
    g_uiState.my = 45
    g_uiState.mbLeftDown = true

    vertScrollBar(35, 0, 0, 10, 20, 0, 100, value)

    check isHot(35)
    check isActive(35)
    check g_drawLayers.layers[ord(layerDefault)].len == 1

  test "scrollbar allowFocusCaptured uses previous solved rect":
    resetUi()
    var value = 0.0
    g_uiState.layoutRects[36] = rect(40, 40, 40, 10)
    g_uiState.focusCaptured = true
    g_uiState.mx = 45
    g_uiState.my = 45
    g_uiState.mbLeftDown = true

    horizScrollBar(36, 0, 0, 20, 10, 0, 100, value, allowFocusCaptured = true)

    check isHot(36)
    check isActive(36)

  test "auto-layout drag controls register under active rows":
    resetUi()
    var params = DefaultAutoLayoutParams
    params.itemsPerRow = 1
    params.rowWidth = 20
    params.leftPad = 0
    params.rightPad = 0
    params.rowPad = 0
    params.sectionPad = 0
    params.defaultRowHeight = 10
    params.defaultItemHeight = 10
    initAutoLayout(params)
    beginFrameLayout()

    var sliderValue = 0.0
    autoLayoutPre()
    let sliderRow = g_uiState.autoLayoutState.autoRow
    horizSlider(
      37,
      g_uiState.autoLayoutState.x,
      autoLayoutNextY(),
      autoLayoutNextItemWidth(),
      autoLayoutNextItemHeight(),
      0,
      100,
      sliderValue,
    )
    autoLayoutPost()

    var scrollValue = 0.0
    autoLayoutPre()
    let scrollRow = g_uiState.autoLayoutState.autoRow
    horizScrollBar(
      38,
      g_uiState.autoLayoutState.x,
      autoLayoutNextY(),
      autoLayoutNextItemWidth(),
      autoLayoutNextItemHeight(),
      0,
      100,
      scrollValue,
    )
    autoLayoutPost()

    check int32(g_uiState.layoutArena.nodes[3].parent) == int32(sliderRow)
    check int32(g_uiState.layoutArena.nodes[5].parent) == int32(scrollRow)

  test "horizontal slider edit field follows solved slider rect":
    resetUi()
    var params = DefaultAutoLayoutParams
    params.itemsPerRow = 1
    params.rowWidth = 80
    params.leftPad = 0
    params.rightPad = 0
    params.rowPad = 0
    params.sectionPad = 0
    params.defaultRowHeight = 20
    params.defaultItemHeight = 20
    initAutoLayout(params)
    beginFrameLayout()

    let sliderId: ItemId = 88
    let fieldId = hashId($sliderId & ":textField")
    var value = 12.0
    g_uiState.sliderState.editModeItem = sliderId
    g_uiState.sliderState.textFieldId = fieldId
    g_uiState.sliderState.valueText = "12"
    g_uiState.sliderState.state = ssDefault

    autoLayoutPre()
    let sliderRow = g_uiState.autoLayoutState.autoRow
    horizSlider(
      sliderId,
      g_uiState.autoLayoutState.x,
      autoLayoutNextY(),
      autoLayoutNextItemWidth(),
      autoLayoutNextItemHeight(),
      0,
      100,
      value,
    )
    autoLayoutPost()
    finishFrameLayout()

    var rowChildren = 0
    var fieldNode = NullLayoutNodeId
    for node in g_uiState.layoutArena.nodes:
      if int32(node.parent) == int32(sliderRow):
        inc rowChildren
      if node.itemId == fieldId:
        fieldNode = node.id

    check rowChildren == 1
    check not fieldNode.isNull
    check g_uiState.layoutArena.nodes[fieldNode.int].placement.kind == lpkFollow
    check g_uiState.layoutArena.nodes[fieldNode.int].placement.followKind ==
      lfkMatchTarget
    checkRect(g_uiState.layoutRects[fieldId], g_uiState.layoutRects[sliderId])

  test "text field hover testing uses a previous solved rect":
    resetUi()
    var text = ""
    g_uiState.layoutRects[39] = rect(40, 40, 20, 10)
    g_uiState.mx = 45
    g_uiState.my = 45

    textField(39, 0, 0, 10, 10, text)

    check isHot(39)
    check g_uiState.layoutArena.nodes.len == 1
    check g_drawLayers.layers[ord(layerDefault)].len == 1

  test "text field pre-pass exits edit mode on outside press":
    resetUi()
    let id: ItemId = 390
    g_uiState.layoutRects[id] = rect(40, 40, 20, 10)
    g_uiState.textFieldState.activeItem = id
    g_uiState.textFieldState.state = tfsEdit
    g_uiState.focusCaptured = true
    g_uiState.mx = 10
    g_uiState.my = 10
    g_uiState.mbLeftDown = true

    textFieldPre()

    check g_uiState.textFieldState.activeItem == 0
    check not g_uiState.focusCaptured

  test "text area hover testing uses a previous solved rect":
    resetUi()
    var text = ""
    g_uiState.layoutRects[40] = rect(40, 40, 30, 20)
    g_uiState.mx = 45
    g_uiState.my = 45

    textArea(40, 0, 0, 10, 10, text)

    check isHot(40)
    check g_uiState.layoutArena.nodes.len == 1
    check g_drawLayers.layers[ord(layerDefault)].len == 1

  test "auto-layout text inputs register under active rows":
    resetUi()
    var params = DefaultAutoLayoutParams
    params.itemsPerRow = 1
    params.rowWidth = 20
    params.leftPad = 0
    params.rightPad = 0
    params.rowPad = 0
    params.sectionPad = 0
    params.defaultRowHeight = 10
    params.defaultItemHeight = 10
    initAutoLayout(params)
    beginFrameLayout()

    var fieldText = ""
    autoLayoutPre()
    let fieldRow = g_uiState.autoLayoutState.autoRow
    textField(
      41,
      g_uiState.autoLayoutState.x,
      autoLayoutNextY(),
      autoLayoutNextItemWidth(),
      autoLayoutNextItemHeight(),
      fieldText,
    )
    autoLayoutPost()

    var areaText = ""
    autoLayoutPre()
    let areaRow = g_uiState.autoLayoutState.autoRow
    textArea(
      42,
      g_uiState.autoLayoutState.x,
      autoLayoutNextY(),
      autoLayoutNextItemWidth(),
      autoLayoutNextItemHeight(),
      areaText,
    )
    autoLayoutPost()

    check int32(g_uiState.layoutArena.nodes[3].parent) == int32(fieldRow)
    check int32(g_uiState.layoutArena.nodes[5].parent) == int32(areaRow)

  test "overflowing auto-layout text area scrollbar follows solved text area rect":
    resetUi()
    var params = DefaultAutoLayoutParams
    params.itemsPerRow = 1
    params.rowWidth = 80
    params.leftPad = 0
    params.rightPad = 0
    params.rowPad = 0
    params.sectionPad = 0
    params.defaultRowHeight = 20
    params.defaultItemHeight = 20
    initAutoLayout(params)
    beginFrameLayout()

    let areaId: ItemId = 50
    let scrollBarId = hashId($areaId & ":scrollBar")
    var areaText = "one two three four five six seven eight nine ten"
    let style = borrowDefaultTextAreaStyle()
    autoLayoutPre()
    let areaRow = g_uiState.autoLayoutState.autoRow
    textArea(
      areaId,
      g_uiState.autoLayoutState.x,
      autoLayoutNextY(),
      autoLayoutNextItemWidth(),
      autoLayoutNextItemHeight(),
      areaText,
      style = style,
    )
    autoLayoutPost()
    finishFrameLayout()

    var rowChildren = 0
    var areaNode = NullLayoutNodeId
    var scrollBarNode = NullLayoutNodeId
    for node in g_uiState.layoutArena.nodes:
      if int32(node.parent) == int32(areaRow):
        inc rowChildren
      if node.itemId == areaId:
        areaNode = node.id
      if node.itemId == scrollBarId:
        scrollBarNode = node.id

    check rowChildren == 1
    check not areaNode.isNull
    check not scrollBarNode.isNull
    check g_uiState.layoutArena.nodes[scrollBarNode.int].placement.kind == lpkFollow
    check g_uiState.layoutArena.nodes[scrollBarNode.int].placement.followKind ==
      lfkVerticalScrollBar
    check int32(g_uiState.layoutArena.nodes[scrollBarNode.int].placement.target) ==
      int32(areaNode)

    let
      areaRect = g_uiState.layoutRects[areaId]
      scrollBarRect = g_uiState.layoutRects[scrollBarId]
    check scrollBarRect.x == areaRect.x + areaRect.w - scrollBarRect.w
    check scrollBarRect.y == areaRect.y + style.textPadVert
    check scrollBarRect.h == areaRect.h - style.textPadVert * 2

  test "view hit clipping uses a previous solved rect":
    resetUi()
    g_uiState.layoutRects[43] = rect(40, 40, 20, 10)

    beginView(43, 0, 0, 10, 10)

    checkRect(g_uiState.hitClipRect, rect(40, 40, 20, 10))
    check g_uiState.layoutArena.nodes.len == 1
    check g_drawLayers.layers[ord(layerDefault)].len == 1

    endView()
    check g_uiState.layoutArena.nodes.len == 1
    check g_drawLayers.layers[ord(layerDefault)].len == 2

  test "scroll view wheel hit testing uses a previous solved rect":
    resetUi()
    g_uiState.layoutRects[44] = rect(40, 40, 20, 10)
    g_uiState.mx = 45
    g_uiState.my = 45
    g_uiState.hasEvent = true
    g_uiState.currEvent = Event(kind: ekScroll, ox: 0, oy: -1, mods: {})

    beginScrollView(44, 0, 0, 10, 10)
    endScrollView(100)

    check eventHandled()
    check scrollViewStartY(44) > 0
    check g_uiState.layoutArena.nodes.len == 2

  test "scroll view restore does not register another layout node":
    resetUi()

    beginScrollView(49, 0, 0, 50, 30)
    check g_uiState.layoutArena.nodes.len == 1
    check g_drawLayers.layers[ord(layerDefault)].len == 1

    endScrollView(20)

    check g_uiState.layoutArena.nodes.len == 1
    check g_drawLayers.layers[ord(layerDefault)].len == 2

  test "view scopes child layout nodes":
    resetUi()
    beginFrameLayout()

    beginView(80, 10, 20, 100, 50)
    let viewNode = g_uiState.layoutArena.nodes.high
    let (childX, childY) = addDrawOffset(15, 20)
    let childSlot = layoutSlot(81, rect(childX, childY, 30, 10))
    endView()
    finishFrameLayout()

    check int32(g_uiState.layoutArena.nodes[childSlot.nodeId.int].parent) ==
      int32(g_uiState.layoutArena.nodes[viewNode].id)
    checkRect(g_uiState.layoutRects[81], rect(25, 40, 30, 10))
    checkRect(
      rect(
        0,
        0,
        g_uiState.layoutArena.nodes[viewNode].contentSize.w,
        g_uiState.layoutArena.nodes[viewNode].contentSize.h,
      ),
      rect(0, 0, 45, 30),
    )

  test "scroll view scopes content without parenting scrollbars":
    resetUi()
    beginFrameLayout()

    beginScrollView(82, 10, 10, 50, 30)
    let scrollNode = g_uiState.layoutArena.nodes.high
    let (childX, childY) = addDrawOffset(0, 50)
    let childSlot = layoutSlot(83, rect(childX, childY, 20, 10))
    endScrollView(100)
    finishFrameLayout()

    var scrollChildren = 0
    for node in g_uiState.layoutArena.nodes:
      if int32(node.parent) == int32(g_uiState.layoutArena.nodes[scrollNode].id):
        inc scrollChildren

    check int32(g_uiState.layoutArena.nodes[childSlot.nodeId.int].parent) ==
      int32(g_uiState.layoutArena.nodes[scrollNode].id)
    check scrollChildren == 1
    check g_uiState.layoutArena.nodes[scrollNode].contentSize.h == 60

  test "scroll view contains auto-layout roots declared inside it":
    resetUi()
    beginFrameLayout()

    beginScrollView(84, 10, 10, 100, 80)
    let scrollNode = g_uiState.layoutArena.nodes.high

    var params = DefaultAutoLayoutParams
    params.itemsPerRow = 1
    params.rowWidth = 80
    params.leftPad = 0
    params.rightPad = 0
    params.rowPad = 0
    params.sectionPad = 0
    params.defaultRowHeight = 20
    params.defaultItemHeight = 10
    initAutoLayout(params)

    autoLayoutPre()
    let childSlot = layoutSlot(85, autoLayoutNextBounds())
    autoLayoutPost()
    endScrollView()
    finishFrameLayout()

    let rowNode = g_uiState.layoutArena.nodes[childSlot.nodeId.int].parent
    let autoRoot = g_uiState.layoutArena.nodes[rowNode.int].parent
    check int32(g_uiState.layoutArena.nodes[autoRoot.int].parent) ==
      int32(g_uiState.layoutArena.nodes[scrollNode].id)

  test "scroll view vertical scrollbar follows solved viewport rect":
    resetUi()
    var params = DefaultAutoLayoutParams
    params.itemsPerRow = 1
    params.rowWidth = 120
    params.leftPad = 0
    params.rightPad = 0
    params.rowPad = 0
    params.sectionPad = 0
    params.defaultRowHeight = 30
    params.defaultItemHeight = 30
    initAutoLayout(params)
    beginFrameLayout()

    beginRowLayout(30, [colDynamic()])
    autoLayoutPre()
    beginScrollView(
      86,
      autoLayoutNextX(),
      autoLayoutNextY(),
      autoLayoutNextItemWidth(),
      autoLayoutNextItemHeight(),
    )
    endScrollView(100)
    autoLayoutPost()
    endLayout()
    finishFrameLayout()

    var viewport = rect(0, 0, 0, 0)
    var scrollbar = rect(0, 0, 0, 0)
    for node in g_uiState.layoutArena.nodes:
      if node.itemId == 86:
        viewport = node.rect
      elif node.placement.kind == lpkFollow and
          node.placement.followKind == lfkVerticalScrollBar:
        scrollbar = node.rect

    checkRect(
      scrollbar,
      rect(viewport.x + viewport.w - scrollbar.w, viewport.y, scrollbar.w, viewport.h),
    )

  test "scroll view horizontal scrollbar follows solved viewport rect":
    resetUi()
    var params = DefaultAutoLayoutParams
    params.itemsPerRow = 1
    params.rowWidth = 120
    params.leftPad = 0
    params.rightPad = 0
    params.rowPad = 0
    params.sectionPad = 0
    params.defaultRowHeight = 30
    params.defaultItemHeight = 30
    initAutoLayout(params)
    beginFrameLayout()

    beginRowLayout(30, [colDynamic()])
    autoLayoutPre()
    beginScrollView(
      87,
      autoLayoutNextX(),
      autoLayoutNextY(),
      autoLayoutNextItemWidth(),
      autoLayoutNextItemHeight(),
    )
    endScrollView(200, 20)
    autoLayoutPost()
    endLayout()
    finishFrameLayout()

    var viewport = rect(0, 0, 0, 0)
    var scrollbar = rect(0, 0, 0, 0)
    for node in g_uiState.layoutArena.nodes:
      if node.itemId == 87:
        viewport = node.rect
      elif node.placement.kind == lpkFollow and
          node.placement.followKind == lfkHorizontalScrollBar:
        scrollbar = node.rect

    checkRect(
      scrollbar,
      rect(viewport.x, viewport.y + viewport.h - scrollbar.h, viewport.w, scrollbar.h),
    )

  test "followed scrollbars still hit test against previous rects":
    resetUi()
    beginFrameLayout()

    let id = generateId("scrollbar-follow-test.nim", 1, "scroll")
    let sbId = hashId(lastIdString() & ":scrollBar")
    g_uiState.layoutRects[id] = rect(0, 0, 50, 30)
    g_uiState.layoutRects[sbId] = rect(40, 0, 10, 30)
    g_uiState.mx = 45
    g_uiState.my = 5
    g_uiState.mbLeftDown = true

    beginScrollView(id, 0, 0, 50, 30)
    endScrollView(100)

    check isActive(sbId)

  test "auto-layout views register under active rows":
    resetUi()
    var params = DefaultAutoLayoutParams
    params.itemsPerRow = 1
    params.rowWidth = 20
    params.leftPad = 0
    params.rightPad = 0
    params.rowPad = 0
    params.sectionPad = 0
    params.defaultRowHeight = 10
    params.defaultItemHeight = 10
    initAutoLayout(params)
    beginFrameLayout()

    autoLayoutPre()
    let viewRow = g_uiState.autoLayoutState.autoRow
    beginView(
      45,
      g_uiState.autoLayoutState.x,
      autoLayoutNextY(),
      autoLayoutNextItemWidth(),
      autoLayoutNextItemHeight(),
    )
    endView()
    autoLayoutPost()

    autoLayoutPre()
    let scrollRow = g_uiState.autoLayoutState.autoRow
    beginScrollView(
      46,
      g_uiState.autoLayoutState.x,
      autoLayoutNextY(),
      autoLayoutNextItemWidth(),
      autoLayoutNextItemHeight(),
    )
    endScrollView(10)
    autoLayoutPost()

    var viewParent = NullLayoutNodeId
    var scrollParent = NullLayoutNodeId
    for node in g_uiState.layoutArena.nodes:
      if node.itemId == 45:
        viewParent = node.parent
      elif node.itemId == 46:
        scrollParent = node.parent

    check int32(viewParent) == int32(viewRow)
    check int32(scrollParent) == int32(scrollRow)

  test "dropdown button hover testing uses a previous solved rect":
    resetUi()
    type Choice = enum
      choiceA
      choiceB

    var selected = choiceA
    g_uiState.layoutRects[47] = rect(40, 40, 20, 10)
    g_uiState.mx = 45
    g_uiState.my = 45

    dropDown(47, 0, 0, 10, 10, @["A", "B"], selected, "", disabled = false)

    check isHot(47)
    check g_uiState.layoutArena.nodes.len == 1
    check g_drawLayers.layers[ord(layerDefault)].len == 1

  test "auto-layout dropdown registers under active rows":
    resetUi()
    type Choice = enum
      choiceA
      choiceB

    var params = DefaultAutoLayoutParams
    params.itemsPerRow = 1
    params.rowWidth = 20
    params.leftPad = 0
    params.rightPad = 0
    params.rowPad = 0
    params.sectionPad = 0
    params.defaultRowHeight = 10
    params.defaultItemHeight = 10
    initAutoLayout(params)
    beginFrameLayout()

    var selected = choiceA
    autoLayoutPre()
    let dropdownRow = g_uiState.autoLayoutState.autoRow
    dropDown(
      48,
      g_uiState.autoLayoutState.x,
      autoLayoutNextY(),
      autoLayoutNextItemWidth(),
      autoLayoutNextItemHeight(),
      @["A", "B"],
      selected,
      "",
      disabled = false,
    )
    autoLayoutPost()

    check int32(g_uiState.layoutArena.nodes[3].parent) == int32(dropdownRow)

  test "open auto-layout dropdown overlay follows solved button rect":
    resetUi()
    type Choice = enum
      choiceA
      choiceB
      choiceC
      choiceD
      choiceE
      choiceF
      choiceG
      choiceH
      choiceI
      choiceJ
      choiceK
      choiceL

    var params = DefaultAutoLayoutParams
    params.itemsPerRow = 1
    params.rowWidth = 40
    params.leftPad = 10
    params.rightPad = 0
    params.rowPad = 0
    params.sectionPad = 0
    params.defaultRowHeight = 10
    params.defaultItemHeight = 10
    initAutoLayout(params)

    let dropdownId: ItemId = 49
    let popupListId = hashId($dropdownId & ":popupList")
    let scrollBarId = hashId($dropdownId & ":scrollBar")
    g_uiState.itemState[dropdownId] =
      DropDownStateVars(state: dsOpen, activeItem: dropdownId, keyboardItem: 0)
    openPopup(dropdownId)
    beginFrameLayout()

    var selected = choiceA
    autoLayoutPre()
    let dropdownRow = g_uiState.autoLayoutState.autoRow
    dropDown(
      dropdownId,
      g_uiState.autoLayoutState.x,
      autoLayoutNextY(),
      autoLayoutNextItemWidth(),
      autoLayoutNextItemHeight(),
      @["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L"],
      selected,
      "",
      disabled = false,
    )
    autoLayoutPost()
    finishFrameLayout()

    var rowChildren = 0
    var popupNode = NullLayoutNodeId
    var scrollbarNode = NullLayoutNodeId
    for node in g_uiState.layoutArena.nodes:
      if int32(node.parent) == int32(dropdownRow):
        inc rowChildren
      if node.itemId == popupListId:
        popupNode = node.id
      if node.itemId == scrollBarId:
        scrollbarNode = node.id

    check rowChildren == 1
    check not popupNode.isNull
    check not scrollbarNode.isNull
    check g_uiState.layoutArena.nodes[popupNode.int].placement.kind == lpkFollow
    check g_uiState.layoutArena.nodes[popupNode.int].placement.followKind ==
      lfkDropdownPopup
    check g_uiState.layoutArena.nodes[scrollbarNode.int].placement.kind == lpkFollow
    check g_uiState.layoutArena.nodes[scrollbarNode.int].placement.followKind ==
      lfkVerticalScrollBar
    check int32(g_uiState.layoutArena.nodes[scrollbarNode.int].placement.target) ==
      int32(popupNode)

    let
      buttonRect = g_uiState.layoutRects[dropdownId]
      popupRect = g_uiState.layoutRects[popupListId]
      scrollbarRect = g_uiState.layoutRects[scrollBarId]
    check popupRect.x == buttonRect.x
    check popupRect.y == buttonRect.y + buttonRect.h
    check scrollbarRect.x == popupRect.x + popupRect.w - scrollbarRect.w
    check scrollbarRect.y == popupRect.y
    check scrollbarRect.h == popupRect.h

  test "auto-layout label registers a fit-height text node under the active row":
    resetUi()
    var params = DefaultAutoLayoutParams
    params.itemsPerRow = 1
    params.rowWidth = 40
    params.leftPad = 0
    params.rightPad = 0
    params.defaultRowHeight = 12
    params.defaultItemHeight = 12
    initAutoLayout(params)
    beginFrameLayout()

    label("Auto text")

    check g_uiState.layoutArena.nodes.len == 5
    let node = g_uiState.layoutArena.nodes[3]
    let row = node.parent
    check not row.isNull
    check g_uiState.layoutArena.nodes[row.int].direction == ldLeftToRight
    check node.kind == lnkText
    check node.text == "Auto text"
    check node.height.kind == lskFit

  test "auto-layout button and progress register under active rows":
    resetUi()
    var params = DefaultAutoLayoutParams
    params.itemsPerRow = 1
    params.rowWidth = 20
    params.leftPad = 0
    params.rightPad = 0
    params.rowPad = 0
    params.sectionPad = 0
    params.defaultRowHeight = 10
    params.defaultItemHeight = 10
    initAutoLayout(params)
    beginFrameLayout()

    g_uiState.layoutRects[24] = rect(40, 40, 20, 20)
    g_uiState.mx = 45
    g_uiState.my = 45
    g_uiState.mbLeftDown = true

    autoLayoutPre()
    let buttonRow = g_uiState.autoLayoutState.autoRow
    discard button(
      24,
      g_uiState.autoLayoutState.x,
      autoLayoutNextY(),
      autoLayoutNextItemWidth(),
      autoLayoutNextItemHeight(),
      "Button",
      "",
      disabled = false,
    )
    autoLayoutPost()

    autoLayoutPre()
    let progressRow = g_uiState.autoLayoutState.autoRow
    progress(
      25,
      g_uiState.autoLayoutState.x,
      autoLayoutNextY(),
      autoLayoutNextItemWidth(),
      autoLayoutNextItemHeight(),
      1,
      2,
      tooltip = "Value",
    )
    autoLayoutPost()

    check isHot(24)
    check isActive(24)
    check int32(g_uiState.layoutArena.nodes[3].parent) == int32(buttonRow)
    check int32(g_uiState.layoutArena.nodes[5].parent) == int32(progressRow)

suite "simple widget behavior":
  test "disabled widgets do not become active":
    resetUi()
    g_uiState.mbLeftDown = true

    captureSimpleWidget(10, disabled = true)

    check isHot(10)
    check not isActive(10)

  test "enabled widgets capture active on press":
    resetUi()
    g_uiState.mbLeftDown = true

    captureSimpleWidget(10, disabled = false)

    check isHot(10)
    check isActive(10)

  test "click fires only on release while hot and active":
    check simpleWidgetClicked(10, mbLeftDown = true, hot = true, active = true) == false
    check simpleWidgetClicked(10, mbLeftDown = false, hot = false, active = true) ==
      false
    check simpleWidgetClicked(10, mbLeftDown = false, hot = true, active = false) ==
      false
    check simpleWidgetClicked(10, mbLeftDown = false, hot = true, active = true)

  test "plain widget states cover normal hover down and disabled":
    check simpleWidgetState(false, false, false, true) == wsNormal
    check simpleWidgetState(false, true, false, true) == wsHover
    check simpleWidgetState(false, true, true, false) == wsDown
    check simpleWidgetState(false, true, false, false) == wsNormal
    check simpleWidgetState(true, true, false, true) == wsDisabled

  test "selectable toggles on release while hot and active":
    resetUi()
    var selected = false

    g_uiState.mx = 5
    g_uiState.my = 5
    g_uiState.mbLeftDown = true
    check not selectable(10, 0, 0, 20, 20, "Item", selected)
    check not selected
    check isActive(10)

    g_uiState.hotItem = 0
    g_uiState.mbLeftDown = false
    check selectable(10, 0, 0, 20, 20, "Item", selected)
    check selected

  test "disabled selectable does not toggle":
    resetUi()
    var selected = false

    g_uiState.mx = 5
    g_uiState.my = 5
    g_uiState.mbLeftDown = true
    check not selectable(10, 0, 0, 20, 20, "Item", selected, disabled = true)

    g_uiState.hotItem = 0
    g_uiState.mbLeftDown = false
    check not selectable(10, 0, 0, 20, 20, "Item", selected, disabled = true)
    check not selected

  test "selectable states preserve active and down behavior":
    check simpleWidgetState(false, false, false, true, selected = true) == wsActive
    check simpleWidgetState(false, true, false, true, selected = true) == wsActiveHover
    check simpleWidgetState(false, true, true, false, selected = true) == wsDown
    check simpleWidgetState(true, true, false, true, selected = true) == wsDisabled

  test "radio button state combines group and selected state":
    check radioButtonState(
      hot = false,
      active = false,
      canHover = true,
      selected = false,
      hotButton = -1,
      buttonIndex = 0,
    ) == wsNormal
    check radioButtonState(
      hot = false,
      active = false,
      canHover = true,
      selected = true,
      hotButton = -1,
      buttonIndex = 0,
    ) == wsActive
    check radioButtonState(
      hot = true,
      active = false,
      canHover = true,
      selected = false,
      hotButton = 0,
      buttonIndex = 0,
    ) == wsHover
    check radioButtonState(
      hot = true,
      active = false,
      canHover = true,
      selected = true,
      hotButton = 0,
      buttonIndex = 0,
    ) == wsActiveHover
    check radioButtonState(
      hot = true,
      active = true,
      canHover = false,
      selected = false,
      hotButton = 0,
      buttonIndex = 0,
    ) == wsDown
    check radioButtonState(
      hot = true,
      active = true,
      canHover = false,
      selected = true,
      hotButton = 0,
      buttonIndex = 0,
    ) == wsActiveDown
    check radioButtonState(
      hot = true,
      active = true,
      canHover = false,
      selected = false,
      hotButton = 1,
      buttonIndex = 0,
    ) == wsNormal

suite "scroll view behavior":
  test "horizontal scroll state affects the next draw offset":
    resetUi()

    beginScrollView(70, 0, 0, 50, 30)
    endScrollView(100, 20)

    scrollViewStartX(70, 25)
    beginScrollView(70, 0, 0, 50, 30)
    check drawOffset().ox == -25
    endScrollView(100, 20)

  test "auto scroll view uses previous solved content height for wheel scrolling":
    resetUi()
    beginFrameLayout()

    beginScrollView(90, 0, 0, 50, 30)
    let (firstX, firstY) = addDrawOffset(0, 80)
    discard layoutSlot(91, rect(firstX, firstY, 20, 10))
    endScrollView()
    finishFrameLayout()

    check g_uiState.layoutContentSizes[90].h == 90

    beginFrameLayout()
    g_uiState.mx = 10
    g_uiState.my = 10
    g_uiState.hasEvent = true
    g_uiState.currEvent = Event(kind: ekScroll, ox: 0, oy: -1, mods: {})

    beginScrollView(90, 0, 0, 50, 30)
    let (secondX, secondY) = addDrawOffset(0, 80)
    discard layoutSlot(91, rect(secondX, secondY, 20, 10))
    endScrollView()
    finishFrameLayout()

    check eventHandled()
    check scrollViewStartY(90) > 0
    check g_uiState.layoutContentSizes[90].h == 90

  test "explicit scroll content dimensions override smaller solved content":
    resetUi()
    beginFrameLayout()
    g_uiState.layoutRects[92] = rect(0, 0, 50, 30)
    g_uiState.mx = 10
    g_uiState.my = 10
    g_uiState.hasEvent = true
    g_uiState.currEvent = Event(kind: ekScroll, ox: 0, oy: -1, mods: {})

    beginScrollView(92, 0, 0, 50, 30)
    let (childX, childY) = addDrawOffset(0, 0)
    discard layoutSlot(93, rect(childX, childY, 20, 10))
    endScrollView(100)
    finishFrameLayout()

    check eventHandled()
    check scrollViewStartY(92) > 0
    check g_uiState.layoutContentSizes[92].h == 10

  test "standalone list view scopes row content under its scroll container":
    resetUi()

    beginFrameLayout()
    let range = beginListView(94, 10, 15, 50, 20, 5, 10)
    let (childX, childY) = addDrawOffset(0, 0)
    let childSlot = layoutDrawSlot(95, rect(childX, childY, 40, 10))
    endListView(range)
    finishFrameLayout()

    var listNode = NullLayoutNodeId
    for node in g_uiState.layoutArena.nodes:
      if node.itemId == 94:
        listNode = node.id

    check not listNode.isNull
    check not childSlot.nodeId.isNull
    check range.contentHeight == 50
    check int32(g_uiState.layoutArena.nodes[childSlot.nodeId.int].parent) ==
      int32(listNode)
    checkRect(g_uiState.layoutRects[94], rect(10, 15, 50, 20))
    checkRect(g_uiState.layoutRects[95], rect(10, 15, 40, 10))

suite "feature widget behavior":
  test "tooltip drawing registers a draw-only layout node":
    resetUi()

    drawTooltip(20, 20, "Tip")

    check g_uiState.layoutArena.nodes.len == 1
    check g_drawLayers.layers[ord(layerTooltip)].len == 1

  test "dialog background registers a layout-backed draw node":
    resetUi()

    beginDialog(40, 30, "Dialog")

    check currentLayer() == layerDialog
    check g_uiState.layoutArena.nodes.len == 1
    check g_drawLayers.layers[ord(layerDialog)].len == 1

    endDialog()

  test "explicit dialog registers its id and scopes body children":
    resetUi()

    beginFrameLayout()
    var childSlot = LayoutSlot(nodeId: NullLayoutNodeId)
    if beginDialog(81, 10, 20, 40, 30, "Dialog"):
      childSlot = layoutDrawSlot(82, rect(12, 23, 5, 5))
      endDialog()
    finishFrameLayout()

    var dialogNode = NullLayoutNodeId
    for node in g_uiState.layoutArena.nodes:
      if node.itemId == 81:
        dialogNode = node.id

    check not dialogNode.isNull
    check not childSlot.nodeId.isNull
    check g_uiState.layoutRects.hasKey(81)
    checkRect(g_uiState.layoutRects[81], rect(10, 20, 40, 30))
    check int32(g_uiState.layoutArena.nodes[childSlot.nodeId.int].parent) ==
      int32(dialogNode)

  test "color combo opens its popup from button click":
    resetUi()
    var color = rgb(0.2, 0.4, 0.8)

    g_uiState.mx = 5
    g_uiState.my = 5
    g_uiState.mbLeftDown = true
    check not colorCombo(80, 0, 0, 60, 20, color, "Accent")
    check isActive(80)

    g_uiState.hotItem = 0
    g_uiState.mbLeftDown = false
    discard colorCombo(80, 0, 0, 60, 20, color, "Accent")
    check isPopupOpen(80)

  test "open auto-layout color combo popup does not add row content":
    resetUi()
    var params = DefaultAutoLayoutParams
    params.itemsPerRow = 1
    params.rowWidth = 60
    params.leftPad = 0
    params.rightPad = 0
    params.rowPad = 0
    params.sectionPad = 0
    params.defaultRowHeight = 20
    params.defaultItemHeight = 20
    initAutoLayout(params)

    let comboId: ItemId = 81
    let popupId = hashId($comboId & ":popup")
    openPopup(comboId)
    beginFrameLayout()

    var color = rgb(0.2, 0.4, 0.8)
    autoLayoutPre()
    let comboRow = g_uiState.autoLayoutState.autoRow
    discard colorCombo(
      comboId,
      g_uiState.autoLayoutState.x,
      autoLayoutNextY(),
      autoLayoutNextItemWidth(),
      autoLayoutNextItemHeight(),
      color,
      "Accent",
    )
    autoLayoutPost()
    finishFrameLayout()

    var rowChildren = 0
    var popupNode = NullLayoutNodeId
    for node in g_uiState.layoutArena.nodes:
      if int32(node.parent) == int32(comboRow):
        inc rowChildren
      if node.itemId == popupId:
        popupNode = node.id

    check rowChildren == 1
    check not popupNode.isNull
    check g_uiState.layoutArena.nodes[popupNode.int].placement.kind == lpkFollow
    check g_uiState.layoutArena.nodes[popupNode.int].placement.followKind ==
      lfkDropdownPopup
    check g_uiState.layoutRects.hasKey(comboId)
    check g_uiState.layoutRects.hasKey(popupId)
    check g_uiState.layoutRects[comboId] != g_uiState.layoutRects[popupId]

  test "group box content rect becomes the active draw offset":
    resetUi()

    let r = beginGroupBox(90, 10, 20, 100, 80, "Group")
    checkRect(r, rect(16, 50, 88, 44))
    check drawOffset().ox == 16
    check drawOffset().oy == 50
    check g_uiState.layoutArena.nodes.len == 2
    check g_drawLayers.layers[ord(layerDefault)].len == 2
    endGroupBox()

  test "titled scroll view registers frame and content slots":
    resetUi()

    let r = beginTitledScrollView(91, 10, 20, 100, 80, "Group")
    checkRect(r, rect(16, 50, 88, 44))
    check g_uiState.layoutArena.nodes.len == 2
    check g_drawLayers.layers[ord(layerDefault)].len == 2
    endTitledScrollView(20)

  test "auto-layout group box frame owns row slot and content follows":
    resetUi()
    var params = DefaultAutoLayoutParams
    params.itemsPerRow = 1
    params.rowWidth = 120
    params.leftPad = 0
    params.rightPad = 0
    params.rowPad = 0
    params.sectionPad = 0
    params.defaultRowHeight = 80
    params.defaultItemHeight = 80
    initAutoLayout(params)
    beginFrameLayout()

    let
      groupId: ItemId = 92
      frameId = hashId($groupId & ":frame")
      style = borrowDefaultGroupBoxStyle()
    autoLayoutPre()
    let groupRow = g_uiState.autoLayoutState.autoRow
    discard beginGroupBox(
      groupId,
      g_uiState.autoLayoutState.x,
      autoLayoutNextY(),
      autoLayoutNextItemWidth(),
      autoLayoutNextItemHeight(),
      "Group",
      style,
    )
    endGroupBox()
    autoLayoutPost()
    finishFrameLayout()

    var rowChildren = 0
    var frameNode = NullLayoutNodeId
    var contentNode = NullLayoutNodeId
    for node in g_uiState.layoutArena.nodes:
      if int32(node.parent) == int32(groupRow):
        inc rowChildren
      if node.itemId == frameId:
        frameNode = node.id
      elif node.itemId == groupId:
        contentNode = node.id

    check rowChildren == 1
    check not frameNode.isNull
    check not contentNode.isNull
    check int32(g_uiState.layoutArena.nodes[frameNode.int].parent) == int32(groupRow)
    check g_uiState.layoutArena.nodes[contentNode.int].placement.kind == lpkFollow
    check g_uiState.layoutArena.nodes[contentNode.int].placement.followKind ==
      lfkMatchTarget
    check int32(g_uiState.layoutArena.nodes[contentNode.int].placement.target) ==
      int32(frameNode)

    let
      frameRect = g_uiState.layoutRects[frameId]
      contentRect = g_uiState.layoutRects[groupId]
    checkRect(
      contentRect,
      rect(
        frameRect.x + style.pad,
        frameRect.y + style.titleHeight + style.pad,
        max(0.0, frameRect.w - style.pad * 2),
        max(0.0, frameRect.h - style.titleHeight - style.pad * 2),
      ),
    )

  test "auto-layout titled scroll view frame owns row slot and viewport follows":
    resetUi()
    var params = DefaultAutoLayoutParams
    params.itemsPerRow = 1
    params.rowWidth = 120
    params.leftPad = 0
    params.rightPad = 0
    params.rowPad = 0
    params.sectionPad = 0
    params.defaultRowHeight = 80
    params.defaultItemHeight = 80
    initAutoLayout(params)
    beginFrameLayout()

    let
      scrollId: ItemId = 93
      frameId = hashId($scrollId & ":frame")
      style = borrowDefaultGroupBoxStyle()
    autoLayoutPre()
    let scrollRow = g_uiState.autoLayoutState.autoRow
    discard beginTitledScrollView(
      scrollId,
      g_uiState.autoLayoutState.x,
      autoLayoutNextY(),
      autoLayoutNextItemWidth(),
      autoLayoutNextItemHeight(),
      "Group",
      style,
    )
    endTitledScrollView(20)
    autoLayoutPost()
    finishFrameLayout()

    var rowChildren = 0
    var frameNode = NullLayoutNodeId
    var viewportNode = NullLayoutNodeId
    for node in g_uiState.layoutArena.nodes:
      if int32(node.parent) == int32(scrollRow):
        inc rowChildren
      if node.itemId == frameId:
        frameNode = node.id
      elif node.itemId == scrollId:
        viewportNode = node.id

    check rowChildren == 1
    check not frameNode.isNull
    check not viewportNode.isNull
    check int32(g_uiState.layoutArena.nodes[frameNode.int].parent) == int32(scrollRow)
    check g_uiState.layoutArena.nodes[viewportNode.int].placement.kind == lpkFollow
    check g_uiState.layoutArena.nodes[viewportNode.int].placement.followKind ==
      lfkMatchTarget
    check int32(g_uiState.layoutArena.nodes[viewportNode.int].placement.target) ==
      int32(frameNode)

    let
      frameRect = g_uiState.layoutRects[frameId]
      viewportRect = g_uiState.layoutRects[scrollId]
    checkRect(
      viewportRect,
      rect(
        frameRect.x + style.pad,
        frameRect.y + style.titleHeight + style.pad,
        max(0.0, frameRect.w - style.pad * 2),
        max(0.0, frameRect.h - style.titleHeight - style.pad * 2),
      ),
    )

  test "table header hit testing uses a previous solved rect":
    resetUi()
    let columns =
      [TableColumn(label: "A", width: 50), TableColumn(label: "B", width: 50)]
    var
      widths: seq[float]
      sortState = TableSortState(column: -1, direction: tsdNone)

    g_uiState.layoutRects[101] = rect(40, 40, 100, 24)
    g_uiState.mx = 60
    g_uiState.my = 45
    g_uiState.mbLeftDown = true
    drawTableHeader(101, 0, 0, 10, columns, widths, sortState)

    g_uiState.hotItem = 0
    g_uiState.mbLeftDown = false
    drawTableHeader(101, 0, 0, 10, columns, widths, sortState)

    check sortState.column == 0
    check sortState.direction == tsdAsc

  test "table drawing registers layout-backed draw nodes":
    resetUi()
    let columns = [TableColumn(label: "A", width: 5), TableColumn(label: "B", width: 5)]

    drawTableHeader(0, 0, 10, columns)
    beginTableRow(0, [5.0, 5.0], 0, 10, 10)
    tableCell("A")

    check g_uiState.layoutArena.nodes.len == 3
    check g_drawLayers.layers[ord(layerDefault)].len == 3

  test "auto-layout table view registers one row child with internal body":
    resetUi()
    var params = DefaultAutoLayoutParams
    params.itemsPerRow = 1
    params.rowWidth = 160
    params.leftPad = 0
    params.rightPad = 0
    params.rowPad = 0
    params.sectionPad = 0
    params.defaultRowHeight = 70
    params.defaultItemHeight = 70
    initAutoLayout(params)
    beginFrameLayout()

    let columns =
      [TableColumn(label: "A", width: 80), TableColumn(label: "B", width: 80)]
    var
      widths: seq[float]
      sortState = TableSortState(column: -1, direction: tsdNone)
    useNextId("table-layout-test")
    let
      headerId = hashId("table-layout-test")
      tableId = hashId($headerId & ":table")
      bodyId = hashId($headerId & ":body")
      style = borrowDefaultTableStyle()

    autoLayoutPre()
    let tableRow = g_uiState.autoLayoutState.autoRow
    tableView(
      g_uiState.autoLayoutState.x,
      autoLayoutNextY(),
      autoLayoutNextItemWidth(),
      autoLayoutNextItemHeight(),
      columns,
      widths,
      sortState,
      2.Natural,
      i,
    ):
      tableCell("Row " & $i)
    autoLayoutPost()
    finishFrameLayout()

    var rowChildren = 0
    var tableNode = NullLayoutNodeId
    var headerNode = NullLayoutNodeId
    var bodyNode = NullLayoutNodeId
    var bodyDrawChildren = 0
    for node in g_uiState.layoutArena.nodes:
      if int32(node.parent) == int32(tableRow):
        inc rowChildren
      if node.itemId == tableId:
        tableNode = node.id
      elif node.itemId == headerId:
        headerNode = node.id
      elif node.itemId == bodyId:
        bodyNode = node.id

    check rowChildren == 1
    check not tableNode.isNull
    check not headerNode.isNull
    check not bodyNode.isNull
    check g_uiState.layoutArena.nodes[tableNode.int].kind == lnkContainer
    check g_uiState.layoutArena.nodes[bodyNode.int].kind == lnkContainer
    check int32(g_uiState.layoutArena.nodes[headerNode.int].parent) == int32(tableNode)
    check int32(g_uiState.layoutArena.nodes[bodyNode.int].parent) == int32(tableNode)

    for node in g_uiState.layoutArena.nodes:
      if int32(node.parent) == int32(bodyNode):
        inc bodyDrawChildren
    check bodyDrawChildren > 0

    let
      tableRect = g_uiState.layoutRects[tableId]
      headerRect = g_uiState.layoutRects[headerId]
      bodyRect = g_uiState.layoutRects[bodyId]
    checkRect(
      headerRect, rect(tableRect.x, tableRect.y, tableRect.w, style.headerHeight)
    )
    checkRect(
      bodyRect,
      rect(
        tableRect.x,
        tableRect.y + style.headerHeight,
        tableRect.w,
        max(0.0, tableRect.h - style.headerHeight),
      ),
    )

  test "manual chart drawing registers a draw-only layout node":
    resetUi()
    let series: seq[ChartSeries] = @[]

    plotChart(0, 0, 20, 10, series, 0, 1)

    check g_uiState.layoutArena.nodes.len == 1
    check g_drawLayers.layers[ord(layerDefault)].len == 1

  test "auto-layout chart registers under active rows":
    resetUi()
    var params = DefaultAutoLayoutParams
    params.itemsPerRow = 1
    params.rowWidth = 20
    params.leftPad = 0
    params.rightPad = 0
    params.rowPad = 0
    params.sectionPad = 0
    params.defaultRowHeight = 10
    params.defaultItemHeight = 10
    initAutoLayout(params)
    beginFrameLayout()

    let series: seq[ChartSeries] = @[]
    autoLayoutPre()
    let chartRow = g_uiState.autoLayoutState.autoRow
    plotChart(
      102,
      g_uiState.autoLayoutState.x,
      autoLayoutNextY(),
      autoLayoutNextItemWidth(),
      autoLayoutNextItemHeight(),
      series,
      0,
      1,
    )
    autoLayoutPost()

    check int32(g_uiState.layoutArena.nodes[3].parent) == int32(chartRow)

  test "interactive table header updates caller-owned sort state":
    resetUi()
    let columns =
      [TableColumn(label: "A", width: 50), TableColumn(label: "B", width: 50)]
    var
      widths: seq[float]
      sortState = TableSortState(column: -1, direction: tsdNone)

    g_uiState.mx = 10
    g_uiState.my = 10
    g_uiState.mbLeftDown = true
    drawTableHeader(100, 0, 0, 100, columns, widths, sortState)

    g_uiState.hotItem = 0
    g_uiState.mbLeftDown = false
    drawTableHeader(100, 0, 0, 100, columns, widths, sortState)

    check sortState.column == 0
    check sortState.direction == tsdAsc

suite "drag widget behavior":
  test "capture requires a hit":
    resetUi()
    g_uiState.mbLeftDown = true

    check not captureDragWidget(20, hit = false)
    check not isHot(20)
    check not isActive(20)

  test "capture marks hot and active when input is free":
    resetUi()
    g_uiState.mbLeftDown = true

    check captureDragWidget(20, hit = true)
    check isHot(20)
    check isActive(20)

  test "focused capture can override an existing active item":
    resetUi()
    g_uiState.mbLeftDown = true
    markActive(10)

    check not captureDragWidget(20, hit = true)
    check isHot(20)
    check isActive(10)

    check captureDragWidget(20, hit = true, allowActiveCapture = true)
    check isActive(20)

  test "drag widget states cover normal hover and down":
    check dragWidgetState(hot = false, active = false, canHover = true) == wsNormal
    check dragWidgetState(hot = true, active = false, canHover = true) == wsHover
    check dragWidgetState(hot = true, active = true, canHover = false) == wsDown
    check dragWidgetState(hot = false, active = true, canHover = false) == wsDown
    check dragWidgetState(hot = true, active = false, canHover = false) == wsNormal
