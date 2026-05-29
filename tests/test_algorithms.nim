import std/math
import std/options
import std/unittest

import glfw

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
