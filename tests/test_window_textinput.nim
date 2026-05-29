## Windowed integration tests for real text-field editing. These run against a
## live WebGPU NanoVG context (see wgpu_test_common) so the widget's in-proc
## glyph measurement works and the full edit-mode state machine is exercised:
## entry/exit, typing, deletion, cursor movement, selection, commit/cancel, tab
## navigation, input filtering, and value constraints.

import std/options

import wgpu_test_common

const
  Fx = 40.0
  Fy = 40.0
  Fw = 160.0
  Fh = 20.0

template tf(text: var string) =
  textField(1, Fx, Fy, Fw, Fh, text)

# Type a string and let the widget consume it in one frame.
template typeInto(text: var string, s: string) =
  typeText(s)
  tf(text)

# Send one key (down) and let the widget process it.
template key(text: var string, k: Key, mods: set[ModifierKey] = {}) =
  sendKey(k, mods)
  tf(text)

suite "text field edit entry/exit":
  test "click enters edit mode and captures focus":
    resetUi()
    var text = "seed"
    focusTextField(1, Fx, Fy, Fw, Fh, text)

    check g_uiState.textFieldState.activeItem == 1
    check g_uiState.textFieldState.state == tfsEdit
    check g_uiState.focusCaptured

  test "enter commits the edited value and exits":
    resetUi()
    var text = "seed"
    focusTextField(1, Fx, Fy, Fw, Fh, text)
    typeInto(text, "done")
    key(text, keyEnter)

    check text == "done"
    check g_uiState.textFieldState.activeItem == 0
    check not g_uiState.focusCaptured

  test "escape cancels and restores the original value":
    resetUi()
    var text = "original"
    focusTextField(1, Fx, Fy, Fw, Fh, text)
    typeInto(text, "garbage")
    check text == "garbage"

    key(text, keyEscape)
    check text == "original"
    check g_uiState.textFieldState.activeItem == 0

suite "text field typing and deletion":
  test "the value is fully selected on entry so typing replaces it":
    resetUi()
    var text = "seed"
    focusTextField(1, Fx, Fy, Fw, Fh, text)
    typeInto(text, "X")
    check text == "X"

  test "moving to end deselects, then typing appends":
    resetUi()
    var text = "seed"
    focusTextField(1, Fx, Fy, Fw, Fh, text)
    key(text, keyEnd)
    typeInto(text, "ling")
    check text == "seedling"

  test "backspace deletes the char before the cursor":
    resetUi()
    var text = ""
    focusTextField(1, Fx, Fy, Fw, Fh, text)
    typeInto(text, "abc")
    key(text, keyBackspace)
    check text == "ab"
    check g_uiState.textFieldState.cursorPos == 2

  test "delete removes the char after the cursor":
    resetUi()
    var text = ""
    focusTextField(1, Fx, Fy, Fw, Fh, text)
    typeInto(text, "abc")
    key(text, keyHome)
    key(text, keyDelete)
    check text == "bc"

suite "text field cursor and selection":
  test "left and right arrows move the cursor":
    resetUi()
    var text = ""
    focusTextField(1, Fx, Fy, Fw, Fh, text)
    typeInto(text, "abc") # cursor at 3
    key(text, keyLeft)
    check g_uiState.textFieldState.cursorPos == 2
    key(text, keyLeft)
    check g_uiState.textFieldState.cursorPos == 1
    key(text, keyRight)
    check g_uiState.textFieldState.cursorPos == 2

  test "home and end jump to the extremes":
    resetUi()
    var text = ""
    focusTextField(1, Fx, Fy, Fw, Fh, text)
    typeInto(text, "hello")
    key(text, keyHome)
    check g_uiState.textFieldState.cursorPos == 0
    key(text, keyEnd)
    check g_uiState.textFieldState.cursorPos == 5

  test "ctrl+A selects all and the next typed char replaces everything":
    resetUi()
    var text = ""
    focusTextField(1, Fx, Fy, Fw, Fh, text)
    typeInto(text, "replace me")
    key(text, keyHome) # clear the entry selection, cursor to start
    key(text, keyA, {mkCtrl})
    check hasSelection(g_uiState.textFieldState.selection)
    typeInto(text, "Z")
    check text == "Z"

  test "clicking in the body positions the cursor and clears the selection":
    resetUi()
    var text = ""
    focusTextField(1, Fx, Fy, Fw, Fh, text)
    typeInto(text, "abcdef") # whole value, cursor at end, no selection now

    # Click near the very left edge of the text box -> cursor at 0.
    pressLeftAt(Fx + 1, Fy + Fh * 0.5)
    tf(text)
    check g_uiState.textFieldState.cursorPos == 0
    check not hasSelection(g_uiState.textFieldState.selection)
    releaseLeft()
    tf(text)

