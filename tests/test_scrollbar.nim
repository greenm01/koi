## Headless behaviour tests for the scrollbar widget: thumb-drag capture,
## value mapping with clamping at both ends, trough (track) clicks, and
## post-frame drag-state reset. The Shift fine-drag path needs a real window
## (disableCursor) and is not exercised here.

import widget_test_common

const
  SbId: ItemId = 70
  Bx = 20.0
  By = 80.0
  Bw = 100.0
  Bh = 12.0
  StartVal = 0.0
  EndVal = 100.0
  ThumbSize = 30.0

proc thumbGeom(value: float): tuple[x, w, minX, maxX: float] =
  let st = borrowDefaultScrollBarStyle()
  let w =
    scrollBarThumbLength(Bw, st.thumbPad, st.thumbMinSize, ThumbSize, StartVal, EndVal)
  let minX = Bx + st.thumbPad
  let maxX = Bx + Bw - st.thumbPad - w
  let x = scrollBarThumbFromValue(value, StartVal, EndVal, minX, maxX)
  (x, w, minX, maxX)

proc bar(value: var float, tooltip: string = "") =
  horizScrollBar(
    SbId, Bx, By, Bw, Bh, StartVal, EndVal, value, tooltip, thumbSize = ThumbSize
  )

proc disabledBar(value: var float) =
  horizScrollBar(
    SbId,
    Bx,
    By,
    Bw,
    Bh,
    StartVal,
    EndVal,
    value,
    thumbSize = ThumbSize,
    disabled = true,
  )

proc makeRepeatDue() =
  g_uiState.t0 = currentTime() - 1.0

suite "scrollbar thumb drag":
  test "pressing on the thumb begins a normal drag":
    resetUi()
    var value = 50.0
    let g = thumbGeom(value)

    placeRect(SbId, rect(Bx, By, Bw, Bh))
    pressLeftAt(g.x + g.w * 0.5, By + Bh * 0.5)
    bar(value)

    check isActive(SbId)
    check g_uiState.scrollBarState.state == sbsDragNormal

  test "dragging far right clamps the value to the maximum":
    resetUi()
    var value = 50.0
    let g = thumbGeom(value)

    placeRect(SbId, rect(Bx, By, Bw, Bh))
    pressLeftAt(g.x + g.w * 0.5, By + Bh * 0.5)
    bar(value) # capture -> sbsDragNormal, ui.x0 set to press X

    g_uiState.dx = g_uiState.x0 + 1000.0 # drag well past the track end
    bar(value)
    check abs(value - EndVal) < 1e-9

  test "dragging far left clamps the value to the minimum":
    resetUi()
    var value = 50.0
    let g = thumbGeom(value)

    placeRect(SbId, rect(Bx, By, Bw, Bh))
    pressLeftAt(g.x + g.w * 0.5, By + Bh * 0.5)
    bar(value)

    g_uiState.dx = g_uiState.x0 - 1000.0
    bar(value)
    check abs(value - StartVal) < 1e-9

  test "disabled scrollbar does not activate or change value":
    resetUi()
    var value = 50.0
    let g = thumbGeom(value)

    placeRect(SbId, rect(Bx, By, Bw, Bh))
    pressLeftAt(g.x + g.w * 0.5, By + Bh * 0.5)
    disabledBar(value)

    check isHot(SbId)
    check not isActive(SbId)
    check g_uiState.scrollBarState.state == sbsDefault
    check abs(value - 50.0) < 1e-9

suite "scrollbar trough click":
  test "clicking right of the thumb steps the value up by 10%":
    resetUi()
    var value = 50.0
    let g = thumbGeom(value)

    placeRect(SbId, rect(Bx, By, Bw, Bh))
    # Press inside the bar but to the right of the thumb.
    pressLeftAt(g.maxX + g.w + 1.0, By + Bh * 0.5)
    bar(value) # -> sbsTrackClickFirst
    check g_uiState.scrollBarState.state == sbsTrackClickFirst

    bar(value) # sbsTrackClickFirst applies one step (range * 0.1 = 10)
    check abs(value - 60.0) < 1e-9

  test "holding the track repeats while the cursor remains past the thumb":
    resetUi()
    var value = 20.0
    let g = thumbGeom(value)

    placeRect(SbId, rect(Bx, By, Bw, Bh))
    pressLeftAt(g.maxX + g.w + 1.0, By + Bh * 0.5)
    bar(value) # -> sbsTrackClickFirst
    bar(value) # first step
    check abs(value - 30.0) < 1e-9

    makeRepeatDue()
    bar(value) # delay -> repeat
    check g_uiState.scrollBarState.state == sbsTrackClickRepeat
    check abs(value - 30.0) < 1e-9

    makeRepeatDue()
    bar(value) # repeat step
    check abs(value - 40.0) < 1e-9

  test "track repeat stops once the thumb moves under the cursor":
    resetUi()
    var value = 50.0
    let g = thumbGeom(value)

    placeRect(SbId, rect(Bx, By, Bw, Bh))
    pressLeftAt(g.x + g.w + 2.0, By + Bh * 0.5)
    bar(value) # -> sbsTrackClickFirst
    bar(value) # first step moves the thumb under/near the cursor
    check abs(value - 60.0) < 1e-9

    makeRepeatDue()
    bar(value) # delay -> repeat
    makeRepeatDue()
    bar(value) # repeat should be suppressed because the thumb passed the cursor
    check abs(value - 60.0) < 1e-9

    releaseLeft()
    bar(value)
    scrollBarPost()
    let afterRightClick = thumbGeom(value)

    pressLeftAt(afterRightClick.x - 2.0, By + Bh * 0.5)
    bar(value) # -> sbsTrackClickFirst with opposite click direction
    bar(value)
    check abs(value - 50.0) < 1e-9

  test "track repeat still runs while tooltip state is visible":
    resetUi()
    var value = 20.0
    let g = thumbGeom(value)
    g_uiState.tooltipState.state = tsShow
    g_uiState.tooltipState.lastHotItem = SbId
    g_uiState.tooltipState.text = "scroll"

    placeRect(SbId, rect(Bx, By, Bw, Bh))
    pressLeftAt(g.maxX + g.w + 1.0, By + Bh * 0.5)
    bar(value, tooltip = "scroll")
    bar(value, tooltip = "scroll")
    makeRepeatDue()
    bar(value, tooltip = "scroll")
    makeRepeatDue()
    bar(value, tooltip = "scroll")

    check abs(value - 40.0) < 1e-9

suite "scrollbar drag reset":
  test "releasing the button resets the drag state via scrollBarPost":
    resetUi()
    var value = 50.0
    let g = thumbGeom(value)

    placeRect(SbId, rect(Bx, By, Bw, Bh))
    pressLeftAt(g.x + g.w * 0.5, By + Bh * 0.5)
    bar(value)
    check g_uiState.scrollBarState.state == sbsDragNormal

    releaseLeft()
    bar(value)
    scrollBarPost()
    check g_uiState.scrollBarState.state == sbsDefault
    check not g_uiState.widgetMouseDrag
