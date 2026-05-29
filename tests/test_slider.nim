## Headless behaviour tests for the slider widget.
##
## horizSlider's normal (non-Shift) drag computes the value directly from the
## mouse X, so it can be driven headless. The fine-drag (Shift) path and
## vertSlider both call disableCursor()/showCursor() which need a real window,
## so those paths are only exercised up to capture here.

import std/math

import widget_test_common

const
  SlId: ItemId = 60
  Sx = 20.0
  Sy = 80.0
  Sw = 100.0
  Sh = 20.0

template checkClose(actual, expected: float) =
  check abs(actual - expected) < 1e-9

proc trackBounds(): tuple[lo, hi: float] =
  let pad = borrowDefaultSliderStyle().trackPad
  (Sx + pad, Sx + Sw - pad)

suite "horizontal slider drag":
  test "pressing maps the mouse X to the value":
    resetUi()
    let (lo, hi) = trackBounds()
    var value = 0.0

    placeRect(SlId, rect(Sx, Sy, Sw, Sh))
    pressLeftAt((lo + hi) * 0.5, Sy + Sh * 0.5)
    horizSlider(SlId, Sx, Sy, Sw, Sh, 0.0, 100.0, value)

    check isActive(SlId)
    checkClose(value, 50.0)

  test "drag to the track ends hits exactly min and max":
    resetUi()
    let (lo, hi) = trackBounds()
    var value = 50.0

    placeRect(SlId, rect(Sx, Sy, Sw, Sh))
    pressLeftAt(hi, Sy + Sh * 0.5)
    horizSlider(SlId, Sx, Sy, Sw, Sh, 0.0, 100.0, value)
    checkClose(value, 100.0)

    mouseTo(lo, Sy + Sh * 0.5)
    horizSlider(SlId, Sx, Sy, Sw, Sh, 0.0, 100.0, value)
    checkClose(value, 0.0)

  test "dragging the cursor past the track edge clamps to the range":
    # Regression: the non-Shift drag path used to write lerp() straight back
    # without clamping, so dragging the thumb out past the track produced
    # values well outside [startVal, endVal].
    resetUi()
    var value = 50.0

    placeRect(SlId, rect(Sx, Sy, Sw, Sh))
    pressLeftAt(Sx + Sw * 0.5, Sy + Sh * 0.5) # capture inside the track
    horizSlider(SlId, Sx, Sy, Sw, Sh, 0.0, 100.0, value)

    mouseTo(Sx + Sw * 3, Sy + Sh * 0.5) # keep holding, drag far past the right
    horizSlider(SlId, Sx, Sy, Sw, Sh, 0.0, 100.0, value)
    checkClose(value, 100.0)

    mouseTo(Sx - Sw * 3, Sy + Sh * 0.5) # drag far past the left
    horizSlider(SlId, Sx, Sy, Sw, Sh, 0.0, 100.0, value)
    checkClose(value, 0.0)

  test "a press without cursor movement leaves the value unchanged":
    resetUi()
    let (lo, hi) = trackBounds()
    var value = 25.0

    placeRect(SlId, rect(Sx, Sy, Sw, Sh))
    let px = (lo + hi) * 0.5
    # lastmx/lastmy equal to mx/my -> no movement detected.
    g_uiState.lastmx = px
    g_uiState.lastmy = Sy + Sh * 0.5
    pressLeftAt(px, Sy + Sh * 0.5)
    horizSlider(SlId, Sx, Sy, Sw, Sh, 0.0, 100.0, value)

    check isActive(SlId)
    checkClose(value, 25.0)

  test "release stops the drag and keeps the value":
    resetUi()
    let (lo, hi) = trackBounds()
    var value = 0.0

    placeRect(SlId, rect(Sx, Sy, Sw, Sh))
    pressLeftAt((lo + hi) * 0.5, Sy + Sh * 0.5)
    horizSlider(SlId, Sx, Sy, Sw, Sh, 0.0, 100.0, value)
    checkClose(value, 50.0)

    releaseLeft()
    horizSlider(SlId, Sx, Sy, Sw, Sh, 0.0, 100.0, value)
    sliderPost()
    checkClose(value, 50.0)
    check g_uiState.sliderState.state == ssDefault
    check not g_uiState.widgetMouseDrag

suite "horizontal slider value range":
  test "an out-of-range incoming value is clamped on read":
    resetUi()
    var value = 999.0
    placeRect(SlId, rect(Sx, Sy, Sw, Sh))
    # No press: the widget just clamps and echoes the value back.
    mouseTo(0, 0)
    horizSlider(SlId, Sx, Sy, Sw, Sh, 0.0, 100.0, value)
    checkClose(value, 100.0)

  test "disabled slider does not activate or change from mouse input":
    resetUi()
    let (lo, hi) = trackBounds()
    var value = 25.0

    placeRect(SlId, rect(Sx, Sy, Sw, Sh))
    pressLeftAt((lo + hi) * 0.75, Sy + Sh * 0.5)
    horizSlider(SlId, Sx, Sy, Sw, Sh, 0.0, 100.0, value, disabled = true)

    check isHot(SlId)
    check not isActive(SlId)
    checkClose(value, 25.0)

suite "vertical slider capture":
  test "hovering marks the slider hot without starting a drag":
    resetUi()
    var value = 50.0
    placeRect(SlId, rect(Sx, Sy, Sw, Sh))
    mouseTo(Sx + Sw * 0.5, Sy + Sh * 0.5) # hover, no button
    vertSlider(SlId, Sx, Sy, Sw, Sh, 0.0, 100.0, value)

    check isHot(SlId)
    check not isActive(SlId)
    check g_uiState.sliderState.state == ssDefault

  test "disabled vertical slider does not capture":
    resetUi()
    var value = 50.0
    placeRect(SlId, rect(Sx, Sy, Sw, Sh))
    pressLeftAt(Sx + Sw * 0.5, Sy + Sh * 0.5)
    vertSlider(SlId, Sx, Sy, Sw, Sh, 0.0, 100.0, value, disabled = true)

    check isHot(SlId)
    check not isActive(SlId)
    check g_uiState.sliderState.state == ssDefault
    checkClose(value, 50.0)
