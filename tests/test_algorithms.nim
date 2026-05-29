import std/math
import std/options
import std/unittest

import glfw
import nanovg

import koi/core
import koi/defaults
import koi/input
import koi/internal/algorithms
import koi/layout
import koi/types

const Epsilon = 0.0001

template checkClose(actual, expected: float) =
  check abs(actual - expected) < Epsilon

proc resetLayout(params: AutoLayoutParams = DefaultAutoLayoutParams) =
  g_uiState = UIState.default
  g_uiState.winWidth = 1000
  g_uiState.winHeight = 1000
  g_uiState.drawOffsetStack = @[DrawOffset(ox: 0, oy: 0)]
  initAutoLayout(params)

func fixedGlyphs(count: Natural, advance: float): seq[GlyphPosition] =
  for i in 0 ..< count:
    result.add(
      GlyphPosition(
        x: (i.float * advance).cfloat,
        minX: (i.float * advance).cfloat,
        maxX: ((i.float + 1.0) * advance).cfloat,
      )
    )

func textRow(
    startPos, endPos: Natural, nextRowPos: int, width: float = 10
): types.TextRow =
  types.TextRow(
    startPos: startPos,
    startBytePos: startPos,
    endPos: endPos,
    endBytePos: endPos,
    nextRowPos: nextRowPos,
    nextRowBytePos: nextRowPos,
    width: width,
  )

suite "layout algorithms":
  test "itemsPerRow zero falls back to one column":
    var params = DefaultAutoLayoutParams
    params.itemsPerRow = 0
    resetLayout(params)

    autoLayoutPre()
    checkClose(autoLayoutNextItemWidth(), 303)
    autoLayoutPost()

    check g_uiState.autoLayoutState.currColIndex == 0
    checkClose(g_uiState.autoLayoutState.y, 33)

suite "dropdown algorithms":
  test "hover math ignores padding and out-of-range rows":
    check dropDownHoverItem(101, 100, 4, 20, 0, 4, 10) == -1
    check dropDownHoverItem(104, 100, 4, 20, 0, 4, 10) == 0
    check dropDownHoverItem(143.9, 100, 4, 20, 2, 4, 10) == 3
    check dropDownHoverItem(184, 100, 4, 20, 0, 4, 10) == -1
    check dropDownHoverItem(164, 100, 4, 20, 8, 4, 10) == -1

suite "scrollbar algorithms":
  test "thumb math handles degenerate value ranges":
    checkClose(scrollBarThumbLength(100, 2, 12, -1, 5, 5), 96)
    checkClose(scrollBarThumbLength(100, 2, 12, 0, 0, 100), 12)
    checkClose(scrollBarThumbFromValue(5, 5, 5, 2, 98), 2)
    checkClose(scrollBarValueFromThumb(50, 2, 98, 5, 5), 5)

  test "track click value clamps ascending and descending ranges":
    checkClose(scrollBarTrackClickValue(95, 0, 100, 1, 10), 100)
    checkClose(scrollBarTrackClickValue(5, 0, 100, -1, 10), 0)
    checkClose(scrollBarTrackClickValue(5, 100, 0, -1, 10), 0)

suite "text editing algorithms":
  test "insert max length accounts for replaced selection":
    let res = insertString(
      "abcde", 4.Natural, TextSelection(startPos: 1, endPos: 4), "XYZ", 5.Natural.some
    )

    check res.text == "aXYZe"
    check res.cursorPos == 4
    check not hasSelection(res.selection)

  test "insert at max length without selection is a no-op":
    let res = insertString("abcde", 5.Natural, NoSelection, "Z", 5.Natural.some)

    check res.text == "abcde"
    check res.cursorPos == 5
    check not hasSelection(res.selection)

  test "delete right at end keeps text and cursor stable":
    useShortcuts(smLinux)
    let res = handleCommonTextEditingShortcuts(
      mkKeyShortcut(keyDelete), "abc", 3.Natural, NoSelection, Natural.none
    )

    check res.isSome
    check res.get.text == "abc"
    check res.get.cursorPos == 3
    check not hasSelection(res.get.selection)

