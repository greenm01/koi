proc ensureAutoLayoutRoot(ui: var UIState): LayoutNodeId =
  alias(a, ui.autoLayoutState)
  if not ui.frameLayoutActive():
    return NullLayoutNodeId
  if not a.autoRoot.isNull:
    return a.autoRoot

  let offset = drawOffset()
  let parent =
    if ui.layoutArena.nodeStack.len > 0:
      ui.layoutArena.nodeStack[^1]
    else:
      ui.layoutRoot
  a.autoRoot = ui.layoutArena.addLayoutNode(
    layoutNode(
      width = fixed(a.rowWidth),
      height = fit(),
      direction = ldTopToBottom,
      placement = layoutPlacement(rect(offset.ox, offset.oy, a.rowWidth, 0)),
    ),
    parent,
  )
  a.autoRoot

proc addAutoLayoutSpacer(ui: var UIState, height: float) =
  if height <= 0:
    return

  let root = ui.ensureAutoLayoutRoot()
  if root.isNull:
    return

  discard ui.layoutArena.addLayoutNode(
    layoutNode(width = grow(), height = fixed(height)), root
  )

proc beginAutoLayoutRow(ui: var UIState) =
  alias(a, ui.autoLayoutState)
  alias(ap, ui.autoLayoutParams)

  let root = ui.ensureAutoLayoutRoot()
  if root.isNull:
    a.activeSlotParent = NullLayoutNodeId
    a.activeSlotUsed = false
    return

  a.autoRow = ui.layoutArena.addLayoutNode(
    layoutNode(
      width = fixed(a.rowWidth),
      height = fit(min = a.rowHeight),
      direction = ldLeftToRight,
      padding = padding(ap.leftPad, ap.rightPad, 0, 0),
      childGap = ap.leftPad + ap.rightPad,
      alignCross = lcaCenter,
    ),
    root,
  )
  a.activeSlotParent = a.autoRow
  a.activeSlotUsed = false

proc prepareAutoLayoutSlot(ui: var UIState) =
  alias(a, ui.autoLayoutState)
  alias(ap, ui.autoLayoutParams)

  if ui.layoutStack.len != 0 and ui.layoutStack[^1].mode != lpmViewport:
    a.activeSlotParent = NullLayoutNodeId
    a.activeSlotUsed = false
    return

  if a.currColIndex == 0:
    if not a.firstRow:
      ui.addAutoLayoutSpacer(ap.rowPad)
    if a.groupBegin:
      ui.addAutoLayoutSpacer(ap.rowGroupPad)
    ui.beginAutoLayoutRow()
  else:
    a.activeSlotParent = a.autoRow
    a.activeSlotUsed = false

proc addEmptyAutoSlot(ui: var UIState) =
  alias(a, ui.autoLayoutState)
  let parent = a.activeSlotParent
  if parent.isNull or a.activeSlotUsed:
    return

  var node = layoutNode(
    kind = lnkWidget,
    width = fixed(a.nextItemWidth),
    height = fixed(autoLayoutNextItemHeight()),
  )
  node.intrinsicMin = size(a.nextItemWidth, autoLayoutNextItemHeight())
  node.intrinsicPref = node.intrinsicMin
  discard ui.layoutArena.addLayoutNode(node, parent)
  a.activeSlotUsed = true

proc addEmptyRowSlot(ui: var UIState, row: LayoutPresetFrame) =
  alias(a, ui.autoLayoutState)
  if row.nodeId.isNull or a.activeSlotUsed:
    return

  var node = layoutNode(
    kind = lnkWidget,
    width = row.currentRowLayoutSize(ui.autoLayoutParams),
    height = fixed(autoLayoutNextItemHeight()),
  )
  node.intrinsicMin = size(a.nextItemWidth, autoLayoutNextItemHeight())
  node.intrinsicPref = node.intrinsicMin
  discard ui.layoutArena.addLayoutNode(node, row.nodeId)
  a.activeSlotUsed = true

proc autoLayoutPre*(section: bool = false) =
  alias(ui, g_uiState)
  alias(a, ui.autoLayoutState)
  alias(ap, ui.autoLayoutParams)

  if ui.layoutStack.len > 0:
    alias(node, ui.layoutStack[^1])
    case node.mode
    of lpmRow:
      a.activeSlotParent = NullLayoutNodeId
      a.activeSlotUsed = false
      a.rowHeight = node.rowHeight
      a.x = node.currentX
      a.y = node.y
      a.nextItemWidth = node.currentRowWidth(ap)
      a.nextItemHeight = ap.defaultItemHeight
      a.applyNextItemOverrides()
      return
    of lpmSpace:
      a.activeSlotParent = NullLayoutNodeId
      a.activeSlotUsed = false
      a.x = 0
      a.y = 0
      a.rowHeight = node.h
      a.nextItemWidth = node.w
      a.nextItemHeight = node.h
      a.applyNextItemOverrides()
      return
    of lpmViewport:
      discard

  let firstColumn = a.currColIndex == 0

  if firstColumn:
    a.rowHeight =
      if a.nextRowHeight.isSome: a.nextRowHeight.get else: ap.defaultRowHeight
    a.nextRowHeight = float.none

    a.x = ap.leftPad
    if not a.firstRow:
      a.y += ap.rowPad

    if a.groupBegin:
      a.y += ap.rowGroupPad
  else:
    a.x += a.lastItemWidth + ap.rightPad + ap.leftPad

  let itemsPerRow = ap.effectiveItemsPerRow()
  a.nextItemWidth =
    (
      a.rowWidth - ap.leftPad - ap.rightPad -
      (ap.leftPad + ap.rightPad) * (itemsPerRow - 1).float
    ) / itemsPerRow.float
  a.nextItemHeight = ap.defaultItemHeight
  a.applyNextItemOverrides()
  ui.prepareAutoLayoutSlot()

proc autoLayoutPost*(section: bool = false) =
  alias(ui, g_uiState)
  alias(a, ui.autoLayoutState)
  alias(ap, ui.autoLayoutParams)

  if ui.layoutStack.len > 0:
    alias(node, ui.layoutStack[^1])
    case node.mode
    of lpmRow:
      ui.addEmptyRowSlot(node)
      node.currentX += a.nextItemWidth
      if node.columns.len > 0 and node.colIndex < node.columns.high:
        node.currentX += node.itemSpacing
      inc(node.colIndex)
      node.hasCurrentColumn = false
      return
    of lpmSpace:
      return
    of lpmViewport:
      discard

  let lastColumn = a.currColIndex == ap.effectiveItemsPerRow() - 1
  ui.addEmptyAutoSlot()

  if lastColumn or section:
    a.currColIndex = 0
    a.y += a.rowHeight
    a.y += ap.sectionPad
    if not a.autoRoot.isNull:
      ui.addAutoLayoutSpacer(ap.sectionPad)
    a.autoRow = NullLayoutNodeId
    a.prevSection = section
    a.firstRow = false
  else:
    inc(a.currColIndex)

  a.lastItemWidth = a.nextItemWidth
  a.groupBegin = false
  a.activeSlotParent = NullLayoutNodeId
  a.activeSlotUsed = false

proc autoLayoutFinal*() =
  alias(ui, g_uiState)
  alias(a, ui.autoLayoutState)

  if a.prevSection:
    a.y -= ui.autoLayoutParams.sectionPad
