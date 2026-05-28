import std/math
import std/unittest

import koi/core
import koi/defaults
import koi/layout
import koi/rect
import koi/types

const Epsilon = 0.0001

template checkClose(actual, expected: float) =
  check abs(actual - expected) < Epsilon

template checkRect(actual, expected: Rect) =
  checkClose(actual.x, expected.x)
  checkClose(actual.y, expected.y)
  checkClose(actual.w, expected.w)
  checkClose(actual.h, expected.h)

proc resetLayout(params: AutoLayoutParams = DefaultAutoLayoutParams) =
  g_uiState = UIState.default
  g_uiState.winWidth = 1000
  g_uiState.winHeight = 1000
  g_uiState.drawOffsetStack = @[DrawOffset(ox: 0, oy: 0)]
  initAutoLayout(params)

suite "auto-layout":
  test "standard columns advance with default sizing":
    resetLayout()

    autoLayoutPre()
    checkRect(autoLayoutNextBounds(), rect(13, 0, 143, 21))
    autoLayoutPost()

    autoLayoutPre()
    checkRect(autoLayoutNextBounds(), rect(173, 0, 143, 21))
    autoLayoutPost()

    checkClose(g_uiState.autoLayoutState.y, 33)

  test "next item width and height apply to the next shorthand item":
    resetLayout()

    autoLayoutPre()
    autoLayoutPost()

    nextItemWidth(70)
    nextItemHeight(13)
    autoLayoutPre()

    checkRect(autoLayoutNextBounds(), rect(173, 4, 70, 13))
    autoLayoutPost()

  test "next row height applies once":
    resetLayout()

    nextRowHeight(40)
    autoLayoutPre()
    checkRect(autoLayoutNextBounds(), rect(13, 10, 143, 21))
    autoLayoutPost(section = true)

    autoLayoutPre()
    checkRect(autoLayoutNextBounds(), rect(13, 57, 143, 21))

suite "row layout":
  test "legacy fixed then dynamic row keeps source-compatible call shape":
    resetLayout()

    beginRowLayout(30)
    beginColumn(cmStatic, 150)
    autoLayoutPre()
    checkRect(autoLayoutNextBounds(), rect(13, 5, 150, 21))
    autoLayoutPost()
    endColumn()

    beginColumn(cmDynamic)
    autoLayoutPre()
    checkRect(autoLayoutNextBounds(), rect(163, 5, 166, 21))
    autoLayoutPost()
    endColumn()
    endLayout()

  test "predeclared fixed and dynamic row resolves before widgets consume it":
    resetLayout()

    beginRowLayout(30, [col(150), colDynamic(), colDynamic()])
    autoLayoutPre()
    checkRect(autoLayoutNextBounds(), rect(13, 5, 150, 21))
    autoLayoutPost()

    autoLayoutPre()
    checkRect(autoLayoutNextBounds(), rect(163, 5, 76.5, 21))
    autoLayoutPost()

    autoLayoutPre()
    checkRect(autoLayoutNextBounds(), rect(239.5, 5, 76.5, 21))
    autoLayoutPost()
    endLayout()

  test "predeclared ratio row uses available row width":
    resetLayout()

    beginRowLayout(30, [colRatio(0.25), colRatio(0.75)])
    autoLayoutPre()
    checkRect(autoLayoutNextBounds(), rect(13, 5, 75.75, 21))
    autoLayoutPost()

    autoLayoutPre()
    checkRect(autoLayoutNextBounds(), rect(88.75, 5, 227.25, 21))
    autoLayoutPost()
    endLayout()

  test "nextLayoutColumn consumes one row column":
    resetLayout()

    beginRowLayout(30, [col(40), col(80)])
    nextLayoutColumn()
    autoLayoutPre()
    checkRect(autoLayoutNextBounds(), rect(53, 5, 80, 21))
    autoLayoutPost()
    endLayout()

suite "layout space":
  test "space exposes local bounds and converts coordinates through draw offset":
    resetLayout()
    g_uiState.drawOffsetStack = @[DrawOffset(ox: 20, oy: 30)]

    beginSpaceLayout(120)

    checkRect(layoutSpaceBounds(), rect(0, 0, 320, 120))
    let (sx, sy) = layoutSpaceToScreen(10, 15)
    checkClose(sx, 30)
    checkClose(sy, 45)

    let (lx, ly) = layoutSpaceToLocal(30, 45)
    checkClose(lx, 10)
    checkClose(ly, 15)

    checkRect(layoutSpaceRectToScreen(rect(1, 2, 3, 4)), rect(21, 32, 3, 4))
    checkRect(layoutSpaceRectToLocal(rect(21, 32, 3, 4)), rect(1, 2, 3, 4))

    endLayout()
    checkClose(g_uiState.autoLayoutState.y, 132)