suite "text field editing edge cases":
  test "backspace at the start of the value is a no-op":
    resetUi()
    var text = ""
    focusTextField(1, Fx, Fy, Fw, Fh, text)
    typeInto(text, "ab")
    key(text, keyHome)
    key(text, keyBackspace)
    check text == "ab"
    check g_uiState.textFieldState.cursorPos == 0

  test "delete at the end of the value is a no-op":
    resetUi()
    var text = ""
    focusTextField(1, Fx, Fy, Fw, Fh, text)
    typeInto(text, "ab") # cursor at end
    key(text, keyDelete)
    check text == "ab"

  test "left arrow clamps at 0 and right arrow clamps at the end":
    resetUi()
    var text = ""
    focusTextField(1, Fx, Fy, Fw, Fh, text)
    typeInto(text, "ab")
    key(text, keyHome)
    key(text, keyLeft)
    key(text, keyLeft)
    check g_uiState.textFieldState.cursorPos == 0
    key(text, keyEnd)
    key(text, keyRight)
    key(text, keyRight)
    check g_uiState.textFieldState.cursorPos == 2

  test "backspace deletes a multi-byte rune as a single character":
    resetUi()
    var text = ""
    focusTextField(1, Fx, Fy, Fw, Fh, text)
    typeInto(text, "café") # 'é' is two bytes, one rune
    check text.runeLen == 4
    key(text, keyBackspace)
    check text == "caf"
    check g_uiState.textFieldState.cursorPos == 3

  test "ctrl+left/right move by whole words":
    # Word-back lands on a word's first char; word-forward skips the current
    # word AND its trailing whitespace, landing on the next word's first char.
    resetUi()
    var text = ""
    focusTextField(1, Fx, Fy, Fw, Fh, text)
    typeInto(text, "foo bar baz") # cursor at end (11)
    key(text, keyLeft, {mkCtrl})
    check g_uiState.textFieldState.cursorPos == 8 # start of "baz"
    key(text, keyLeft, {mkCtrl})
    check g_uiState.textFieldState.cursorPos == 4 # start of "bar"
    key(text, keyRight, {mkCtrl})
    check g_uiState.textFieldState.cursorPos == 8 # forward to start of "baz"

  test "shift+arrow extends a selection that delete then removes":
    resetUi()
    var text = ""
    focusTextField(1, Fx, Fy, Fw, Fh, text)
    typeInto(text, "abcdef")
    key(text, keyHome)
    key(text, keyRight, {mkShift})
    key(text, keyRight, {mkShift})
    key(text, keyRight, {mkShift}) # select "abc"
    check hasSelection(g_uiState.textFieldState.selection)
    key(text, keyBackspace) # delete the selection
    check text == "def"

suite "text field double-click word selection":
  proc selText(text: string, sel: TextSelection): string =
    if not hasSelection(sel):
      return ""
    let ns = normaliseSelection(sel)
    text.runeSubStr(ns.startPos, ns.endPos - ns.startPos)

  # Simulate a double click at x by stamping the double-click timing fields.
  proc doubleClickAt(text: var string, x: float) =
    g_uiState.mbLeftDown = true
    g_uiState.mx = x
    g_uiState.my = Fy + Fh * 0.5
    g_uiState.lastMbLeftDownT = currentTime()
    g_uiState.mbLeftDownT = currentTime()
    g_uiState.lastMbLeftDownX = x
    g_uiState.lastMbLeftDownY = Fy + Fh * 0.5
    tf(text)

  test "double-click selects the word without the trailing space":
    resetUi()
    var text = ""
    focusTextField(1, Fx, Fy, Fw, Fh, text)
    typeInto(text, "foo bar baz")
    key(text, keyEnd)
    doubleClickAt(text, Fx + 4 + 42.0) # into the middle word "bar"
    check selText(text, g_uiState.textFieldState.selection) == "bar"

  test "double-click stops at punctuation":
    resetUi()
    var text = ""
    focusTextField(1, Fx, Fy, Fw, Fh, text)
    typeInto(text, "foo.bar")
    key(text, keyHome)
    doubleClickAt(text, Fx + 4 + 8.0) # into "foo"
    check selText(text, g_uiState.textFieldState.selection) == "foo"

suite "text field tab navigation":
  test "tab exits the field and requests the next one":
    resetUi()
    var a = "one"
    focusTextField(1, Fx, Fy, Fw, Fh, a)
    sendKey(keyTab)
    textField(1, Fx, Fy, Fw, Fh, a)

    check g_uiState.textFieldState.activeItem == 0
    check g_uiState.tabActivationState.activateNext

suite "text field filtering and constraints":
  test "an integer filter rejects non-digit characters":
    resetUi()
    var text = ""
    pressLeftAt(Fx + 4, Fy + Fh * 0.5)
    textField(1, Fx, Fy, Fw, Fh, text, filter = tffInteger)
    releaseLeft()
    textField(1, Fx, Fy, Fw, Fh, text, filter = tffInteger)

    typeText("a1b2c3")
    textField(1, Fx, Fy, Fw, Fh, text, filter = tffInteger)
    check text == "123"

  test "an integer constraint clamps the value on commit":
    resetUi()
    var text = ""
    let c = TextFieldConstraint(kind: tckInteger, minInt: 0, maxInt: 100).some
    pressLeftAt(Fx + 4, Fy + Fh * 0.5)
    textField(1, Fx, Fy, Fw, Fh, text, constraint = c)
    releaseLeft()
    textField(1, Fx, Fy, Fw, Fh, text, constraint = c)

    typeText("250")
    textField(1, Fx, Fy, Fw, Fh, text, constraint = c)
    sendKey(keyEnter)
    textField(1, Fx, Fy, Fw, Fh, text, constraint = c)

    check text == "100"
