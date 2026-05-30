proc spacer*() =
  autoLayoutPre()
  autoLayoutPost()

proc spacer*(height: float) =
  nextRowHeight(height)
  autoLayoutPre()
  autoLayoutPost(section = true)

proc beginRowLayout*(height: float, columns: openArray[LayoutColumn] = []) =
  alias(ui, g_uiState)
  alias(a, ui.autoLayoutState)
  alias(ap, ui.autoLayoutParams)

  if a.currColIndex > 0:
    autoLayoutPost(section = true)

  let startX = if a.currColIndex == 0 and a.x == 0: ap.leftPad else: a.x
  let availableW = if ui.layoutStack.len > 0: a.nextItemWidth else: a.rowWidth
  let itemSpacing = 0.0
  let rowColumns = @columns
  let rowSolverW = max(0.0, availableW - ap.leftPad - ap.rightPad)

  ui.layoutStack.add(
    LayoutPresetFrame(
      mode: lpmRow,
      x: startX,
      y: a.y,
      w: availableW,
      h: height,
      rowHeight: height,
      availableWidth: availableW,
      currentX: startX,
      itemSpacing: itemSpacing,
      columns: rowColumns,
      resolvedWidths: rowColumns.resolvedRowWidths(availableW, itemSpacing, ap),
      resolvedSizes: rowColumns.resolvedRowSizes(),
      nodeId: ui.layoutArena.beginLayoutNode(
        layoutNode(
          width = fixed(rowSolverW),
          height = fixed(height),
          direction = ldLeftToRight,
          alignCross = lcaCenter,
          placement = manual(startX, a.y),
        )
      ),
    )
  )

proc beginSpaceLayout*(height: float) =
  alias(ui, g_uiState)
  alias(a, ui.autoLayoutState)

  let rowSlotOwned = ui.layoutStack.len > 0 and ui.layoutStack[^1].mode == lpmRow
  if rowSlotOwned:
    autoLayoutPre()

  let width =
    if rowSlotOwned or ui.layoutStack.len > 0: a.nextItemWidth else: a.rowWidth
  let
    (x, y) = addDrawOffset(a.x, a.y)
    layoutWidth =
      if rowSlotOwned:
        ui.layoutStack[^1].currentRowLayoutSize(ui.autoLayoutParams)
      else:
        fixed(width)
    placement =
      if rowSlotOwned:
        flow()
      else:
        manual(x, y)

  ui.layoutStack.add(
    LayoutPresetFrame(
      mode: lpmSpace,
      x: x,
      y: y,
      w: width,
      h: height,
      rowSlotOwned: rowSlotOwned,
      nodeId: ui.layoutArena.beginLayoutNode(
        layoutNode(width = layoutWidth, height = fixed(height), placement = placement)
      ),
    )
  )
  if rowSlotOwned:
    a.activeSlotUsed = true
  pushDrawOffset(DrawOffset(ox: x, oy: y))

proc endLayout*() =
  alias(ui, g_uiState)
  if ui.layoutStack.len > 0:
    let node = ui.layoutStack.pop()
    if not node.nodeId.isNull:
      discard ui.layoutArena.endLayoutNode()

    if node.mode == lpmSpace:
      popDrawOffset()
      if node.rowSlotOwned:
        autoLayoutPost()
        return

    ui.autoLayoutState.y += node.h
    ui.autoLayoutState.y += ui.autoLayoutParams.sectionPad
