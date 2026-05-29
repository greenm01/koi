import std/unittest

import koi/core
import koi/drawing
import koi/input
import koi/internal/widget_behavior
import koi/rect
import koi/types
import koi/widgets/selectable

proc resetUi() =
  g_uiState = UIState.default
  g_uiState.winWidth = 100
  g_uiState.winHeight = 100
  g_uiState.hitClipRect = rect(0, 0, 100, 100)
  g_uiState.drawOffsetStack = @[DrawOffset(ox: 0, oy: 0)]
  g_drawLayers.init()

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
