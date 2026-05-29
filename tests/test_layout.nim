import std/math
import std/unittest

import koi/core
import koi/defaults
import koi/drawing
import koi/input
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

  test "spacer consumes the next shorthand slot":
    resetLayout()

    spacer()
    autoLayoutPre()
    checkRect(autoLayoutNextBounds(), rect(173, 0, 143, 21))

  test "height spacer consumes a whole row":
    resetLayout()

    spacer(40)
    autoLayoutPre()
    checkRect(autoLayoutNextBounds(), rect(13, 57, 143, 21))

  test "ratio helper clamps pixel ratios":
    checkClose(ratioFromPixels(25, 100), 0.25)
    checkClose(ratioFromPixels(-10, 100), 0)
    checkClose(ratioFromPixels(120, 100), 1)
    checkClose(ratioFromPixels(10, 0), 0)

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

  test "predeclared variable row preserves minimum and grows":
    resetLayout()

    beginRowLayout(30, [col(100), colVariable(50), colDynamic()])
    autoLayoutPre()
    checkRect(autoLayoutNextBounds(), rect(13, 5, 100, 21))
    autoLayoutPost()

    autoLayoutPre()
    checkRect(autoLayoutNextBounds(), rect(113, 5, 126.5, 21))
    autoLayoutPost()

    autoLayoutPre()
    checkRect(autoLayoutNextBounds(), rect(239.5, 5, 76.5, 21))
    autoLayoutPost()
    endLayout()

  test "variable row clamps to minimum when space is tight":
    var params = DefaultAutoLayoutParams
    params.rowWidth = 90
    resetLayout(params)

    beginRowLayout(30, [colVariable(80), colDynamic()])
    autoLayoutPre()
    checkRect(autoLayoutNextBounds(), rect(13, 5, 80, 21))
    autoLayoutPost()

    autoLayoutPre()
    checkRect(autoLayoutNextBounds(), rect(93, 5, 0, 21))
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

suite "NEP1 naming aliases":
  test "style aliases and compatibility wrappers refer to the same defaults":
    let original = defaultButtonStyle()
    var changed = defaultButtonStyle()
    changed.cornerRadius = original.cornerRadius + 1

    defaultButtonStyle(changed)
    checkClose(getDefaultButtonStyle().cornerRadius, changed.cornerRadius)

    setDefaultButtonStyle(original)
    checkClose(defaultButtonStyle().cornerRadius, original.cornerRadius)

  test "borrowed default styles avoid per-call deep copies":
    let
      originalButton = defaultButtonStyle()
      originalTextArea = defaultTextAreaStyle()

    try:
      var changedButton = defaultButtonStyle()
      changedButton.cornerRadius = originalButton.cornerRadius + 2

      defaultButtonStyle(changedButton)
      checkClose(borrowDefaultButtonStyle().cornerRadius, changedButton.cornerRadius)

      var copiedButton = defaultButtonStyle()
      copiedButton.label.padHoriz = borrowDefaultButtonStyle().label.padHoriz + 10
      checkClose(
        borrowDefaultButtonStyle().label.padHoriz, originalButton.label.padHoriz
      )

      borrowDefaultButtonStyle().label.padHoriz = originalButton.label.padHoriz + 5
      checkClose(defaultButtonStyle().label.padHoriz, originalButton.label.padHoriz + 5)

      let borrowedTextArea = borrowDefaultTextAreaStyle()
      borrowedTextArea.scrollBarStyleNormal.thumbPad =
        originalTextArea.scrollBarStyleNormal.thumbPad + 3
      checkClose(
        defaultTextAreaStyle().scrollBarStyleNormal.thumbPad,
        originalTextArea.scrollBarStyleNormal.thumbPad + 3,
      )
    finally:
      setDefaultButtonStyle(originalButton)
      setDefaultTextAreaStyle(originalTextArea)

  test "state aliases preserve old wrapper behavior":
    g_uiState = UIState.default

    scale(1.5)
    checkClose(getScale(), 1.5)
    setScale(2.0)
    checkClose(scale(), 2.0)

    focusCaptured(true)
    check focusCaptured()
    setFocusCaptured(false)
    check not focusCaptured()

    requestFrames(3)
    check g_uiState.framesLeft == 3
    setFramesLeft(4)
    check g_uiState.framesLeft == 4

    currentLayer(layerPopup)
    check currentLayer() == layerPopup
    setCurrentLayer(layerDialog)
    check currentLayer() == layerDialog

    markHot(12)
    check isHot(12)
    setHot(13)
    check isHot(13)

    markActive(21)
    check isActive(21)
    setActive(22)
    check isActive(22)

    hitClip(1, 2, 3, 4)
    checkRect(g_uiState.hitClipRect, rect(1, 2, 3, 4))
    setHitClip(5, 6, 7, 8)
    checkRect(g_uiState.hitClipRect, rect(5, 6, 7, 8))

    markEventHandled()
    check eventHandled()
    g_uiState.eventHandled = false
    setEventHandled()
    check eventHandled()

    useNextId("preferred")
    check nextId("ignored.nim", 1) == hashId("preferred")
    setNextId("compat")
    check getNextId("ignored.nim", 1) == hashId("compat")
