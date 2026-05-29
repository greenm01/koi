import std/math
import std/tables
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
    checkRect(nextWidgetBounds(), rect(13, 0, 143, 21))
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
    checkRect(layoutSpaceRatioRect(0.25, 0.5, 0.5, 0.5), rect(80, 60, 160, 60))
    checkRect(layoutSpaceRatioRect(-1, 0.5, 3, 1), rect(0, 60, 320, 60))
    let (sx, sy) = layoutSpaceToScreen(10, 15)
    checkClose(sx, 30)
    checkClose(sy, 45)

    let (lx, ly) = layoutSpaceToLocal(30, 45)
    checkClose(lx, 10)
    checkClose(ly, 15)

    checkRect(layoutSpaceRectToScreen(rect(1, 2, 3, 4)), rect(21, 32, 3, 4))
    checkRect(layoutSpaceRectToLocal(rect(21, 32, 3, 4)), rect(1, 2, 3, 4))

    endLayout()
    let (outerX, outerY) = layoutSpaceToScreen(1, 2)
    checkClose(outerX, 21)
    checkClose(outerY, 32)
    checkClose(g_uiState.autoLayoutState.y, 132)

suite "layout frame integration":
  test "frame root caches registered slot rects":
    resetLayout()
    beginFrameLayout()

    discard layoutSlot(10, rect(7, 8, 30, 11))
    finishFrameLayout()

    checkRect(g_uiState.layoutRects[10], rect(7, 8, 30, 11))

  test "slots read previous frame rects and draw with current solved rects":
    resetLayout()
    beginFrameLayout()
    discard layoutSlot(11, rect(10, 20, 30, 40))
    finishFrameLayout()

    beginFrameLayout()
    let slot = layoutSlot(11, rect(50, 60, 70, 80))
    checkRect(slot.previousBounds, rect(10, 20, 30, 40))

    var drawn = rect(0, 0, 0, 0)
    addLayoutDrawLayer(layerDefault, slot.nodeId, vg, bounds):
      drawn = bounds

    finishFrameLayout()
    g_drawLayers.draw(g_nvgContext)

    checkRect(drawn, rect(50, 60, 70, 80))
    checkRect(g_uiState.layoutRects[11], rect(50, 60, 70, 80))

  test "row slots flow through the row node and keep centered row bounds":
    resetLayout()
    beginFrameLayout()

    beginRowLayout(30, [col(100), colDynamic()])
    autoLayoutPre()
    discard layoutSlot(12, autoLayoutNextBounds())
    autoLayoutPost()
    endLayout()
    finishFrameLayout()

    checkRect(g_uiState.layoutRects[12], rect(13, 5, 100, 21))

  test "frame layout installs default text measurement":
    resetLayout()
    beginFrameLayout()

    check g_uiState.layoutArena.measureText != nil
    let m =
      g_uiState.layoutArena.measureText("wide word", 10, "sans-bold", LayoutInfinity)
    checkClose(m.minWidth, 20)
    checkClose(m.prefWidth, 45)
    checkClose(m.lineHeight, 14)
    check m.lineCount == 1

