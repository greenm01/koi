proc beginFrameLayout*() =
  alias(ui, g_uiState)

  ui.layoutArena.initLayoutArena(measureLayoutText)
  ui.layoutRoot = ui.layoutArena.beginLayoutNode(
    layoutNode(
      width = fixed(ui.winWidth),
      height = fixed(ui.winHeight),
      direction = ldTopToBottom,
    )
  )
  ui.autoLayoutState.autoRoot = NullLayoutNodeId
  ui.autoLayoutState.autoRow = NullLayoutNodeId
  ui.autoLayoutState.activeSlotParent = NullLayoutNodeId
  ui.autoLayoutState.activeSlotUsed = false

proc layoutPlacement(fallback: Rect): LayoutPlacement =
  result = manual(fallback.x, fallback.y)
  if g_uiState.layoutStack.len > 0:
    let frame = g_uiState.layoutStack[^1]
    case frame.mode
    of lpmRow:
      result = flow()
    of lpmSpace, lpmViewport:
      result = manual(fallback.x - frame.x, fallback.y - frame.y)

proc previousLayoutRect*(id: ItemId, fallback: Rect): Rect =
  alias(ui, g_uiState)
  if ui.layoutRects.hasKey(id):
    ui.layoutRects[id]
  else:
    fallback

proc previousLayoutContentSize*(id: ItemId, fallback: Size): Size =
  alias(ui, g_uiState)
  if ui.layoutContentSizes.hasKey(id):
    ui.layoutContentSizes[id]
  else:
    fallback

func frameLayoutActive(ui: UIState): bool =
  ui.layoutArena.nodes.len > 0 and not ui.layoutRoot.isNull

func activeAutoSlotParent(ui: UIState): LayoutNodeId =
  if ui.autoLayoutState.activeSlotParent.isNull:
    NullLayoutNodeId
  else:
    ui.autoLayoutState.activeSlotParent

proc markAutoSlotUsed(ui: var UIState, parent: LayoutNodeId) =
  if not parent.isNull and int32(parent) == int32(ui.autoLayoutState.activeSlotParent):
    ui.autoLayoutState.activeSlotUsed = true

proc markPresetSlotUsed(ui: var UIState) =
  if ui.layoutStack.len > 0 and ui.layoutStack[^1].mode == lpmRow:
    ui.autoLayoutState.activeSlotUsed = true

proc currentRowLayoutSize(node: LayoutPresetFrame, ap: AutoLayoutParams): LayoutSize

proc layoutSlotWithSizing(
    id: ItemId, fallback: Rect, width, height: LayoutSize, parent: LayoutNodeId
): LayoutSlot =
  alias(ui, g_uiState)

  var node = layoutNode(
    kind = lnkWidget,
    itemId = id,
    width = width,
    height = height,
    placement =
      if parent.isNull:
        layoutPlacement(fallback)
      else:
        flow(),
  )
  node.intrinsicMin = size(fallback.w, fallback.h)
  node.intrinsicPref = size(fallback.w, fallback.h)
  if width.kind == lskGrow:
    node.intrinsicMin.w = width.min
    node.intrinsicPref.w = width.min
  if height.kind == lskGrow:
    node.intrinsicMin.h = height.min
    node.intrinsicPref.h = height.min
  node.rect = fallback

  let nodeId =
    if parent.isNull:
      ui.layoutArena.addLayoutNode(node)
    else:
      ui.layoutArena.addLayoutNode(node, parent)
  ui.markAutoSlotUsed(parent)
  ui.markPresetSlotUsed()

  result = LayoutSlot(
    itemId: id,
    nodeId: nodeId,
    bounds: fallback,
    previousBounds: previousLayoutRect(id, fallback),
  )

proc layoutSlot*(id: ItemId, fallback: Rect): LayoutSlot =
  alias(ui, g_uiState)
  let parent = ui.activeAutoSlotParent()
  var width = fixed(fallback.w)
  if parent.isNull and ui.layoutStack.len > 0 and ui.layoutStack[^1].mode == lpmRow:
    width = ui.layoutStack[^1].currentRowLayoutSize(ui.autoLayoutParams)
  layoutSlotWithSizing(id, fallback, width, fixed(fallback.h), parent)

proc layoutContainerSlot*(
    id: ItemId,
    fallback: Rect,
    direction: LayoutDirection = ldLeftToRight,
    childGap: float = 0.0,
    padding: Padding = Padding(),
    alignCross: LayoutCrossAlign = lcaStretch,
): LayoutSlot =
  alias(ui, g_uiState)
  let parent = ui.activeAutoSlotParent()
  var width = fixed(fallback.w)
  if parent.isNull and ui.layoutStack.len > 0 and ui.layoutStack[^1].mode == lpmRow:
    width = ui.layoutStack[^1].currentRowLayoutSize(ui.autoLayoutParams)

  var node = layoutNode(
    kind = lnkContainer,
    itemId = id,
    width = width,
    height = fixed(fallback.h),
    direction = direction,
    childGap = childGap,
    padding = padding,
    alignCross = alignCross,
    placement =
      if parent.isNull:
        layoutPlacement(fallback)
      else:
        flow(),
  )
  node.intrinsicMin = size(fallback.w, fallback.h)
  node.intrinsicPref = size(fallback.w, fallback.h)
  if width.kind == lskGrow:
    node.intrinsicMin.w = width.min
    node.intrinsicPref.w = width.min
  node.rect = fallback

  let nodeId =
    if parent.isNull:
      ui.layoutArena.addLayoutNode(node)
    else:
      ui.layoutArena.addLayoutNode(node, parent)
  ui.markAutoSlotUsed(parent)
  ui.markPresetSlotUsed()

  result = LayoutSlot(
    itemId: id,
    nodeId: nodeId,
    bounds: fallback,
    previousBounds: previousLayoutRect(id, fallback),
  )
