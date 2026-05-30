## Headless behaviour tests for the popup widget: open/close, focus capture and
## release, escape-to-close, outside-click auto-close, and layer scoping.

import widget_test_common

suite "popup open/close and focus":
  test "openPopup captures focus and marks active":
    resetUi()

    openPopup(30)

    check isPopupOpen(30)
    check isActive(30)
    check g_uiState.focusCaptured
    check g_uiState.popupState.state == psOpenLMBDown
    check not g_uiState.popupState.closed
    check shouldRenderNextFrame()

  test "begin/end popup switch to the popup layer and clip to its rect":
    resetUi()
    openPopup(30)
    releaseLeft()

    check beginPopup(30, 10, 10, 30, 30)
    check currentLayer() == layerPopup
    checkRect(g_uiState.hitClipRect, rect(10, 10, 30, 30))

    endPopup()
    check currentLayer() == layerDefault
    # Focus stays captured by the popup until it is actually closed.
    check g_uiState.focusCaptured

  test "first LMB release advances psOpenLMBDown to psOpen":
    resetUi()
    openPopup(30)
    check g_uiState.popupState.state == psOpenLMBDown

    releaseLeft()
    check beginPopup(30, 10, 10, 30, 30)
    check g_uiState.popupState.state == psOpen
    endPopup()

  test "closePopup releases captured focus":
    resetUi()
    openPopup(30)
    check g_uiState.focusCaptured

    closePopup()
    check not isPopupOpen(30)
    check not g_uiState.focusCaptured
    check g_uiState.popupState.closed
    check shouldRenderNextFrame()

suite "popup dismissal":
  test "escape key closes the popup and is consumed":
    resetUi()
    openPopup(30)
    sendKey(keyEscape)

    check not beginPopup(30, 10, 10, 30, 30)
    check not isPopupOpen(30)
    check eventHandled()

  test "outside click closes the popup after the first release":
    resetUi()
    openPopup(30)

    # First frame: button still held from the click that opened it.
    releaseLeft()
    check beginPopup(30, 10, 10, 30, 30)
    endPopup()

    # Next frame: a fresh press well outside the popup bounds dismisses it.
    pressLeftAt(150, 150)
    check not beginPopup(30, 10, 10, 30, 30)
    check not isPopupOpen(30)

  test "click inside the popup keeps it open":
    resetUi()
    openPopup(30)
    releaseLeft()
    check beginPopup(30, 10, 10, 30, 30)
    endPopup()

    pressLeftAt(20, 20) # inside rect(10, 10, 30, 30)
    check beginPopup(30, 10, 10, 30, 30)
    check isPopupOpen(30)
    endPopup()

  test "closing from inside the popup body releases focus":
    resetUi()
    openPopup(30)
    releaseLeft()
    check beginPopup(30, 10, 10, 30, 30)

    closePopup()
    endPopup()

    check not isPopupOpen(30)
    check not g_uiState.focusCaptured

suite "popup layout scoping":
  test "popup hit clipping reuses a previously solved rect":
    resetUi()
    g_uiState.layoutRects[31] = rect(40, 40, 20, 10)

    openPopup(31)
    releaseLeft()

    check beginPopup(31, 0, 0, 10, 10)
    checkRect(g_uiState.hitClipRect, rect(40, 40, 20, 10))
    endPopup()

  test "popup draw offset reuses a previously solved rect":
    resetUi()
    g_uiState.layoutRects[32] = rect(40, 40, 20, 10)

    openPopup(32)
    releaseLeft()

    check beginPopup(32, 0, 0, 10, 10)
    check addDrawOffset(2, 3) == (42.0, 43.0)
    endPopup()