suite "unified layout solver":
  test "horizontal flow distributes remaining space to grow children":
    var arena: LayoutArena
    arena.initLayoutArena()

    let root = arena.beginLayoutNode(
      layoutNode(width = fixed(300), height = fixed(100), direction = ldLeftToRight)
    )
    let first = arena.addLayoutNode(layoutNode(width = fixed(100), height = grow()))
    let second = arena.addLayoutNode(layoutNode(width = grow(), height = grow()))
    let third = arena.addLayoutNode(layoutNode(width = grow(), height = grow()))
    discard arena.endLayoutNode()

    arena.solveLayout(rect(0, 0, 300, 100), root)

    checkRect(arena.layoutRect(first), rect(0, 0, 100, 100))
    checkRect(arena.layoutRect(second), rect(100, 0, 100, 100))
    checkRect(arena.layoutRect(third), rect(200, 0, 100, 100))
    checkClose(arena.nodes[root.int].contentSize.w, 300)
    checkClose(arena.nodes[root.int].contentSize.h, 100)

  test "padding, gap, percent, fixed, and grow resolve on one axis":
    var arena: LayoutArena
    arena.initLayoutArena()

    let root = arena.beginLayoutNode(
      layoutNode(
        width = fixed(400),
        height = fixed(50),
        direction = ldLeftToRight,
        padding = padding(10, 10, 0, 0),
        childGap = 5,
      )
    )
    let ratio = arena.addLayoutNode(layoutNode(width = percent(0.25), height = grow()))
    let exact = arena.addLayoutNode(layoutNode(width = fixed(50), height = grow()))
    let fill = arena.addLayoutNode(layoutNode(width = grow(), height = grow()))
    let overlay = arena.addLayoutNode(
      layoutNode(width = fixed(20), height = fixed(20), placement = manual(1, 2))
    )
    discard arena.endLayoutNode()

    arena.solveLayout(rect(0, 0, 400, 50), root)

    checkRect(arena.layoutRect(ratio), rect(10, 0, 92.5, 50))
    checkRect(arena.layoutRect(exact), rect(107.5, 0, 50, 50))
    checkRect(arena.layoutRect(fill), rect(162.5, 0, 227.5, 50))
    checkRect(arena.layoutRect(overlay), rect(1, 2, 20, 20))

  test "fit sizing wraps children and padding":
    var arena: LayoutArena
    arena.initLayoutArena()

    let root = arena.beginLayoutNode(
      layoutNode(
        width = fixed(100),
        height = fit(),
        direction = ldTopToBottom,
        padding = padding(0, 0, 4, 4),
        childGap = 5,
      )
    )
    let first = arena.addLayoutNode(layoutNode(width = grow(), height = fixed(20)))
    let second = arena.addLayoutNode(layoutNode(width = grow(), height = fixed(30)))
    discard arena.endLayoutNode()

    arena.solveLayout(rect(0, 0, 100, 0), root)

    checkRect(arena.layoutRect(root), rect(0, 0, 100, 63))
    checkRect(arena.layoutRect(first), rect(0, 4, 100, 20))
    checkRect(arena.layoutRect(second), rect(0, 29, 100, 30))

  test "alignment and manual placement use solved parent rects":
    var arena: LayoutArena
    arena.initLayoutArena()

    let root = arena.beginLayoutNode(
      layoutNode(
        width = fixed(120),
        height = fixed(80),
        direction = ldLeftToRight,
        alignMain = laCenter,
        alignCross = lcaEnd,
      )
    )
    let centered =
      arena.addLayoutNode(layoutNode(width = fixed(40), height = fixed(20)))
    let manualChild = arena.addLayoutNode(
      layoutNode(width = fixed(10), height = fixed(10), placement = manual(7, 9))
    )
    discard arena.endLayoutNode()

    arena.solveLayout(rect(0, 0, 120, 80), root)

    checkRect(arena.layoutRect(centered), rect(40, 60, 40, 20))
    checkRect(arena.layoutRect(manualChild), rect(7, 9, 10, 10))

  test "fixed-width text wraps and updates a fit-height parent":
    proc measureText(
        text: string, fontSize: float, fontFace: string, maxWidth: float
    ): TextMeasure =
      let lineCount =
        if maxWidth >= LayoutInfinity * 0.5:
          1
        else:
          max(1, ceil(100.0 / maxWidth).int)
      TextMeasure(minWidth: 20, prefWidth: 100, lineHeight: 10, lineCount: lineCount)

    var arena: LayoutArena
    arena.initLayoutArena(measureText)

    let root = arena.beginLayoutNode(layoutNode(width = fixed(50), height = fit()))
    let text = arena.addLayoutNode(
      layoutNode(kind = lnkText, width = grow(), height = fit(), text = "wrapped")
    )
    discard arena.endLayoutNode()

    arena.solveLayout(rect(0, 0, 50, 0), root)

    checkRect(arena.layoutRect(root), rect(0, 0, 50, 20))
    checkRect(arena.layoutRect(text), rect(0, 0, 50, 20))
    checkClose(arena.nodes[root.int].contentSize.h, 20)

  test "fit-height bubbles through nested containers":
    proc measureText(
        text: string, fontSize: float, fontFace: string, maxWidth: float
    ): TextMeasure =
      TextMeasure(
        minWidth: 10,
        prefWidth: 60,
        lineHeight: 8,
        lineCount: if maxWidth >= 30: 2 else: 3,
      )

    var arena: LayoutArena
    arena.initLayoutArena(measureText)

    let root = arena.beginLayoutNode(layoutNode(width = fixed(30), height = fit()))
    let group = arena.beginLayoutNode(layoutNode(width = grow(), height = fit()))
    let text = arena.addLayoutNode(
      layoutNode(kind = lnkText, width = grow(), height = fit(), text = "nested")
    )
    discard arena.endLayoutNode()
    discard arena.endLayoutNode()

    arena.solveLayout(rect(0, 0, 30, 0), root)

    checkRect(arena.layoutRect(root), rect(0, 0, 30, 16))
    checkRect(arena.layoutRect(group), rect(0, 0, 30, 16))
    checkRect(arena.layoutRect(text), rect(0, 0, 30, 16))

  test "overflow shrinks fit and grow children toward minimums":
    var arena: LayoutArena
    arena.initLayoutArena()

    let root = arena.beginLayoutNode(
      layoutNode(width = fixed(100), height = fixed(20), direction = ldLeftToRight)
    )
    let exact = arena.addLayoutNode(layoutNode(width = fixed(70), height = fixed(20)))

    var fitChild = layoutNode(width = fit(min = 20), height = fixed(20))
    fitChild.intrinsicMin = size(20, 20)
    fitChild.intrinsicPref = size(60, 20)
    let fitted = arena.addLayoutNode(fitChild)

    var growChild = layoutNode(width = grow(min = 10), height = fixed(20))
    growChild.intrinsicMin = size(40, 20)
    growChild.intrinsicPref = size(40, 20)
    let grown = arena.addLayoutNode(growChild)
    discard arena.endLayoutNode()

    arena.solveLayout(rect(0, 0, 100, 20), root)

    checkRect(arena.layoutRect(exact), rect(0, 0, 70, 20))
    checkRect(arena.layoutRect(fitted), rect(70, 0, 20, 20))
    checkRect(arena.layoutRect(grown), rect(90, 0, 10, 20))

