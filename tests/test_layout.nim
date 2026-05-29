import std/math
import std/strutils
import std/tables
import std/unittest

import nanovg

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

template checkColorClose(actual, expected: Color) =
  checkClose(actual.r, expected.r)
  checkClose(actual.g, expected.g)
  checkClose(actual.b, expected.b)
  checkClose(actual.a, expected.a)

proc hasLineContaining(lines: seq[string], needle: string): bool =
  for line in lines:
    if needle in line:
      return true

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

  test "space children solve relative to the space node":
    resetLayout()
    g_uiState.drawOffsetStack = @[DrawOffset(ox: 20, oy: 30)]
    beginFrameLayout()

    beginSpaceLayout(120)
    let spaceNode = g_uiState.layoutStack[^1].nodeId
    let (x, y) = addDrawOffset(10, 15)
    discard layoutSlot(25, rect(x, y, 30, 20))
    endLayout()
    finishFrameLayout()

    checkRect(g_uiState.layoutArena.layoutRect(spaceNode), rect(20, 30, 320, 120))
    checkRect(g_uiState.layoutRects[25], rect(30, 45, 30, 20))

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

  test "predeclared row columns register solver-native sizes":
    resetLayout()
    beginFrameLayout()

    beginRowLayout(30, [col(100), colDynamic(), colRatio(0.25), colVariable(50)])

    autoLayoutPre()
    let fixedSlot = layoutSlot(13, autoLayoutNextBounds())
    autoLayoutPost()

    autoLayoutPre()
    let dynamicSlot = layoutSlot(14, autoLayoutNextBounds())
    autoLayoutPost()

    autoLayoutPre()
    let ratioSlot = layoutSlot(15, autoLayoutNextBounds())
    autoLayoutPost()

    autoLayoutPre()
    let variableSlot = layoutSlot(16, autoLayoutNextBounds())
    autoLayoutPost()

    endLayout()
    finishFrameLayout()

    check g_uiState.layoutArena.nodes[fixedSlot.nodeId.int].width.kind == lskFixed
    check g_uiState.layoutArena.nodes[dynamicSlot.nodeId.int].width.kind == lskGrow
    check g_uiState.layoutArena.nodes[ratioSlot.nodeId.int].width.kind == lskPercent
    check g_uiState.layoutArena.nodes[variableSlot.nodeId.int].width.kind == lskGrow

    checkRect(g_uiState.layoutRects[13], rect(13, 5, 100, 21))
    checkRect(g_uiState.layoutRects[14], rect(113, 5, 38.625, 21))
    checkRect(g_uiState.layoutRects[15], rect(151.625, 5, 75.75, 21))
    checkRect(g_uiState.layoutRects[16], rect(227.375, 5, 88.625, 21))

  test "imperative row columns register solver-native sizes":
    resetLayout()
    beginFrameLayout()

    beginRowLayout(30)

    beginColumn(cmStatic, 150)
    autoLayoutPre()
    let fixedSlot = layoutSlot(19, autoLayoutNextBounds())
    autoLayoutPost()
    endColumn()

    beginColumn(cmDynamic)
    autoLayoutPre()
    let dynamicSlot = layoutSlot(20, autoLayoutNextBounds())
    autoLayoutPost()
    endColumn()

    endLayout()
    finishFrameLayout()

    check g_uiState.layoutArena.nodes[fixedSlot.nodeId.int].width.kind == lskFixed
    check g_uiState.layoutArena.nodes[dynamicSlot.nodeId.int].width.kind == lskGrow
    checkRect(fixedSlot.bounds, rect(13, 5, 150, 21))
    checkRect(dynamicSlot.bounds, rect(163, 5, 166, 21))
    checkRect(g_uiState.layoutRects[19], rect(13, 5, 150, 21))
    checkRect(g_uiState.layoutRects[20], rect(163, 5, 153, 21))

  test "imperative ratio and variable columns use solver sizing":
    resetLayout()
    beginFrameLayout()

    beginRowLayout(30)

    beginColumn(cmRatio, 0.25)
    autoLayoutPre()
    let ratioSlot = layoutSlot(21, autoLayoutNextBounds())
    autoLayoutPost()
    endColumn()

    beginColumn(cmVariable, 80)
    autoLayoutPre()
    let variableSlot = layoutSlot(22, autoLayoutNextBounds())
    autoLayoutPost()
    endColumn()

    beginColumn(cmDynamic)
    autoLayoutPre()
    let dynamicSlot = layoutSlot(23, autoLayoutNextBounds())
    autoLayoutPost()
    endColumn()

    endLayout()
    finishFrameLayout()

    check g_uiState.layoutArena.nodes[ratioSlot.nodeId.int].width.kind == lskPercent
    check g_uiState.layoutArena.nodes[variableSlot.nodeId.int].width.kind == lskGrow
    check g_uiState.layoutArena.nodes[dynamicSlot.nodeId.int].width.kind == lskGrow
    checkRect(g_uiState.layoutRects[21], rect(13, 5, 75.75, 21))
    checkRect(g_uiState.layoutRects[22], rect(88.75, 5, 153.625, 21))
    checkRect(g_uiState.layoutRects[23], rect(242.375, 5, 73.625, 21))

  test "imperative skipped columns preserve solved flow":
    resetLayout()
    beginFrameLayout()

    beginRowLayout(30)

    beginColumn(cmStatic, 40)
    spacer()
    endColumn()

    beginColumn(cmStatic, 80)
    autoLayoutPre()
    discard layoutSlot(24, autoLayoutNextBounds())
    autoLayoutPost()
    endColumn()

    endLayout()
    finishFrameLayout()

    checkRect(g_uiState.layoutRects[24], rect(53, 5, 80, 21))

  test "row spacer preserves skipped column in solved layout":
    resetLayout()
    beginFrameLayout()

    beginRowLayout(30, [col(40), col(60), col(80)])
    spacer()
    autoLayoutPre()
    discard layoutSlot(17, autoLayoutNextBounds())
    autoLayoutPost()
    endLayout()
    finishFrameLayout()

    checkRect(g_uiState.layoutRects[17], rect(53, 5, 60, 21))

  test "nextLayoutColumn preserves skipped column in solved layout":
    resetLayout()
    beginFrameLayout()

    beginRowLayout(30, [col(40), col(80)])
    nextLayoutColumn()
    autoLayoutPre()
    discard layoutSlot(18, autoLayoutNextBounds())
    autoLayoutPost()
    endLayout()
    finishFrameLayout()

    checkRect(g_uiState.layoutRects[18], rect(53, 5, 80, 21))

  test "space in predeclared row consumes one solved column":
    resetLayout()
    beginFrameLayout()

    beginRowLayout(30, [col(40), col(60), col(80)])
    beginSpaceLayout(30)
    let (x, y) = addDrawOffset(5, 5)
    discard layoutSlot(26, rect(x, y, 10, 10))
    endLayout()

    autoLayoutPre()
    discard layoutSlot(27, autoLayoutNextBounds())
    autoLayoutPost()

    endLayout()
    finishFrameLayout()

    checkRect(g_uiState.layoutRects[26], rect(18, 5, 10, 10))
    checkRect(g_uiState.layoutRects[27], rect(53, 5, 60, 21))

  test "space in imperative row consumes one solved column":
    resetLayout()
    beginFrameLayout()

    beginRowLayout(30)

    beginColumn(cmStatic, 40)
    beginSpaceLayout(30)
    let (x, y) = addDrawOffset(5, 5)
    discard layoutSlot(28, rect(x, y, 10, 10))
    endLayout()
    endColumn()

    beginColumn(cmStatic, 80)
    autoLayoutPre()
    discard layoutSlot(29, autoLayoutNextBounds())
    autoLayoutPost()
    endColumn()

    endLayout()
    finishFrameLayout()

    checkRect(g_uiState.layoutRects[28], rect(18, 5, 10, 10))
    checkRect(g_uiState.layoutRects[29], rect(53, 5, 80, 21))

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

  test "auto-layout root is created at the active draw offset":
    resetLayout()
    g_uiState.drawOffsetStack = @[DrawOffset(ox: 20, oy: 30)]
    beginFrameLayout()

    autoLayoutPre()
    discard layoutSlot(30, autoLayoutNextBounds())
    autoLayoutPost()
    finishFrameLayout()

    let root = g_uiState.autoLayoutState.autoRoot
    check not root.isNull
    checkClose(g_uiState.layoutArena.layoutRect(root).x, 20)
    checkClose(g_uiState.layoutArena.layoutRect(root).y, 30)
    checkClose(g_uiState.layoutArena.layoutRect(root).w, 320)
    check g_uiState.layoutArena.layoutRect(root).h > 0
    checkRect(g_uiState.layoutRects[30], rect(33, 30, 143, 21))

  test "wrapped auto-layout text grows its row and shifts later widgets":
    var params = DefaultAutoLayoutParams
    params.itemsPerRow = 1
    params.rowWidth = 60
    params.leftPad = 0
    params.rightPad = 0
    params.rowPad = 5
    params.sectionPad = 0
    params.defaultRowHeight = 20
    params.defaultItemHeight = 20
    resetLayout(params)
    beginFrameLayout()
    g_uiState.layoutArena.measureText = proc(
        text: string, fontSize: float, fontFace: string, maxWidth: float
    ): TextMeasure =
      TextMeasure(
        minWidth: 10,
        prefWidth: 100,
        lineHeight: 15,
        lineCount: if maxWidth >= 60: 2 else: 3,
      )

    autoLayoutPre()
    discard textLayoutSlot(
      31, autoLayoutNextBounds(), "wrapped label", borrowDefaultLabelStyle()
    )
    autoLayoutPost()

    autoLayoutPre()
    checkRect(autoLayoutNextBounds(), rect(0, 25, 60, 20))
    discard layoutSlot(32, autoLayoutNextBounds())
    autoLayoutPost()
    finishFrameLayout()

    checkRect(g_uiState.layoutRects[31], rect(0, 0, 60, 30))
    checkRect(g_uiState.layoutRects[32], rect(0, 35, 60, 20))

  test "multi-column auto row grows to tallest text and centers fixed sibling":
    var params = DefaultAutoLayoutParams
    params.itemsPerRow = 2
    params.rowWidth = 100
    params.leftPad = 0
    params.rightPad = 0
    params.rowPad = 0
    params.sectionPad = 0
    params.defaultRowHeight = 20
    params.defaultItemHeight = 10
    resetLayout(params)
    beginFrameLayout()
    g_uiState.layoutArena.measureText = proc(
        text: string, fontSize: float, fontFace: string, maxWidth: float
    ): TextMeasure =
      TextMeasure(
        minWidth: 10,
        prefWidth: 100,
        lineHeight: 15,
        lineCount: if maxWidth >= 50: 2 else: 3,
      )

    autoLayoutPre()
    discard textLayoutSlot(
      41, autoLayoutNextBounds(), "wrapped label", borrowDefaultLabelStyle()
    )
    autoLayoutPost()

    autoLayoutPre()
    discard layoutSlot(42, autoLayoutNextBounds())
    autoLayoutPost()
    finishFrameLayout()

    checkRect(g_uiState.layoutRects[41], rect(0, 0, 50, 30))
    checkRect(g_uiState.layoutRects[42], rect(50, 10, 50, 10))

  test "auto-layout spacers preserve legacy row group and section y positions":
    var params = DefaultAutoLayoutParams
    params.itemsPerRow = 1
    params.rowWidth = 50
    params.leftPad = 0
    params.rightPad = 0
    params.rowPad = 5
    params.rowGroupPad = 11
    params.sectionPad = 7
    params.defaultRowHeight = 20
    params.defaultItemHeight = 10
    resetLayout(params)
    beginFrameLayout()

    autoLayoutPre()
    discard layoutSlot(51, autoLayoutNextBounds())
    autoLayoutPost()

    beginGroup()
    autoLayoutPre()
    discard layoutSlot(52, autoLayoutNextBounds())
    autoLayoutPost(section = true)

    autoLayoutPre()
    discard layoutSlot(53, autoLayoutNextBounds())
    autoLayoutPost()
    finishFrameLayout()

    checkRect(g_uiState.layoutRects[51], rect(0, 5, 50, 10))
    checkRect(g_uiState.layoutRects[52], rect(0, 48, 50, 10))
    checkRect(g_uiState.layoutRects[53], rect(0, 80, 50, 10))

