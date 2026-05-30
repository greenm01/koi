proc finishFrameLayout*() =
  alias(ui, g_uiState)

  let expectedStackLen = if ui.layoutRoot.isNull: 0 else: 1
  if ui.layoutStack.len > 0:
    ui.layoutArena.reportLayoutError(
      lekUnbalancedLayoutStack,
      if ui.layoutArena.nodeStack.len > 0:
        ui.layoutArena.nodeStack[^1]
      else:
        NullLayoutNodeId,
      0,
      &"layout preset stack has {ui.layoutStack.len} unclosed frame(s); clearing",
    )
    ui.clearUnbalancedLayoutPresetFrames()
  if ui.layoutArena.nodeStack.len > expectedStackLen:
    ui.layoutArena.reportLayoutError(
      lekUnbalancedLayoutStack,
      ui.layoutArena.nodeStack[^1],
      0,
      &"layout node stack has {ui.layoutArena.nodeStack.len - expectedStackLen} unclosed node(s); auto-closing",
    )

  while ui.layoutArena.nodeStack.len > 0:
    discard ui.layoutArena.endLayoutNode()

  ui.layoutArena.solveLayout(rect(0, 0, ui.winWidth, ui.winHeight), ui.layoutRoot)

  var solvedRects: Table[ItemId, Rect]
  var solvedContentSizes: Table[ItemId, Size]
  for node in ui.layoutArena.nodes:
    if node.itemId != 0:
      solvedRects[node.itemId] = node.rect
      solvedContentSizes[node.itemId] = node.contentSize
  ui.layoutRects = solvedRects
  ui.layoutContentSizes = solvedContentSizes
  queueLayoutInspectorDraw()

func col*(width: float): LayoutColumn =
  LayoutColumn(mode: cmStatic, value: width)

func colDynamic*(): LayoutColumn =
  LayoutColumn(mode: cmDynamic)

func colRatio*(ratio: float): LayoutColumn =
  LayoutColumn(mode: cmRatio, value: ratio)

func colVariable*(minWidth: float): LayoutColumn =
  LayoutColumn(mode: cmVariable, value: minWidth)

func ratioFromPixels*(pixels, total: float): float =
  if total <= 0:
    0.0
  else:
    (pixels / total).clamp(0.0, 1.0)
