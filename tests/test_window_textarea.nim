## Windowed integration tests for the multi-line text area: edit entry, typing,
## newline insertion (Shift+Enter), deletion across line boundaries, and cancel.
## Runs against the live WebGPU NanoVG context (see wgpu_test_common).

import wgpu_test_common
import koi/types as koi_types

const
  Ax = 40.0
  Ay = 40.0
  Aw = 200.0
  Ah = 80.0

type WrapCase = object
  text: string
  width: float
  rows: seq[koi_types.TextRow]

template ta(text: var string) =
  textArea(2, Ax, Ay, Aw, Ah, text)

template taAt(width: float, text: var string) =
  textArea(2, Ax, Ay, width, Ah, text)

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

proc rowHeight(): float =
  let style = borrowDefaultTextAreaStyle()
  style.textFontSize * style.textLineHeight

proc textBoxX(): float =
  Ax + borrowDefaultTextAreaStyle().textPadHoriz

proc textBoxW(width: float): float =
  let style = borrowDefaultTextAreaStyle()
  width - style.textPadHoriz * 2 - style.scrollBarWidth

proc rowMouseY(rowIndex: Natural): float =
  Ay + borrowDefaultTextAreaStyle().textPadVert + rowHeight() * (rowIndex.float + 0.5)

proc softWrapCase(): WrapCase =
  result.text = "alpha beta gamma delta epsilon zeta eta theta iota"
  for width in countup(72, 180, 4):
    let rows = measureTextRows(result.text, textBoxW(width.float))
    if rows.len >= 4 and rows[0].nextRowPos >= 0 and rows[1].nextRowPos >= 0:
      result.width = width.float
      result.rows = rows
      return

  doAssert false, "could not find a deterministic soft-wrap width"

proc keyAt(width: float, text: var string, k: Key, mods: set[ModifierKey] = {}) =
  sendKey(k, mods)
  taAt(width, text)

proc focusAreaAt(width: float, text: var string) =
  pressLeftAt(Ax + 6, Ay + 6)
  taAt(width, text)
  releaseLeft()
  taAt(width, text)

proc clickRowAt(width: float, text: var string, rowIndex: Natural, x: float) =
  pressLeftAt(x, rowMouseY(rowIndex))
  taAt(width, text)
  releaseLeft()
  taAt(width, text)

proc cursorPos(): Natural =
  cast[TextAreaStateVars](g_uiState.itemState[2]).cursorPos

proc selectedText(text: string): string =
  let selection = cast[TextAreaStateVars](g_uiState.itemState[2]).selection
  if not hasSelection(selection):
    return ""
  let ns = normaliseSelection(selection)
  text.runeSubStr(ns.startPos, ns.endPos - ns.startPos)

proc expectedCursorAtRowX(c: WrapCase, rowIndex: Natural, cursorX: float): Natural =
  let
    row = c.rows[rowIndex]
    glyphs = measureRowGlyphs(c.text, row)
  textAreaCursorPosAt(
    glyphs, row.startPos, textAreaRowTextEndCursor(row, c.text), cursorX, textBoxX()
  )

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

    template cur(): int =
      cast[TextAreaStateVars](g_uiState.itemState[2]).cursorPos.int

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
    template cur(): int =
      cast[TextAreaStateVars](g_uiState.itemState[2]).cursorPos.int

    check cur == 5 # end of line 0 text, NOT 6 (start of line 1)

  test "escape cancels and restores the original text":
    resetUi()
    var text = "keep\nme"
    focusArea(text)
    typeInto(text, "wipe") # entry selects all -> replaces
    key(text, keyEscape)
    check text == "keep\nme"

suite "text area soft wrapping":
  test "End on a soft-wrapped row stays on that visual row":
    resetUi()
    let c = softWrapCase()
    var text = c.text
    focusAreaAt(c.width, text)

    clickRowAt(c.width, text, 0, textBoxX())
    keyAt(c.width, text, keyEnd)

    check cursorPos() == textAreaRowTextEndCursor(c.rows[0], c.text)

  test "shift+End selects only the soft-wrapped visual row":
    resetUi()
    let c = softWrapCase()
    var text = c.text
    focusAreaAt(c.width, text)

    clickRowAt(c.width, text, 1, textBoxX())
    keyAt(c.width, text, keyEnd, {mkShift})

    let expected = c.text.runeSubStr(
      c.rows[1].startPos,
      textAreaRowTextEndCursor(c.rows[1], c.text) - c.rows[1].startPos,
    )
    check selectedText(text) == expected

  test "up/down preserves measured x-column across soft-wrapped rows":
    resetUi()
    let c = softWrapCase()
    var text = c.text
    focusAreaAt(c.width, text)

    clickRowAt(c.width, text, 0, textBoxX())
    keyAt(c.width, text, keyEnd)
    let cursorX = textAreaCursorX(
      measureRowGlyphs(c.text, c.rows[0]), c.rows[0].startPos, cursorPos(), textBoxX()
    )

    keyAt(c.width, text, keyDown)
    check cursorPos() == expectedCursorAtRowX(c, 1, cursorX)

    keyAt(c.width, text, keyDown)
    check cursorPos() == expectedCursorAtRowX(c, 2, cursorX)

  test "clicking past text on a soft-wrapped row lands at that row end":
    resetUi()
    let c = softWrapCase()
    var text = c.text
    focusAreaAt(c.width, text)

    clickRowAt(c.width, text, 1, textBoxX() + textBoxW(c.width) - 1)

    check cursorPos() == textAreaRowTextEndCursor(c.rows[1], c.text)

  test "wrapped text area rendering flushes queued draw commands":
    let c = softWrapCase()
    var text = c.text

    renderOneFrame:
      textArea(2, Ax, Ay, c.width, Ah, text)