suite "unified layout solver":
  test "direct parent insertion flattens children before solve":
    var arena: LayoutArena
    arena.initLayoutArena()

    let root = arena.beginLayoutNode(
      layoutNode(width = fixed(100), height = fixed(30), direction = ldLeftToRight)
    )
    let nested = arena.beginLayoutNode(layoutNode(width = fixed(20), height = grow()))
    discard arena.endLayoutNode()
    let direct =
      arena.addLayoutNode(layoutNode(width = fixed(30), height = grow()), root)
    discard arena.endLayoutNode()

    arena.solveLayout(rect(0, 0, 100, 30), root)

    check arena.nodes[root.int].childCount == 2
    check int32(arena.childIndices[int(arena.nodes[root.int].firstChild)]) ==
      int32(nested)
    check int32(arena.childIndices[int(arena.nodes[root.int].firstChild) + 1]) ==
      int32(direct)
    checkRect(arena.layoutRect(nested), rect(0, 0, 20, 30))
    checkRect(arena.layoutRect(direct), rect(20, 0, 30, 30))

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

  test "scroll offset shifts child rects but preserves content size":
    var arena: LayoutArena
    arena.initLayoutArena()

    let root = arena.beginLayoutNode(layoutNode(width = fixed(100), height = fixed(60)))
    let scroller = arena.beginLayoutNode(
      layoutNode(width = fixed(50), height = fixed(20), scrollOffset = size(0, 15))
    )
    let child = arena.addLayoutNode(
      layoutNode(width = fixed(10), height = fixed(10), placement = manual(0, 40))
    )
    discard arena.endLayoutNode()
    discard arena.endLayoutNode()

    arena.solveLayout(rect(0, 0, 100, 60), root)

    checkRect(arena.layoutRect(scroller), rect(0, 0, 50, 20))
    checkRect(arena.layoutRect(child), rect(0, 25, 10, 10))
    checkClose(arena.nodes[scroller.int].contentSize.h, 50)

  test "follower nodes track target rects without contributing content size":
    var arena: LayoutArena
    arena.initLayoutArena()

    let root = arena.beginLayoutNode(layoutNode(width = fixed(100), height = fixed(80)))
    let target = arena.addLayoutNode(
      layoutNode(width = fixed(50), height = fixed(30), placement = manual(10, 20))
    )
    let follower = arena.addLayoutNode(
      layoutNode(
        width = fixed(5),
        height = fixed(10),
        placement = follow(target, lfkVerticalScrollBar),
      )
    )
    let matchFollower = arena.addLayoutNode(
      layoutNode(
        width = fixed(1), height = fixed(1), placement = follow(target, lfkMatchTarget)
      )
    )
    let insetFollower = arena.addLayoutNode(
      layoutNode(
        width = fixed(5),
        height = fixed(10),
        placement =
          follow(target, lfkVerticalScrollBar, followInset = padding(0, 0, 3, 4)),
      )
    )
    let fixedInsetFollower = arena.addLayoutNode(
      layoutNode(
        width = fixed(8),
        height = fixed(9),
        placement = follow(target, lfkInsetFixed, followInset = padding(6, 0, 7, 0)),
      )
    )
    discard arena.endLayoutNode()

    arena.solveLayout(rect(0, 0, 100, 80), root)

    checkRect(arena.layoutRect(target), rect(10, 20, 50, 30))
    checkRect(arena.layoutRect(follower), rect(55, 20, 5, 30))
    checkRect(arena.layoutRect(matchFollower), rect(10, 20, 50, 30))
    checkRect(arena.layoutRect(insetFollower), rect(55, 23, 5, 23))
    checkRect(arena.layoutRect(fixedInsetFollower), rect(16, 27, 8, 9))
    checkClose(arena.nodes[root.int].contentSize.w, 60)
    checkClose(arena.nodes[root.int].contentSize.h, 50)

  test "dropdown popup followers clamp to root without contributing content size":
    var arena: LayoutArena
    arena.initLayoutArena()

    let root = arena.beginLayoutNode(layoutNode(width = fixed(100), height = fixed(80)))
    let belowTarget = arena.addLayoutNode(
      layoutNode(width = fixed(20), height = fixed(10), placement = manual(20, 20))
    )
    let belowPopup = arena.addLayoutNode(
      layoutNode(
        width = fixed(30),
        height = fixed(10),
        placement = follow(belowTarget, lfkDropdownPopup, windowPad = 10),
      )
    )
    let edgeTarget = arena.addLayoutNode(
      layoutNode(width = fixed(20), height = fixed(10), placement = manual(70, 60))
    )
    let edgePopup = arena.addLayoutNode(
      layoutNode(
        width = fixed(40),
        height = fixed(30),
        placement = follow(edgeTarget, lfkDropdownPopup, windowPad = 10),
      )
    )
    discard arena.endLayoutNode()

    arena.solveLayout(rect(0, 0, 100, 80), root)

    checkRect(arena.layoutRect(belowPopup), rect(20, 30, 30, 10))
    checkRect(arena.layoutRect(edgePopup), rect(50, 30, 40, 30))
    checkClose(arena.nodes[root.int].contentSize.w, 90)
    checkClose(arena.nodes[root.int].contentSize.h, 70)

  test "attach placement supports node parent and root targets":
    var arena: LayoutArena
    arena.initLayoutArena()

    let root = arena.beginLayoutNode(layoutNode(width = fixed(100), height = fixed(80)))
    let target = arena.addLayoutNode(
      layoutNode(width = fixed(40), height = fixed(20), placement = manual(20, 20))
    )
    let nodeAttached = arena.addLayoutNode(
      layoutNode(
        width = fixed(10),
        height = fixed(6),
        placement = attach(target, lapBottomRight, lapTopLeft, offset = size(3, 4)),
      )
    )
    let parentAttached = arena.addLayoutNode(
      layoutNode(
        width = fixed(20),
        height = fixed(10),
        placement = attachParent(lapCenter, lapCenter),
      )
    )
    let rootAttached = arena.addLayoutNode(
      layoutNode(
        width = fixed(10),
        height = fixed(10),
        placement = attachRoot(
          lapBottomRight,
          lapBottomRight,
          offset = size(50, 0),
          windowPad = 5,
          clipToRoot = true,
        ),
      )
    )
    discard arena.endLayoutNode()

    arena.solveLayout(rect(0, 0, 100, 80), root)

    checkRect(arena.layoutRect(nodeAttached), rect(63, 44, 10, 6))
    checkRect(arena.layoutRect(parentAttached), rect(40, 35, 20, 10))
    checkRect(arena.layoutRect(rootAttached), rect(85, 65, 10, 10))
    checkClose(arena.nodes[root.int].contentSize.w, 60)
    checkClose(arena.nodes[root.int].contentSize.h, 40)

  test "aspect ratio derives flexible axes from the resolved opposite axis":
    var arena: LayoutArena
    arena.initLayoutArena()

    let root =
      arena.beginLayoutNode(layoutNode(width = fixed(200), height = fixed(200)))
    let widthDerived = arena.addLayoutNode(
      layoutNode(width = fixed(160), height = fit(), aspectRatio = 16.0 / 9.0)
    )
    let heightDerived = arena.addLayoutNode(
      layoutNode(width = fit(), height = fixed(30), aspectRatio = 2.0)
    )
    let fixedBoth = arena.addLayoutNode(
      layoutNode(width = fixed(100), height = fixed(20), aspectRatio = 1.0)
    )
    discard arena.endLayoutNode()

    arena.solveLayout(rect(0, 0, 200, 200), root)

    checkRect(arena.layoutRect(widthDerived), rect(0, 0, 160, 90))
    checkRect(arena.layoutRect(heightDerived), rect(0, 90, 60, 30))
    checkRect(arena.layoutRect(fixedBoth), rect(0, 120, 100, 20))

  test "layout errors report duplicates invalid percents and missing targets":
    var arena: LayoutArena
    arena.initLayoutArena()

    let root = arena.beginLayoutNode(
      layoutNode(width = fixed(100), height = fixed(40), direction = ldLeftToRight)
    )
    let percentChild = arena.addLayoutNode(
      layoutNode(itemId = 7, width = percent(1.5), height = fixed(10))
    )
    discard
      arena.addLayoutNode(layoutNode(itemId = 7, width = fixed(10), height = fixed(10)))
    discard arena.addLayoutNode(
      layoutNode(
        itemId = 8,
        width = fixed(10),
        height = fixed(10),
        placement = attach(LayoutNodeId(999), lapTopLeft, lapTopLeft),
      )
    )
    discard arena.endLayoutNode()

    arena.solveLayout(rect(0, 0, 100, 40), root)

    checkRect(arena.layoutRect(percentChild), rect(0, 0, 100, 10))
    check arena.errors.len == 3
    check arena.errors[0].kind == lekInvalidPercent
    check arena.errors[1].kind == lekDuplicateItemId
    check arena.errors[2].kind == lekMissingAttachTarget

  test "layout max node capacity reports and rejects overflow nodes":
    var arena: LayoutArena
    arena.initLayoutArena()
    arena.setLayoutMaxNodes(1)

    let root = arena.beginLayoutNode(layoutNode(width = fixed(100), height = fixed(40)))
    let overflow =
      arena.addLayoutNode(layoutNode(width = fixed(10), height = fixed(10)))

    check not root.isNull
    check overflow.isNull
    check arena.errors.len == 1
    check arena.errors[0].kind == lekExceededMaxNodes

  test "ending an empty arena layout stack reports an imbalance":
    var arena: LayoutArena
    arena.initLayoutArena()

    check arena.endLayoutNode().isNull
    check arena.errors.len == 1
    check arena.errors[0].kind == lekUnbalancedLayoutStack

  test "global layout error settings survive frame layout reset":
    resetLayout()
    var reported: seq[LayoutErrorKind]
    setLayoutErrorHandler(
      proc(error: LayoutError) =
        reported.add(error.kind)
    )
    setLayoutMaxNodes(1)

    beginFrameLayout()
    discard layoutSlot(71, rect(0, 0, 10, 10))
    finishFrameLayout()

    check reported == @[lekExceededMaxNodes]
    check layoutErrors().len == 1
    check layoutErrors()[0].kind == lekExceededMaxNodes

    clearLayoutErrors()
    check layoutErrors().len == 0

  test "finishFrameLayout reports and clears unclosed preset frames":
    resetLayout()
    var reported: seq[LayoutErrorKind]
    setLayoutErrorHandler(
      proc(error: LayoutError) =
        reported.add(error.kind)
    )

    beginFrameLayout()
    beginSpaceLayout(40)
    finishFrameLayout()

    check reported == @[lekUnbalancedLayoutStack]
    check layoutErrors().len == 1
    check layoutErrors()[0].kind == lekUnbalancedLayoutStack
    check g_uiState.layoutStack.len == 0
    check g_uiState.layoutArena.nodeStack.len == 0
    check drawOffset() == DrawOffset(ox: 0, oy: 0)

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

  test "layout inspector queues an overlay and tracks the hovered node":
    resetLayout()
    g_drawLayers.init()
    g_uiState.mx = 12
    g_uiState.my = 12
    setLayoutInspectorEnabled(true)

    beginFrameLayout()
    discard layoutSlot(101, rect(10, 10, 20, 20))
    finishFrameLayout()

    check layoutInspectorEnabled()
    check int32(layoutInspectorHoveredNode()) >= 0
    check g_drawLayers.layers[ord(layerGlobalOverlay)].len == 1

  test "layout inspector picks the top z-index node under the cursor":
    resetLayout()
    g_drawLayers.init()
    g_uiState.mx = 15
    g_uiState.my = 15
    setLayoutInspectorEnabled(true)

    beginFrameLayout()
    let anchor = layoutSlot(301, rect(0, 0, 10, 10))
    let high = layoutAttachSlot(
      302, rect(0, 0, 20, 20), anchor.nodeId, lapBottomRight, lapTopLeft, zIndex = 9
    )
    discard layoutSlot(303, rect(12, 12, 20, 20))
    finishFrameLayout()

    check int32(layoutInspectorHoveredNode()) == int32(high.nodeId)

  test "layout inspector detail falls back to selected node when not hovering":
    resetLayout()
    g_drawLayers.init()
    g_uiState.mx = 12
    g_uiState.my = 12
    g_uiState.mbLeftDown = true
    setLayoutInspectorEnabled(true)

    beginFrameLayout()
    let selected = layoutSlot(311, rect(10, 10, 20, 20))
    finishFrameLayout()

    check int32(layoutInspectorSelectedNode()) == int32(selected.nodeId)
    check int32(layoutInspectorDetailNode()) == int32(selected.nodeId)

    g_drawLayers.init()
    g_uiState.mx = 80
    g_uiState.my = 80
    g_uiState.mbLeftDown = false

    beginFrameLayout()
    let selectedAgain = layoutSlot(311, rect(10, 10, 20, 20))
    finishFrameLayout()

    check int32(layoutInspectorHoveredNode()) == 0
    check int32(layoutInspectorSelectedNode()) == int32(selectedAgain.nodeId)
    check int32(layoutInspectorDetailNode()) == int32(selectedAgain.nodeId)

  test "layout inspector node lines include hierarchy sizing and placement details":
    resetLayout()

    beginFrameLayout()
    let parent = g_uiState.layoutArena.beginLayoutNode(
      layoutNode(
        itemId = 401,
        width = fixed(100),
        height = fixed(50),
        direction = ldLeftToRight,
        padding = padding(1, 2, 3, 4),
        childGap = 5,
        alignMain = laCenter,
        alignCross = lcaEnd,
        scrollOffset = size(2, 3),
        placement = manual(20, 30),
      )
    )
    let child = g_uiState.layoutArena.addLayoutNode(
      layoutNode(
        itemId = 402,
        width = percent(0.5, min = 10, max = 90),
        height = grow(min = 8, max = 40),
        aspectRatio = 2,
        placement = attachParent(
          lapBottomRight,
          lapTopLeft,
          offset = size(6, 7),
          windowPad = 3,
          clipToRoot = true,
          zIndex = 4,
          capturePointer = true,
        ),
      )
    )
    discard g_uiState.layoutArena.endLayoutNode()
    finishFrameLayout()

    let parentLines = layoutInspectorNodeLines(parent)
    check parentLines.hasLineContaining("children: 1 sibling: 0")
    check parentLines.hasLineContaining("direction: ldLeftToRight")
    check parentLines.hasLineContaining("padding: 1.0, 2.0, 3.0, 4.0")
    check parentLines.hasLineContaining("gap: 5.0")
    check parentLines.hasLineContaining("align: main=laCenter cross=lcaEnd")
    check parentLines.hasLineContaining("scroll: 2.0, 3.0")
    check parentLines.hasLineContaining("placement: manual")

    let childLines = layoutInspectorNodeLines(child)
    check childLines.hasLineContaining("parents: 0 > " & $int32(parent))
    check childLines.hasLineContaining("width: percent(0.500")
    check childLines.hasLineContaining("height: grow(min=8.0, max=40.0)")
    check childLines.hasLineContaining("placement: attach")
    check childLines.hasLineContaining("attach target: latParent -1")
    check childLines.hasLineContaining(
      "attach points: target=lapBottomRight self=lapTopLeft"
    )
    check childLines.hasLineContaining("attach capture: true")
    check childLines.hasLineContaining("z-index: 4")

  test "layout inspector error lines prioritize detail-node related errors":
    resetLayout()

    beginFrameLayout()
    let badPercent = g_uiState.layoutArena.addLayoutNode(
      layoutNode(itemId = 501, width = percent(1.4), height = fixed(10)),
      g_uiState.layoutRoot,
    )
    discard g_uiState.layoutArena.addLayoutNode(
      layoutNode(itemId = 501, width = fixed(10), height = fixed(10)),
      g_uiState.layoutRoot,
    )
    discard g_uiState.layoutArena.addLayoutNode(
      layoutNode(
        itemId = 502,
        width = fixed(10),
        height = fixed(10),
        placement = attach(LayoutNodeId(999), lapTopLeft, lapTopLeft),
      ),
      g_uiState.layoutRoot,
    )
    finishFrameLayout()

    g_uiState.layoutDebug.selectedNode = badPercent
    let lines = layoutInspectorErrorLines()
    check lines.hasLineContaining("errors: 3")
    check lines.hasLineContaining("related errors:")
    check lines.hasLineContaining("lekInvalidPercent")
    check lines.hasLineContaining("lekDuplicateItemId")
    check lines.hasLineContaining("recent errors:")
    check lines.hasLineContaining("lekMissingAttachTarget")

  test "layout inspector error lines include stack imbalance diagnostics":
    resetLayout()
    g_uiState.layoutArena.initLayoutArena()
    discard g_uiState.layoutArena.endLayoutNode()

    let lines = layoutInspectorErrorLines()
    check lines.hasLineContaining("errors: 1")
    check lines.hasLineContaining("lekUnbalancedLayoutStack")

  test "attached slots follow frame-local targets and expose z-index to draws":
    resetLayout()
    g_drawLayers.init()

    beginFrameLayout()
    let anchor = layoutSlot(201, rect(20, 20, 30, 10))
    let attached = layoutAttachSlot(
      202,
      rect(0, 0, 12, 8),
      anchor.nodeId,
      lapBottomLeft,
      lapTopLeft,
      offset = size(2, 3),
      zIndex = 12,
    )
    var drawOrder: seq[int]
    addLayoutDrawLayer(layerDefault, attached.nodeId, vg, bounds):
      drawOrder.add(g_uiState.layoutArena.layoutZIndex(attached.nodeId))
      checkRect(bounds, rect(22, 33, 12, 8))
    finishFrameLayout()

    checkRect(g_uiState.layoutRects[202], rect(22, 33, 12, 8))
    check g_uiState.layoutArena.nodes[attached.nodeId.int].placement.kind == lpkAttach
    check g_drawLayers.layers[ord(layerDefault)][0].zIndex == 12

    g_drawLayers.draw(g_nvgContext)
    check drawOrder == @[12]

  test "attached containers scope child layout to the solved attached rect":
    resetLayout()

    beginFrameLayout()
    let anchor = layoutSlot(211, rect(40, 20, 20, 10))
    let container = beginLayoutAttachContainerSlotAt(
      212,
      rect(0, 0, 30, 20),
      rect(0, 0, 30, 20),
      anchor.nodeId,
      lapBottomLeft,
      lapTopLeft,
      offset = size(0, 5),
    )
    discard layoutSlot(213, rect(3, 4, 10, 6))
    endLayoutContainerSlot()
    finishFrameLayout()

    checkRect(g_uiState.layoutRects[212], rect(40, 35, 30, 20))
    checkRect(g_uiState.layoutRects[213], rect(43, 39, 10, 6))
    check g_uiState.layoutArena.nodes[container.nodeId.int].placement.kind == lpkAttach

  test "attached parent and root containers are convenience wrappers":
    resetLayout()

    beginFrameLayout()
    let parentContainer = beginLayoutAttachParentContainerSlotAt(
      221, rect(0, 0, 20, 10), rect(0, 0, 20, 10), lapCenter, lapCenter
    )
    endLayoutContainerSlot()
    let rootContainer = beginLayoutAttachRootContainerSlotAt(
      222,
      rect(0, 0, 10, 10),
      rect(0, 0, 10, 10),
      lapBottomRight,
      lapBottomRight,
      windowPad = 5,
      clipToRoot = true,
    )
    endLayoutContainerSlot()
    finishFrameLayout()

    check g_uiState.layoutArena.nodes[parentContainer.nodeId.int].placement.attach.targetKind ==
      latParent
    check g_uiState.layoutArena.nodes[rootContainer.nodeId.int].placement.attach.targetKind ==
      latRoot
    checkRect(g_uiState.layoutRects[221], rect(490, 495, 20, 10))
    checkRect(g_uiState.layoutRects[222], rect(985, 985, 10, 10))

  test "attached capture pointer containers temporarily scope hit testing":
    resetLayout()
    resetHitClip()
    g_uiState.layoutRects[231] = rect(20, 20, 30, 20)
    g_uiState.focusCaptured = true
    g_uiState.mx = 25
    g_uiState.my = 25

    beginFrameLayout()
    discard beginLayoutAttachRootContainerSlotAt(
      231,
      rect(20, 20, 30, 20),
      rect(20, 20, 30, 20),
      lapTopLeft,
      lapTopLeft,
      capturePointer = true,
    )

    check not g_uiState.focusCaptured
    check isHit(20, 20, 30, 20)
    check not isHit(0, 0, 10, 10)

    endLayoutContainerSlot()
    finishFrameLayout()

    check g_uiState.focusCaptured
    checkRect(g_uiState.hitClipRect, rect(0, 0, 1000, 1000))

  test "draw layers render lower z-index entries first while preserving insertion order":
    g_drawLayers.init()
    var order: seq[int]

    addDrawLayerZ(layerDefault, 10, vg):
      order.add(10)
    addDrawLayerZ(layerDefault, -1, vg):
      order.add(-1)
    addDrawLayerZ(layerDefault, 10, vg):
      order.add(11)

    g_drawLayers.draw(g_nvgContext)

    check order == @[-1, 10, 11]

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

  test "global default font applies to text-bearing styles":
    let originalFont = defaultFont()

    try:
      setDefaultFont("test-font", 17.0)

      check defaultFont().fontFace == "test-font"
      checkClose(defaultFont().fontSize, 17.0)
      check borrowDefaultLabelStyle().fontFace == "test-font"
      checkClose(borrowDefaultLabelStyle().fontSize, 17.0)
      check borrowDefaultButtonStyle().label.fontFace == "test-font"
      checkClose(borrowDefaultButtonStyle().label.fontSize, 17.0)
      check borrowDefaultTextFieldStyle().textFontFace == "test-font"
      checkClose(borrowDefaultTextFieldStyle().textFontSize, 17.0)
      check borrowDefaultTextAreaStyle().textFontFace == "test-font"
      checkClose(borrowDefaultTextAreaStyle().textFontSize, 17.0)
      check borrowDefaultTooltipStyle().fontFace == "test-font"
      checkClose(borrowDefaultTooltipStyle().fontSize, 17.0)
      check borrowDefaultTableStyle().rowLabel.fontFace == "test-font"
      checkClose(borrowDefaultTableStyle().rowLabel.fontSize, 17.0)
    finally:
      setDefaultFont(originalFont.fontFace, originalFont.fontSize)

  test "global default corner radius applies to rounded styles":
    let originalRadius = defaultCornerRadius()

    try:
      setDefaultCornerRadius(9.0)

      checkClose(defaultCornerRadius(), 9.0)
      checkClose(borrowDefaultButtonStyle().cornerRadius, 9.0)
      checkClose(borrowDefaultTooltipStyle().cornerRadius, 9.0)
      checkClose(borrowDefaultPopupStyle().backgroundCornerRadius, 9.0)
      checkClose(borrowDefaultTextFieldStyle().bgCornerRadius, 9.0)
      checkClose(borrowDefaultTextAreaStyle().bgCornerRadius, 9.0)
      checkClose(borrowDefaultScrollBarStyle().thumbCornerRadius, 9.0)
      checkClose(borrowDefaultDropDownStyle().itemListCornerRadius, 9.0)
      checkClose(borrowDefaultDialogStyle().cornerRadius, 9.0)
      checkClose(borrowDefaultGroupBoxStyle().cornerRadius, 9.0)
    finally:
      setDefaultCornerRadius(originalRadius)

  test "global default accent colors apply to highlighted styles":
    let
      originalAccent = defaultAccentColors()
      accent = rgb(0.2, 0.4, 0.9)
      accentLow = rgb(0.1, 0.25, 0.5)

    try:
      setDefaultAccentColors(accent, accentLow)

      checkColorClose(defaultAccentColors().accent, accent)
      checkColorClose(defaultAccentColors().accentLow, accentLow)
      checkColorClose(borrowDefaultButtonStyle().fillColorDown, accent)
      checkColorClose(borrowDefaultSelectableStyle().fillColorActive, accent)
      checkColorClose(borrowDefaultSelectableStyle().fillColorDown, accentLow)
      checkColorClose(borrowDefaultRadioButtonsStyle().buttonFillColorActive, accent)
      checkColorClose(borrowDefaultDropDownStyle().itemBackgroundColorHover, accent)
      checkColorClose(borrowDefaultTextFieldStyle().cursorColor, accent)
      checkColorClose(borrowDefaultTextAreaStyle().cursorColor, accent)
      checkColorClose(borrowDefaultProgressStyle().valueColor, accent)
      checkColorClose(borrowDefaultChartStyle().lineColor, accent)
      checkColorClose(borrowDefaultChartStyle().columnColor, accentLow)
      checkColorClose(borrowDefaultMenuStyle().item.fillColorHover, accent)
      checkColorClose(borrowDefaultMenuStyle().item.fillColorDown, accentLow)
    finally:
      setDefaultAccentColors(originalAccent.accent, originalAccent.accentLow)

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