suite "text field view algorithms":
  test "empty text keeps the view at the text box origin":
    let glyphs = fixedGlyphs(0, 10)
    let view = textFieldViewForCursor(
      glyphs,
      0.Natural,
      0.Natural,
      100,
      50,
      TextFieldView(displayStartPos: 3, displayStartX: 12),
    )

    check view.displayStartPos == 0
    checkClose(view.displayStartX, 100)
    checkClose(textFieldCursorX(glyphs, 0.Natural, 0.Natural, view), 100)

  test "fully visible text stays unscrolled":
    let glyphs = fixedGlyphs(4, 10)
    let view = textFieldViewForCursor(
      glyphs,
      4.Natural,
      4.Natural,
      100,
      50,
      TextFieldView(displayStartPos: 2, displayStartX: 80),
    )

    check view.displayStartPos == 0
    checkClose(view.displayStartX, 100)
    checkClose(textFieldCursorX(glyphs, 4.Natural, 4.Natural, view), 140)

  test "long text keeps the end cursor at the right edge":
    let glyphs = fixedGlyphs(10, 10)
    let view = textFieldViewForCursor(
      glyphs,
      10.Natural,
      10.Natural,
      100,
      50,
      TextFieldView(displayStartPos: 0, displayStartX: 100),
    )

    check view.displayStartPos == 5
    checkClose(view.displayStartX, 100)
    checkClose(textFieldCursorX(glyphs, 10.Natural, 10.Natural, view), 150)

  test "moving left scrolls only enough to reveal the cursor":
    let glyphs = fixedGlyphs(10, 10)
    let view = textFieldViewForCursor(
      glyphs,
      10.Natural,
      2.Natural,
      100,
      50,
      TextFieldView(displayStartPos: 5, displayStartX: 100),
    )

    check view.displayStartPos == 2
    checkClose(view.displayStartX, 100)
    checkClose(textFieldCursorX(glyphs, 10.Natural, 2.Natural, view), 100)

  test "mouse position maps to visible cursor positions":
    let glyphs = fixedGlyphs(10, 10)
    let view = TextFieldView(displayStartPos: 5, displayStartX: 100)

    check textFieldCursorPosAt(
      glyphs, 10.Natural, view.displayStartPos, view.displayStartX, 101
    ) == 5
    check textFieldCursorPosAt(
      glyphs, 10.Natural, view.displayStartPos, view.displayStartX, 116
    ) == 7
    check textFieldCursorPosAt(
      glyphs, 10.Natural, view.displayStartPos, view.displayStartX, 500
    ) == 10

suite "text area view algorithms":
  test "empty text maps cursor and clicks to the first row":
    let rows = @[textRow(0, 0, -1, width = 0)]
    let glyphs = fixedGlyphs(0, 10)

    check textAreaRowForCursor(rows, 0) == 0
    check textAreaRowAtY(rows.len.Natural, 0, 100, 20, 80) == 0
    check textAreaCursorPosAt(glyphs, 0, textAreaRowEndCursor(rows[0]), 120, 100) == 0

  test "cursor positions map across wrapped and trailing rows":
    let rows = @[textRow(0, 4, 5), textRow(5, 9, 10), textRow(10, 10, -1, width = 0)]

    check textAreaRowForCursor(rows, 0) == 0
    check textAreaRowForCursor(rows, 5) == 1
    check textAreaRowForCursor(rows, 9) == 1
    check textAreaRowForCursor(rows, 10) == 2

  test "mouse y clamps to available rows":
    check textAreaRowAtY(3, 1, 100, 20, 70) == 0
    check textAreaRowAtY(3, 1, 100, 20, 121) == 2
    check textAreaRowAtY(3, 1, 100, 20, 500) == 2

  test "display start follows the cursor only when needed":
    checkClose(textAreaDisplayStartRowForCursor(10, 1, 60, 20, 0), 0)
    checkClose(textAreaDisplayStartRowForCursor(10, 3, 60, 20, 0), 1)
    checkClose(textAreaDisplayStartRowForCursor(10, 2, 60, 20, 5), 2)
    checkClose(textAreaDisplayStartRowForCursor(2, 1, 60, 20, 5), 0)

  test "scroll display start clamps to available rows":
    check textAreaVisibleRows(60, 20) == 3
    checkClose(textAreaMaxDisplayStart(10, 60, 20), 7)
    checkClose(textAreaScrollDisplayStart(10, 60, 20, 0, -3), 0)
    checkClose(textAreaScrollDisplayStart(10, 60, 20, 5, 10), 7)
    checkClose(textAreaScrollDisplayStart(2, 60, 20, 5, 1), 0)

  test "line start and end use the cursor row":
    let rows = @[textRow(0, 4, 5), textRow(5, 9, 10), textRow(10, 10, -1, width = 0)]

    check textAreaLineStartCursor(rows, 7) == 5
    check textAreaLineEndCursor(rows, 7) == 10
    check textAreaLineStartCursor(rows, 10) == 10
    check textAreaLineEndCursor(rows, 10) == 10

  test "row delta clamps at document bounds":
    check textAreaRowByDelta(4, 1, -10) == 0
    check textAreaRowByDelta(4, 1, 2) == 3
    check textAreaRowByDelta(4, 3, 1) == 3
    check textAreaRowByDelta(0, 3, 1) == 0

  test "selection spans are clipped to each wrapped row":
    let rows = @[textRow(0, 4, 5), textRow(5, 9, 10), textRow(10, 12, -1)]
    let selection = TextSelection(startPos: 3, endPos: 11)
    let first = textAreaSelectionForRow(rows[0], selection)
    let middle = textAreaSelectionForRow(rows[1], selection)
    let last = textAreaSelectionForRow(rows[2], selection)

    check first.active
    check first.startPos == 3
    check first.endPos == 5
    check middle.active
    check middle.startPos == 5
    check middle.endPos == 10
    check last.active
    check last.startPos == 10
    check last.endPos == 11

  test "mouse x maps to row-local cursor positions":
    let glyphs = fixedGlyphs(4, 10)

    check textAreaCursorPosAt(glyphs, 5, 9, 99, 100) == 5
    check textAreaCursorPosAt(glyphs, 5, 9, 116, 100) == 7
    check textAreaCursorPosAt(glyphs, 5, 9, 500, 100) == 9
    checkClose(textAreaCursorX(glyphs, 5, 5, 100), 100)
    checkClose(textAreaCursorX(glyphs, 5, 7, 100), 120)
    checkClose(textAreaCursorX(glyphs, 5, 9, 100), 140)
