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
import koi/widgets/checkbox
import koi/widgets/colorpicker
import koi/widgets/groupbox
import koi/widgets/label
import koi/widgets/menu
import koi/widgets/popup
import koi/widgets/progress
import koi/widgets/radiobuttons
import koi/widgets/section
import koi/widgets/selectable
import koi/widgets/scrollview
import koi/widgets/table
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

suite "menu behavior":
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
      27, 3, 4, 30, 12, active, "Off", "On", "", disabled = false,
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
    check sectionHeader("Header", expanded)

    check isHot(id)
    check isActive(id)

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

suite "feature widget behavior":
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

  test "group box content rect becomes the active draw offset":
    resetUi()

    let r = beginGroupBox(90, 10, 20, 100, 80, "Group")
    checkRect(r, rect(16, 50, 88, 44))
    check drawOffset().ox == 16
    check drawOffset().oy == 50
    endGroupBox()

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
