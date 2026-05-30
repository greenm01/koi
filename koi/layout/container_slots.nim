proc layoutChildSlot*(
    parent: LayoutNodeId,
    id: ItemId,
    fallback: Rect,
    width: LayoutSize,
    height: LayoutSize,
): LayoutSlot =
  layoutSlotWithSizing(id, fallback, width, height, parent)

proc beginLayoutContainerSlotAt*(
    id: ItemId, fallback, frameBounds: Rect, scrollOffset: Size = size(0, 0)
): LayoutSlot =
  alias(ui, g_uiState)
  alias(a, ui.autoLayoutState)

  let parent = ui.activeAutoSlotParent()
  var width = fixed(fallback.w)
  if parent.isNull and ui.layoutStack.len > 0 and ui.layoutStack[^1].mode == lpmRow:
    width = ui.layoutStack[^1].currentRowLayoutSize(ui.autoLayoutParams)

  var node = layoutNode(
    kind = lnkContainer,
    itemId = id,
    width = width,
    height = fixed(fallback.h),
    scrollOffset = scrollOffset,
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
      ui.layoutArena.beginLayoutNode(node)
    else:
      let child = ui.layoutArena.addLayoutNode(node, parent)
      ui.layoutArena.nodeStack.add(child)
      child

  ui.markAutoSlotUsed(parent)
  ui.markPresetSlotUsed()

  ui.layoutStack.add(
    LayoutPresetFrame(
      mode: lpmViewport,
      x: frameBounds.x,
      y: frameBounds.y,
      w: frameBounds.w,
      h: frameBounds.h,
      nodeId: nodeId,
      savedActiveSlotParent: a.activeSlotParent,
      savedActiveSlotUsed: a.activeSlotUsed,
    )
  )
  a.activeSlotParent = NullLayoutNodeId
  a.activeSlotUsed = false

  result = LayoutSlot(
    itemId: id,
    nodeId: nodeId,
    bounds: fallback,
    previousBounds: previousLayoutRect(id, fallback),
  )

proc beginLayoutContainerSlot*(id: ItemId, fallback: Rect): LayoutSlot =
  beginLayoutContainerSlotAt(id, fallback, fallback)

proc beginLayoutChildContainerSlotAt*(
    parent: LayoutNodeId,
    id: ItemId,
    fallback, frameBounds: Rect,
    width, height: LayoutSize,
    scrollOffset: Size = size(0, 0),
): LayoutSlot =
  alias(ui, g_uiState)
  alias(a, ui.autoLayoutState)

  var node = layoutNode(
    kind = lnkContainer,
    itemId = id,
    width = width,
    height = height,
    scrollOffset = scrollOffset,
    placement = flow(),
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
      ui.layoutArena.beginLayoutNode(node)
    else:
      let child = ui.layoutArena.addLayoutNode(node, parent)
      ui.layoutArena.nodeStack.add(child)
      child

  ui.layoutStack.add(
    LayoutPresetFrame(
      mode: lpmViewport,
      x: frameBounds.x,
      y: frameBounds.y,
      w: frameBounds.w,
      h: frameBounds.h,
      nodeId: nodeId,
      savedActiveSlotParent: a.activeSlotParent,
      savedActiveSlotUsed: a.activeSlotUsed,
    )
  )
  a.activeSlotParent = NullLayoutNodeId
  a.activeSlotUsed = false

  result = LayoutSlot(
    itemId: id,
    nodeId: nodeId,
    bounds: fallback,
    previousBounds: previousLayoutRect(id, fallback),
  )

proc beginLayoutFollowerContainerSlotAt*(
    id: ItemId,
    fallback, frameBounds: Rect,
    target: LayoutNodeId,
    followKind: LayoutFollowerKind,
    followAlign: HorizontalAlign = haLeft,
    windowPad: float = 10.0,
    followInset: Padding = Padding(),
    scrollOffset: Size = size(0, 0),
): LayoutSlot =
  alias(ui, g_uiState)
  alias(a, ui.autoLayoutState)

  var node = layoutNode(
    kind = lnkContainer,
    itemId = id,
    width = fixed(fallback.w),
    height = fixed(fallback.h),
    scrollOffset = scrollOffset,
    placement = follow(target, followKind, followAlign, windowPad, followInset),
  )
  node.intrinsicMin = size(fallback.w, fallback.h)
  node.intrinsicPref = size(fallback.w, fallback.h)
  node.rect = fallback

  let nodeId =
    if ui.frameLayoutActive():
      let child = ui.layoutArena.addLayoutNode(node, ui.layoutRoot)
      ui.layoutArena.nodeStack.add(child)
      child
    else:
      ui.layoutArena.beginLayoutNode(node)

  ui.layoutStack.add(
    LayoutPresetFrame(
      mode: lpmViewport,
      x: frameBounds.x,
      y: frameBounds.y,
      w: frameBounds.w,
      h: frameBounds.h,
      nodeId: nodeId,
      savedActiveSlotParent: a.activeSlotParent,
      savedActiveSlotUsed: a.activeSlotUsed,
    )
  )
  a.activeSlotParent = NullLayoutNodeId
  a.activeSlotUsed = false

  result = LayoutSlot(
    itemId: id,
    nodeId: nodeId,
    bounds: fallback,
    previousBounds: previousLayoutRect(id, fallback),
  )

proc beginLayoutAttachContainerSlotAt*(
    id: ItemId,
    fallback, frameBounds: Rect,
    placement: LayoutPlacement,
    scrollOffset: Size = size(0, 0),
): LayoutSlot =
  alias(ui, g_uiState)
  alias(a, ui.autoLayoutState)

  doAssert placement.kind == lpkAttach

  var node = layoutNode(
    kind = lnkContainer,
    itemId = id,
    width = fixed(fallback.w),
    height = fixed(fallback.h),
    scrollOffset = scrollOffset,
    placement = placement,
  )
  node.intrinsicMin = size(fallback.w, fallback.h)
  node.intrinsicPref = size(fallback.w, fallback.h)
  node.rect = fallback

  let nodeId =
    if ui.frameLayoutActive():
      let child = ui.layoutArena.addLayoutNode(node, ui.layoutRoot)
      if not child.isNull:
        ui.layoutArena.nodeStack.add(child)
      child
    else:
      ui.layoutArena.beginLayoutNode(node)

  ui.layoutStack.add(
    LayoutPresetFrame(
      mode: lpmViewport,
      x: frameBounds.x,
      y: frameBounds.y,
      w: frameBounds.w,
      h: frameBounds.h,
      nodeId: nodeId,
      savedActiveSlotParent: a.activeSlotParent,
      savedActiveSlotUsed: a.activeSlotUsed,
      savedHitClip: ui.hitClipRect,
      savedFocusCaptured: ui.focusCaptured,
      capturePointer: placement.attach.capturePointer,
    )
  )
  a.activeSlotParent = NullLayoutNodeId
  a.activeSlotUsed = false
  if placement.attach.capturePointer:
    let hitBounds = previousLayoutRect(id, fallback)
    ui.focusCaptured = false
    hitClip(hitBounds.x, hitBounds.y, hitBounds.w, hitBounds.h)

  result = LayoutSlot(
    itemId: id,
    nodeId: nodeId,
    bounds: fallback,
    previousBounds: previousLayoutRect(id, fallback),
  )

proc beginLayoutAttachContainerSlotAt*(
    id: ItemId,
    fallback, frameBounds: Rect,
    target: LayoutNodeId,
    targetPoint, selfPoint: LayoutAttachPoint,
    offset: Size = size(0, 0),
    windowPad: float = 0.0,
    clipToRoot: bool = false,
    zIndex: int = 0,
    capturePointer: bool = false,
    scrollOffset: Size = size(0, 0),
): LayoutSlot =
  beginLayoutAttachContainerSlotAt(
    id,
    fallback,
    frameBounds,
    attach(
      target, targetPoint, selfPoint, offset, windowPad, clipToRoot, zIndex,
      capturePointer,
    ),
    scrollOffset,
  )

proc beginLayoutAttachParentContainerSlotAt*(
    id: ItemId,
    fallback, frameBounds: Rect,
    targetPoint, selfPoint: LayoutAttachPoint,
    offset: Size = size(0, 0),
    windowPad: float = 0.0,
    clipToRoot: bool = false,
    zIndex: int = 0,
    capturePointer: bool = false,
    scrollOffset: Size = size(0, 0),
): LayoutSlot =
  beginLayoutAttachContainerSlotAt(
    id,
    fallback,
    frameBounds,
    attachParent(
      targetPoint, selfPoint, offset, windowPad, clipToRoot, zIndex, capturePointer
    ),
    scrollOffset,
  )

proc beginLayoutAttachRootContainerSlotAt*(
    id: ItemId,
    fallback, frameBounds: Rect,
    targetPoint, selfPoint: LayoutAttachPoint,
    offset: Size = size(0, 0),
    windowPad: float = 0.0,
    clipToRoot: bool = false,
    zIndex: int = 0,
    capturePointer: bool = false,
    scrollOffset: Size = size(0, 0),
): LayoutSlot =
  beginLayoutAttachContainerSlotAt(
    id,
    fallback,
    frameBounds,
    attachRoot(
      targetPoint, selfPoint, offset, windowPad, clipToRoot, zIndex, capturePointer
    ),
    scrollOffset,
  )

proc endLayoutContainerSlot*() =
  alias(ui, g_uiState)
  if ui.layoutStack.len == 0 or ui.layoutStack[^1].mode != lpmViewport:
    return

  let frame = ui.layoutStack.pop()
  if not frame.nodeId.isNull:
    discard ui.layoutArena.endLayoutNode()
  ui.autoLayoutState.activeSlotParent = frame.savedActiveSlotParent
  ui.autoLayoutState.activeSlotUsed = frame.savedActiveSlotUsed
  if frame.capturePointer:
    ui.hitClipRect = frame.savedHitClip
    ui.focusCaptured = frame.savedFocusCaptured

proc beginLayoutViewportForSlot*(slot: LayoutSlot, frameBounds: Rect = slot.bounds) =
  alias(ui, g_uiState)
  alias(a, ui.autoLayoutState)

  if slot.nodeId.isNull:
    return

  ui.layoutArena.nodeStack.add(slot.nodeId)
  ui.layoutStack.add(
    LayoutPresetFrame(
      mode: lpmViewport,
      x: frameBounds.x,
      y: frameBounds.y,
      w: frameBounds.w,
      h: frameBounds.h,
      nodeId: slot.nodeId,
      savedActiveSlotParent: a.activeSlotParent,
      savedActiveSlotUsed: a.activeSlotUsed,
    )
  )
  a.activeSlotParent = NullLayoutNodeId
  a.activeSlotUsed = false

proc endLayoutViewportForSlot*() =
  endLayoutContainerSlot()
