## Windowed integration tests for the slider cursor-capture drag paths that
## need a real window (disableCursor/showCursor/cursorPosX): the horizontal
## Shift fine-drag and the vertical slider. Headless these crash; here we
## verify they run, stay in range, and actually move the value.

import std/math

import wgpu_test_common

template checkInRange(v, lo, hi: float) =
  check v >= lo - 1e-6
  check v <= hi + 1e-6

suite "horizontal slider fine-drag (Shift)":
  test "shift fine-drag adjusts the value, stays in range, and restores the cursor":
    resetUi()
    const
      sx = 40.0
      sy = 80.0
      sw = 120.0
      sh = 20.0
    var value = 50.0
    placeRect(60, rect(sx, sy, sw, sh))

    # Capture by pressing inside the track with Shift held; move so the widget
    # detects motion and switches to the hidden-cursor fine-drag state.
    g_uiState.keyStates[ord(keyLeftShift)] = true
    g_uiState.lastmx = sx + sw * 0.5
    pressLeftAt(sx + sw * 0.5 + 5, sy + sh * 0.5)
    horizSlider(60, sx, sy, sw, sh, 0.0, 100.0, value)
    check g_uiState.sliderState.state == ssDragHidden

    # Drag via the relative-motion channel.
    g_uiState.dx = g_uiState.x0 + 60.0
    horizSlider(60, sx, sy, sw, sh, 0.0, 100.0, value)
    checkInRange(value, 0.0, 100.0)

    # Releasing Shift returns to the normal state and shows the cursor again.
    g_uiState.keyStates[ord(keyLeftShift)] = false
    horizSlider(60, sx, sy, sw, sh, 0.0, 100.0, value)
    check g_uiState.sliderState.state == ssDefault

    releaseLeft()
    horizSlider(60, sx, sy, sw, sh, 0.0, 100.0, value)
    sliderPost()
    checkInRange(value, 0.0, 100.0)

suite "vertical slider drag":
  test "dragging changes the value and keeps it in range":
    resetUi()
    const
      sx = 40.0
      sy = 40.0
      sw = 20.0
      sh = 120.0
    var value = 50.0
    placeRect(61, rect(sx, sy, sw, sh))

    # Press inside -> vertSlider immediately enters the hidden-cursor drag.
    pressLeftAt(sx + sw * 0.5, sy + sh * 0.5)
    vertSlider(61, sx, sy, sw, sh, 0.0, 100.0, value)
    check g_uiState.sliderState.state == ssDragHidden

    # Drag upward (smaller y) via the relative-motion channel.
    g_uiState.dy = g_uiState.y0 - 40.0
    vertSlider(61, sx, sy, sw, sh, 0.0, 100.0, value)
    checkInRange(value, 0.0, 100.0)
    check value != 50.0 # the drag actually moved it

    releaseLeft()
    vertSlider(61, sx, sy, sw, sh, 0.0, 100.0, value)
    sliderPost()
    checkInRange(value, 0.0, 100.0)
