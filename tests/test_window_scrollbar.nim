## Windowed integration tests for scrollbar hidden-cursor fine-drag paths.
## These need a real window because the widget calls disableCursor/showCursor.

import wgpu_test_common

template checkInRange(v, lo, hi: float) =
  check v >= lo - 1e-6
  check v <= hi + 1e-6

proc horizThumb(value, x, w, thumbSize, startVal, endVal: float): tuple[x, w: float] =
  let st = borrowDefaultScrollBarStyle()
  result.w =
    scrollBarThumbLength(w, st.thumbPad, st.thumbMinSize, thumbSize, startVal, endVal)
  let
    minX = x + st.thumbPad
    maxX = x + w - st.thumbPad - result.w
  result.x = scrollBarThumbFromValue(value, startVal, endVal, minX, maxX)

proc vertThumb(value, y, h, thumbSize, startVal, endVal: float): tuple[y, h: float] =
  let st = borrowDefaultScrollBarStyle()
  result.h =
    scrollBarThumbLength(h, st.thumbPad, st.thumbMinSize, thumbSize, startVal, endVal)
  let
    minY = y + st.thumbPad
    maxY = y + h - st.thumbPad - result.h
  result.y = scrollBarThumbFromValue(value, startVal, endVal, minY, maxY)

suite "horizontal scrollbar fine-drag (Shift)":
  test "shift fine-drag adjusts the value, stays in range, and restores the cursor":
    resetUi()
    const
      id: ItemId = 70
      x = 40.0
      y = 80.0
      w = 120.0
      h = 16.0
      thumbSize = 30.0
    var value = 50.0
    let thumb = horizThumb(value, x, w, thumbSize, 0.0, 100.0)
    placeRect(id, rect(x, y, w, h))

    g_uiState.keyStates[ord(keyLeftShift)] = true
    pressLeftAt(thumb.x + thumb.w * 0.5, y + h * 0.5)
    horizScrollBar(id, x, y, w, h, 0.0, 100.0, value, thumbSize = thumbSize)
    check g_uiState.scrollBarState.state == sbsDragHidden

    g_uiState.dx = g_uiState.x0 + 60.0
    horizScrollBar(id, x, y, w, h, 0.0, 100.0, value, thumbSize = thumbSize)
    checkInRange(value, 0.0, 100.0)

    g_uiState.keyStates[ord(keyLeftShift)] = false
    horizScrollBar(id, x, y, w, h, 0.0, 100.0, value, thumbSize = thumbSize)
    check g_uiState.scrollBarState.state == sbsDragNormal

    releaseLeft()
    horizScrollBar(id, x, y, w, h, 0.0, 100.0, value, thumbSize = thumbSize)
    scrollBarPost()
    check g_uiState.scrollBarState.state == sbsDefault
    checkInRange(value, 0.0, 100.0)

suite "vertical scrollbar fine-drag (Shift)":
  test "shift fine-drag adjusts the value, stays in range, and restores the cursor":
    resetUi()
    const
      id: ItemId = 71
      x = 40.0
      y = 40.0
      w = 16.0
      h = 120.0
      thumbSize = 30.0
    var value = 50.0
    let thumb = vertThumb(value, y, h, thumbSize, 0.0, 100.0)
    placeRect(id, rect(x, y, w, h))

    g_uiState.keyStates[ord(keyLeftShift)] = true
    pressLeftAt(x + w * 0.5, thumb.y + thumb.h * 0.5)
    vertScrollBar(id, x, y, w, h, 0.0, 100.0, value, thumbSize = thumbSize)
    check g_uiState.scrollBarState.state == sbsDragHidden

    g_uiState.dy = g_uiState.y0 + 60.0
    vertScrollBar(id, x, y, w, h, 0.0, 100.0, value, thumbSize = thumbSize)
    checkInRange(value, 0.0, 100.0)

    g_uiState.keyStates[ord(keyLeftShift)] = false
    vertScrollBar(id, x, y, w, h, 0.0, 100.0, value, thumbSize = thumbSize)
    check g_uiState.scrollBarState.state == sbsDragNormal

    releaseLeft()
    vertScrollBar(id, x, y, w, h, 0.0, 100.0, value, thumbSize = thumbSize)
    scrollBarPost()
    check g_uiState.scrollBarState.state == sbsDefault
    checkInRange(value, 0.0, 100.0)
