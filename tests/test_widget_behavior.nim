import std/unittest

import glfw

import koi/core
import koi/drawing
import koi/input
import koi/internal/widget_behavior
import koi/rect
import koi/types
import koi/widgets/menu
import koi/widgets/popup
import koi/widgets/selectable

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
