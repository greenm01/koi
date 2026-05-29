import std/unittest

import koi/core
import koi/input
import koi/internal/widget_behavior
import koi/types

proc resetUi() =
  g_uiState = UIState.default

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
