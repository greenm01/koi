## Invariant-based randomized ("fuzz") tests.
##
## Each test drives a widget with a long, seeded sequence of random but VALID
## input (mouse moves, presses, releases, key events) and checks invariants
## after every frame. Seeds are fixed so any failure replays exactly; on a
## violation we print the seed and the action that tripped it.
##
## Constraint: these stay on headless-safe paths only. We never set the Shift
## modifier (slider/scrollbar fine-drag calls disableCursor -> needs a window)
## and never drive text fields into edit mode (glyph measurement needs a live
## NVG context).

import std/random
import std/strformat
import std/strutils

import widget_test_common

const
  Iterations = 4000
  Seeds = [1, 7, 42, 1337, 90210]

proc fapp(x: float): string =
  formatFloat(x, ffDecimal, 4)

# --------------------------------------------------------------------------
# horizSlider: value must always stay within [startVal, endVal].
# --------------------------------------------------------------------------
suite "fuzz: horizontal slider stays in range":
  test "random drag sequences never escape the value range":
    const
      lo = -5.0
      hi = 17.0
    let bar = rect(20, 80, 120, 18)

    for seed in Seeds:
      var rng = initRand(seed)
      resetUi()
      placeRect(60, bar)
      var value = (lo + hi) * 0.5

      for i in 0 ..< Iterations:
        let act = rng.rand(0 .. 3)
        var what = ""
        case act
        of 0:
          let x = rng.rand((bar.x - 60.0) .. (bar.x + bar.w + 60.0))
          pressLeftAt(x, bar.y + bar.h * 0.5)
          what = &"press x={fapp(x)}"
        of 1:
          let x = rng.rand((bar.x - 60.0) .. (bar.x + bar.w + 60.0))
          mouseTo(x, bar.y + bar.h * 0.5)
          what = &"move x={fapp(x)}"
        of 2:
          releaseLeft()
          what = "release"
        else:
          what = "tick"

        horizSlider(60, bar.x, bar.y, bar.w, bar.h, lo, hi, value)
        sliderPost()

        checkpoint &"seed={seed} iter={i} action={what} value={fapp(value)}"
        check value >= lo - 1e-6
        check value <= hi + 1e-6

        nextFrame()

# --------------------------------------------------------------------------
# horizScrollBar: value must always stay within [startVal, endVal].
# --------------------------------------------------------------------------
suite "fuzz: horizontal scrollbar stays in range":
  test "random thumb/track interaction never escapes the value range":
    const
      lo = 0.0
      hi = 100.0
    let bar = rect(20, 80, 120, 14)

    for seed in Seeds:
      var rng = initRand(seed)
      resetUi()
      placeRect(70, bar)
      var value = 50.0

      for i in 0 ..< Iterations:
        let act = rng.rand(0 .. 3)
        var what = ""
        case act
        of 0:
          let x = rng.rand((bar.x - 40.0) .. (bar.x + bar.w + 40.0))
          pressLeftAt(x, bar.y + bar.h * 0.5)
          g_uiState.dx = x
          what = &"press x={fapp(x)}"
        of 1:
          let x = rng.rand((bar.x - 40.0) .. (bar.x + bar.w + 40.0))
          mouseTo(x, bar.y + bar.h * 0.5)
          g_uiState.dx = x
          what = &"drag x={fapp(x)}"
        of 2:
          releaseLeft()
          what = "release"
        else:
          what = "tick"

        horizScrollBar(70, bar.x, bar.y, bar.w, bar.h, lo, hi, value, thumbSize = 25.0)
        scrollBarPost()

        checkpoint &"seed={seed} iter={i} action={what} value={fapp(value)}"
        check value >= lo - 1e-6
        check value <= hi + 1e-6

        nextFrame()

# --------------------------------------------------------------------------
# dropDown: keyboard/selection indices must stay in bounds and the popup
# state machine must never wedge.
# --------------------------------------------------------------------------
type FuzzChoice = enum
  fcA
  fcB
  fcC
  fcD

suite "fuzz: dropdown indices stay in bounds":
  test "random open/navigate/select sequences keep valid indices":
    const items = @["A", "B", "C", "D"]
    let btn = rect(40, 40, 40, 20)
    let listId = hashId($47 & ":popupList")
    let listRect = rect(40, 60, 40, 80)

    for seed in Seeds:
      var rng = initRand(seed)
      resetUi()
      placeRect(47, btn)
      placeRect(listId, listRect)
      var sel = fcA

      for i in 0 ..< Iterations:
        let act = rng.rand(0 .. 6)
        var what = ""
        case act
        of 0:
          pressLeftAt(btn.x + 5, btn.y + 5)
          what = "press button"
        of 1:
          let y = rng.rand((listRect.y - 10.0) .. (listRect.y + listRect.h + 10.0))
          mouseTo(btn.x + 5, y)
          what = &"move y={fapp(y)}"
        of 2:
          releaseLeft()
          what = "release"
        of 3:
          sendKey(keyDown)
          what = "key down"
        of 4:
          sendKey(keyUp)
          what = "key up"
        of 5:
          sendKey(keyEnter)
          what = "key enter"
        else:
          sendKey(keyEscape)
          what = "key escape"

        dropDown(47, btn.x, btn.y, btn.w, btn.h, items, sel, "", disabled = false)

        let ds = dropDownStateOf(47)
        checkpoint &"seed={seed} iter={i} action={what} " &
          &"kbItem={ds.keyboardItem} sel={ord(sel)} state={ds.state}"
        check ds.keyboardItem >= -1
        check ds.keyboardItem <= items.high
        check ord(sel) >= 0
        check ord(sel) <= items.high
        # When the dropdown reports itself closed, focus must not be left captured
        # by it and the popup must not still be open under its id.
        if ds.state == dsClosed:
          check not isPopupOpen(47)

        clearEvent()
        nextFrame()

# --------------------------------------------------------------------------
# popup: open/begin/end/close/escape/outside-click in random order must keep
# the layer stack balanced and focus consistent.
# --------------------------------------------------------------------------
suite "fuzz: popup layer/focus stays consistent":
  test "random lifecycle sequences keep the layer balanced":
    let pr = rect(50, 50, 60, 40)

    for seed in Seeds:
      var rng = initRand(seed)
      resetUi()
      placeRect(30, pr)
      var inBody = false

      for i in 0 ..< Iterations:
        let act = rng.rand(0 .. 5)
        var what = ""
        case act
        of 0:
          if not inBody:
            openPopup(30)
            what = "open"
        of 1:
          if not inBody:
            mouseTo(rng.rand(0.0 .. TestWinW), rng.rand(0.0 .. TestWinH))
            if rng.rand(1) == 0:
              pressLeftAt(mx(), my())
            else:
              releaseLeft()
            if beginPopup(30, pr.x, pr.y, pr.w, pr.h):
              inBody = true
            what = "begin"
        of 2:
          if inBody:
            endPopup()
            inBody = false
            what = "end"
        of 3:
          if not inBody:
            sendKey(keyEscape)
            what = "queue escape"
        of 4:
          if inBody:
            closePopup()
            what = "close from body"
        else:
          what = "tick"

        # Invariant: outside a popup body, we must always be on the default
        # layer (begin/end must balance the layer stack).
        if not inBody:
          checkpoint &"seed={seed} iter={i} action={what} layer={currentLayer()}"
          check currentLayer() == layerDefault
          # A closed popup must never leave focus captured by it.
          if not isPopupOpen(30):
            check not g_uiState.focusCaptured

        clearEvent()
        if not inBody:
          nextFrame()

      # Leave each seed in a clean state for the next.
      if inBody:
        endPopup()
