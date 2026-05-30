proc layoutDrawSlot*(id: ItemId, fallback: Rect): LayoutSlot =
  layoutSlotWithSizing(
    id, fallback, fixed(fallback.w), fixed(fallback.h), NullLayoutNodeId
  )

proc layoutFollowerSlot*(
    id: ItemId,
    fallback: Rect,
    target: LayoutNodeId,
    followKind: LayoutFollowerKind,
    followAlign: HorizontalAlign = haLeft,
    windowPad: float = 10.0,
    followInset: Padding = Padding(),
): LayoutSlot =
  alias(ui, g_uiState)

  var node = layoutNode(
    kind = lnkWidget,
    itemId = id,
    width = fixed(fallback.w),
    height = fixed(fallback.h),
    placement = follow(target, followKind, followAlign, windowPad, followInset),
  )
  node.intrinsicMin = size(fallback.w, fallback.h)
  node.intrinsicPref = size(fallback.w, fallback.h)
  node.rect = fallback

  let nodeId =
    if ui.frameLayoutActive():
      ui.layoutArena.addLayoutNode(node, ui.layoutRoot)
    else:
      ui.layoutArena.addLayoutNode(node)
  result = LayoutSlot(
    itemId: id,
    nodeId: nodeId,
    bounds: fallback,
    previousBounds: previousLayoutRect(id, fallback),
  )

proc layoutAttachSlot*(
    id: ItemId, fallback: Rect, placement: LayoutPlacement
): LayoutSlot =
  alias(ui, g_uiState)

  doAssert placement.kind == lpkAttach

  var node = layoutNode(
    kind = lnkWidget,
    itemId = id,
    width = fixed(fallback.w),
    height = fixed(fallback.h),
    placement = placement,
  )
  node.intrinsicMin = size(fallback.w, fallback.h)
  node.intrinsicPref = size(fallback.w, fallback.h)
  node.rect = fallback

  let nodeId =
    if ui.frameLayoutActive():
      ui.layoutArena.addLayoutNode(node, ui.layoutRoot)
    else:
      ui.layoutArena.addLayoutNode(node)
  result = LayoutSlot(
    itemId: id,
    nodeId: nodeId,
    bounds: fallback,
    previousBounds: previousLayoutRect(id, fallback),
  )

proc layoutAttachSlot*(
    id: ItemId,
    fallback: Rect,
    target: LayoutNodeId,
    targetPoint, selfPoint: LayoutAttachPoint,
    offset: Size = size(0, 0),
    windowPad: float = 0.0,
    clipToRoot: bool = false,
    zIndex: int = 0,
    capturePointer: bool = false,
): LayoutSlot =
  layoutAttachSlot(
    id,
    fallback,
    attach(
      target, targetPoint, selfPoint, offset, windowPad, clipToRoot, zIndex,
      capturePointer,
    ),
  )

proc layoutAttachParentSlot*(
    id: ItemId,
    fallback: Rect,
    targetPoint, selfPoint: LayoutAttachPoint,
    offset: Size = size(0, 0),
    windowPad: float = 0.0,
    clipToRoot: bool = false,
    zIndex: int = 0,
    capturePointer: bool = false,
): LayoutSlot =
  layoutAttachSlot(
    id,
    fallback,
    attachParent(
      targetPoint, selfPoint, offset, windowPad, clipToRoot, zIndex, capturePointer
    ),
  )

proc layoutAttachRootSlot*(
    id: ItemId,
    fallback: Rect,
    targetPoint, selfPoint: LayoutAttachPoint,
    offset: Size = size(0, 0),
    windowPad: float = 0.0,
    clipToRoot: bool = false,
    zIndex: int = 0,
    capturePointer: bool = false,
): LayoutSlot =
  layoutAttachSlot(
    id,
    fallback,
    attachRoot(
      targetPoint, selfPoint, offset, windowPad, clipToRoot, zIndex, capturePointer
    ),
  )

proc textLayoutSlotWithSizing(
    id: ItemId,
    fallback: Rect,
    text: string,
    style: LabelStyle,
    width, height: LayoutSize,
    parent: LayoutNodeId,
): LayoutSlot =
  alias(ui, g_uiState)

  var node = layoutNode(
    kind = lnkText,
    itemId = id,
    width = width,
    height = height,
    placement =
      if parent.isNull:
        layoutPlacement(fallback)
      else:
        flow(),
    text = text,
    fontSize = style.fontSize,
    fontFace = style.fontFace,
  )
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

proc textLayoutSlot*(
    id: ItemId, fallback: Rect, text: string, style: LabelStyle
): LayoutSlot =
  alias(ui, g_uiState)
  let parent = ui.activeAutoSlotParent()
  var width = fixed(fallback.w)
  if parent.isNull and ui.layoutStack.len > 0 and ui.layoutStack[^1].mode == lpmRow:
    width = ui.layoutStack[^1].currentRowLayoutSize(ui.autoLayoutParams)
  textLayoutSlotWithSizing(
    id,
    fallback,
    text,
    style,
    width,
    if parent.isNull:
      fixed(fallback.h)
    else:
      fit(min = fallback.h),
    parent,
  )

proc layoutAspectSlot*(
    id: ItemId, fallback: Rect, aspectRatio: float, minHeight: float = 0.0
): LayoutSlot =
  alias(ui, g_uiState)
  let parent = ui.activeAutoSlotParent()
  var node = layoutNode(
    kind = lnkWidget,
    itemId = id,
    width = fixed(fallback.w),
    height = fit(min = minHeight),
    aspectRatio = aspectRatio,
    placement =
      if parent.isNull:
        layoutPlacement(fallback)
      else:
        flow(),
  )
  node.intrinsicMin = size(fallback.w, minHeight)
  node.intrinsicPref = size(fallback.w, minHeight)
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

proc textLayoutChildSlot*(
    parent: LayoutNodeId,
    id: ItemId,
    fallback: Rect,
    text: string,
    style: LabelStyle,
    width: LayoutSize,
    height: LayoutSize,
): LayoutSlot =
  textLayoutSlotWithSizing(id, fallback, text, style, width, height, parent)
