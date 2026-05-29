## Adversarial behaviour tests.
##
## Unlike the per-widget regression suites (which pin down what the code does),
## these assert what *should* be true and are written to try to break the
## widgets -- cross-widget focus handoff, disabled/guard interactions, id
## isolation, and the fiddly corners of each state machine. A failure here is a
## real bug, not a changed implementation detail.

import std/math

import widget_test_common

# NOTE: resetUi() sets the hit-clip to the TestWinW x TestWinH window, so any
# widget placed beyond TestWinW (200) gets its clicks clipped past x=200. Keep
# placed widgets inside the window in these tests.

# A full press-then-release click on a widget proc `call` (a closure that
# invokes the widget for one frame). Returns nothing; the caller inspects state.
template clickCycle(px, py: float, call: untyped) =
  pressLeftAt(px, py)
  call
  nextFrame()
  releaseLeft()
  mouseTo(px, py)
  call

suite "cross-widget focus handoff":
  test "a captured focus blocks a button elsewhere from activating":
    resetUi()
    # Simulate a text field (or any widget) holding focus this frame.
    g_uiState.focusCaptured = true
    placeRect(20, rect(40, 40, 30, 14))

    var fired = false
    clickCycle(45, 45):
      fired = button(20, 0, 0, 30, 14, "Go", "", disabled = false)

    check not fired
    check not isHot(20)

  test "a captured focus blocks a checkbox elsewhere from toggling":
    resetUi()
    g_uiState.focusCaptured = true
    placeRect(21, rect(40, 40, 14, 14))

    var checked = false
    clickCycle(45, 45):
      checkBox(21, 0, 0, 14, checked, "", disabled = false)

    check not checked

suite "disabled guards":
  test "a disabled checkbox never toggles through a full click":
    resetUi()
    placeRect(22, rect(40, 40, 14, 14))

    var checked = false
    clickCycle(45, 45):
      checkBox(22, 0, 0, 14, checked, "", disabled = true)

    check not checked

  test "a disabled button never fires through a full click":
    resetUi()
    placeRect(23, rect(40, 40, 30, 14))

    var fired = false
    clickCycle(45, 45):
      fired = button(23, 0, 0, 30, 14, "Go", "", disabled = true)

    check not fired

suite "widget id isolation":
  test "clicking one checkbox does not toggle a sibling":
    resetUi()
    placeRect(24, rect(40, 40, 14, 14)) # A
    placeRect(25, rect(40, 60, 14, 14)) # B
    var a = false
    var b = false

    proc frame() =
      checkBox(24, 0, 0, 14, a, "", disabled = false)
      checkBox(25, 0, 0, 14, b, "", disabled = false)

    clickCycle( # over A only
      45, 45
    ):
      frame()

    check a
    check not b

suite "selectable toggle cycle":
  test "two full clicks toggle a selectable on then back off":
    resetUi()
    placeRect(26, rect(40, 40, 30, 14))
    var on = false

    clickCycle(45, 45):
      discard selectable(26, 0, 0, 30, 14, "Item", on, "", disabled = false)
    check on

    nextFrame()
    clickCycle(45, 45):
      discard selectable(26, 0, 0, 30, 14, "Item", on, "", disabled = false)
    check not on

suite "radio buttons selection":
  type RB = enum
    r0
    r1
    r2
    r3
    r4

  const
    Rn = 5
    Rgw = 180.0 # fits inside the test window

  proc drawnCentre(target: int): float =
    let pad = borrowDefaultRadioButtonsStyle().buttonPadHoriz
    let bwDraw = (Rgw - pad * (Rn - 1).float) / Rn.float
    target.float * (bwDraw + pad) + bwDraw * 0.5

  test "clicking each button's visual centre selects exactly that button":
    for target in 0 ..< Rn:
      resetUi()
      placeRect(40, rect(0, 40, Rgw, 20))
      var active = @[r0]
      let cx = drawnCentre(target)

      pressLeftAt(cx, 50)
      radioButtons(40, 0, 40, Rgw, 20, @["0", "1", "2", "3", "4"], active)
      nextFrame()
      releaseLeft()
      mouseTo(cx, 50)
      radioButtons(40, 0, 40, Rgw, 20, @["0", "1", "2", "3", "4"], active)

      check active == @[RB(target)]

  test "multiselect toggles items and refuses to deselect the last one":
    resetUi()
    placeRect(41, rect(0, 40, Rgw, 20))
    var sel = @[r0]

    proc click(target: int) =
      let cx = drawnCentre(target)
      nextFrame()
      pressLeftAt(cx, 50)
      radioButtons(
        41, 0, 40, Rgw, 20, @["0", "1", "2", "3", "4"], sel, multiselect = true
      )
      nextFrame()
      releaseLeft()
      mouseTo(cx, 50)
      radioButtons(
        41, 0, 40, Rgw, 20, @["0", "1", "2", "3", "4"], sel, multiselect = true
      )

    click(2) # {0, 2}
    check r2 in sel and r0 in sel and sel.len == 2
    click(0) # {2}
    check sel == @[r2]
    click(2) # would empty the set -> must stay {2}
    check sel == @[r2]

suite "dropdown focus release":
  test "focus is released after a keyboard commit":
    type C = enum
      ca
      cb

    resetUi()
    placeRect(48, rect(40, 40, 40, 20))
    var sel = ca

    pressLeftAt(45, 45)
    dropDown(48, 40, 40, 40, 20, @["A", "B"], sel, "", disabled = false)
    check g_uiState.focusCaptured # captured while open

    releaseLeft()
    mouseTo(0, 0)
    nextFrame()
    sendKey(keyEnter)
    dropDown(48, 40, 40, 40, 20, @["A", "B"], sel, "", disabled = false)

    check not isPopupOpen(48)
    check not g_uiState.focusCaptured # released after commit

suite "popup auto-close border":
  test "a press just outside but within the border keeps the popup open":
    resetUi()
    let style = borrowDefaultPopupStyle().deepCopy
    style.autoCloseBorder = 8.0
    g_uiState.layoutRects[31] = rect(50, 50, 40, 30)

    openPopup(31)
    releaseLeft()
    check beginPopup(31, 50, 50, 40, 30, style)
    endPopup()

    # rect spans x:50..90; press at x=94 is 4px out, inside the 8px border.
    pressLeftAt(94, 65)
    check beginPopup(31, 50, 50, 40, 30, style)
    check isPopupOpen(31)
    endPopup()

  test "a press beyond the border closes the popup":
    resetUi()
    let style = borrowDefaultPopupStyle().deepCopy
    style.autoCloseBorder = 8.0
    g_uiState.layoutRects[32] = rect(50, 50, 40, 30)

    openPopup(32)
    releaseLeft()
    check beginPopup(32, 50, 50, 40, 30, style)
    endPopup()

    pressLeftAt(120, 65) # well beyond the border
    check not beginPopup(32, 50, 50, 40, 30, style)
    check not isPopupOpen(32)
