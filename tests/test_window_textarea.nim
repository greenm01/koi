## Windowed integration tests for the multi-line text area: edit entry, typing,
## newline insertion (Shift+Enter), deletion across line boundaries, and cancel.
## Runs against the live WebGPU NanoVG context (see wgpu_test_common).

import wgpu_test_common

const
  Ax = 40.0
  Ay = 40.0
  Aw = 200.0
  Ah = 80.0

template ta(text: var string) =
  textArea(2, Ax, Ay, Aw, Ah, text)

template typeInto(text: var string, s: string) =
  typeText(s)
  ta(text)

template key(text: var string, k: Key, mods: set[ModifierKey] = {}) =
  sendKey(k, mods)
  ta(text)

proc focusArea(text: var string) =
  pressLeftAt(Ax + 6, Ay + 6)
  ta(text)
  releaseLeft()
  ta(text)

suite "text area editing":
  test "click enters edit mode and captures focus":
    resetUi()
    var text = ""
    focusArea(text)
    check g_uiState.focusCaptured
    check cast[TextAreaStateVars](g_uiState.itemState[2]).activeItem == 2

  test "typing inserts characters":
    resetUi()
    var text = ""
    focusArea(text)
    typeInto(text, "hello")
    check text == "hello"

  test "shift+enter inserts a newline to build multiple lines":
    resetUi()
    var text = ""
    focusArea(text)
    typeInto(text, "ab")
    key(text, keyEnter, {mkShift})
    typeInto(text, "cd")
    check text == "ab\ncd"

  test "backspace at the start of a line merges it with the previous line":
    resetUi()
    var text = ""
    focusArea(text)
    typeInto(text, "ab")
    key(text, keyEnter, {mkShift}) # "ab\n", cursor after newline
    key(text, keyBackspace) # deletes the newline
    check text == "ab"

  test "up/down navigation preserves the column and climbs lines":
    # Regression: row end-cursors used to point past a hard newline (onto the
    # next line's start), so up-arrow from a line end landed on the wrong line
    # and got stuck. Three identical lines make the column mapping exact.
    resetUi()
    var text = ""
    focusArea(text)
    typeInto(text, "abcde")
    key(text, keyEnter, {mkShift})
    typeInto(text, "abcde")
    key(text, keyEnter, {mkShift})
    typeInto(text, "abcde") # cursor at end of line 2 (pos 17)

    template cur: int = cast[TextAreaStateVars](g_uiState.itemState[
        2]).cursorPos.int
    check cur == 17
    key(text, keyUp)
    check cur == 11 # line 1, column 5 (not 12, the start of line 2)
    key(text, keyUp)
    check cur == 5 # line 0, column 5
    key(text, keyDown)
    check cur == 11 # back to line 1, column 5

  test "End on a non-final line stays on that line (before the newline)":
    resetUi()
    var text = ""
    focusArea(text)
    typeInto(text, "abcde")
    key(text, keyEnter, {mkShift})
    typeInto(text, "abcde") # two lines; cursor on line 1
    key(text, keyUp) # move to line 0
    key(text, keyEnd)
    template cur: int = cast[TextAreaStateVars](g_uiState.itemState[
        2]).cursorPos.int
    check cur == 5 # end of line 0 text, NOT 6 (start of line 1)

  test "escape cancels and restores the original text":
    resetUi()
    var text = "keep\nme"
    focusArea(text)
    typeInto(text, "wipe") # entry selects all -> replaces
    key(text, keyEscape)
    check text == "keep\nme"