suite "NEP1 naming aliases":
  test "style aliases and compatibility wrappers refer to the same defaults":
    let original = defaultButtonStyle()
    var changed = defaultButtonStyle()
    changed.cornerRadius = original.cornerRadius + 1

    defaultButtonStyle(changed)
    checkClose(getDefaultButtonStyle().cornerRadius, changed.cornerRadius)

    setDefaultButtonStyle(original)
    checkClose(defaultButtonStyle().cornerRadius, original.cornerRadius)

  test "menu style aliases preserve copy and borrow behavior":
    let original = defaultMenuStyle()

    try:
      var changed = defaultMenuStyle()
      changed.menuBarHeight = original.menuBarHeight + 3
      changed.button.cornerRadius = original.button.cornerRadius + 2

      defaultMenuStyle(changed)
      checkClose(getDefaultMenuStyle().menuBarHeight, changed.menuBarHeight)
      checkClose(
        borrowDefaultMenuStyle().button.cornerRadius, changed.button.cornerRadius
      )

      var copied = defaultMenuStyle()
      copied.button.cornerRadius = changed.button.cornerRadius + 10
      checkClose(
        borrowDefaultMenuStyle().button.cornerRadius, changed.button.cornerRadius
      )

      borrowDefaultMenuStyle().menuItemHeight = original.menuItemHeight + 4
      checkClose(defaultMenuStyle().menuItemHeight, original.menuItemHeight + 4)
    finally:
      setDefaultMenuStyle(original)

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
