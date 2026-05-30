proc setLayoutErrorHandler*(handler: LayoutErrorHandler) =
  g_uiState.layoutArena.setLayoutErrorHandler(handler)

proc clearLayoutErrors*() =
  g_uiState.layoutArena.clearLayoutErrors()

proc layoutErrors*(): seq[LayoutError] =
  g_uiState.layoutArena.layoutErrors()

proc setLayoutMaxNodes*(maxNodes: int) =
  g_uiState.layoutArena.setLayoutMaxNodes(maxNodes)

proc clearUnbalancedLayoutPresetFrames(ui: var UIState) =
  while ui.layoutStack.len > 0:
    let frame = ui.layoutStack.pop()
    if not frame.nodeId.isNull and ui.layoutArena.nodeStack.len > 0 and
        int32(ui.layoutArena.nodeStack[^1]) == int32(frame.nodeId):
      discard ui.layoutArena.endLayoutNode()
    if frame.mode == lpmSpace:
      popDrawOffset()
    if frame.capturePointer:
      ui.hitClipRect = frame.savedHitClip
      ui.focusCaptured = frame.savedFocusCaptured
  ui.autoLayoutState.activeSlotParent = NullLayoutNodeId
  ui.autoLayoutState.activeSlotUsed = false

func layoutInspectorPickNode(arena: LayoutArena, x, y: float): LayoutNodeId =
  result = NullLayoutNodeId
  var bestZ = low(int)
  var bestOrder = -1
  for i, node in arena.nodes:
    if node.rect.contains(x, y):
      let zIndex = arena.layoutZIndex(node.id)
      if result.isNull or zIndex > bestZ or (zIndex == bestZ and i > bestOrder):
        result = node.id
        bestZ = zIndex
        bestOrder = i

proc queueLayoutInspectorDraw() =
  alias(ui, g_uiState)
  if not ui.layoutDebug.enabled:
    return

  ui.layoutDebug.hoveredNode = ui.layoutArena.layoutInspectorPickNode(ui.mx, ui.my)
  if ui.mbLeftDown and not ui.layoutDebug.hoveredNode.isNull:
    ui.layoutDebug.selectedNode = ui.layoutDebug.hoveredNode

  let
    panelW = min(
      if ui.layoutDebug.panelWidth > 0.0: ui.layoutDebug.panelWidth else: 360.0,
      max(160.0, ui.winWidth),
    )
    panelX = max(0.0, ui.winWidth - panelW)
    panelH = ui.winHeight
    treeX = panelX + 12.0
    treeY = 55.0
    treeW = max(0.0, panelW - 24.0)
    treeH = layoutInspectorTreeAreaHeight(panelH)

  ui.updateLayoutInspectorTreeInteraction(treeX, treeY, treeW, treeH)

  let capturedHover = ui.layoutDebug.hoveredNode
  let capturedSelected = ui.layoutDebug.selectedNode
  let capturedDetail =
    ui.layoutArena.layoutInspectorDetailNode(capturedHover, capturedSelected)
  let capturedDetailLines = ui.layoutArena.layoutInspectorNodeLines(capturedDetail)
  let capturedErrorLines = layoutInspectorErrorLines()
  let capturedTreeRows = ui.layoutArena.layoutInspectorTreeRows(ui.layoutDebug)
  let capturedTreeScroll = ui.layoutDebug.treeScroll

  addDrawLayer(layerGlobalOverlay, vg):
    for node in g_uiState.layoutArena.nodes:
      let isHover = int32(node.id) == int32(capturedHover)
      let isSelected = int32(node.id) == int32(capturedSelected)
      vg.beginPath()
      vg.rect(node.rect.x, node.rect.y, node.rect.w, node.rect.h)
      vg.strokeWidth(if isHover or isSelected: 2.0 else: 1.0)
      vg.strokeColor(
        if isHover:
          rgba(255, 190, 0, 220)
        elif isSelected:
          rgba(255, 255, 255, 180)
        else:
          rgba(0, 180, 255, 110)
      )
      vg.stroke()

    vg.beginPath()
    vg.rect(panelX, 0, panelW, panelH)
    vg.fillColor(rgba(20, 22, 24, 230))
    vg.fill()

    vg.useFont(12.0, "sans", haLeft, vaTop)
    vg.fillColor(rgba(235, 235, 235, 255))
    var y = 12.0
    discard vg.text(panelX + 12, y, "Layout Inspector")
    y += 22.0

    vg.beginPath()
    vg.rect(treeX, treeY, treeW, treeH)
    vg.fillColor(rgba(15, 17, 19, 210))
    vg.fill()

    vg.save()
    vg.intersectScissor(treeX, treeY, treeW, treeH)
    for i, row in capturedTreeRows:
      let rowY = treeY + i.float * LayoutInspectorTreeRowHeight - capturedTreeScroll
      if rowY + LayoutInspectorTreeRowHeight < treeY or rowY > treeY + treeH:
        continue

      if row.selected or row.hovered:
        vg.beginPath()
        vg.rect(treeX, rowY, treeW, LayoutInspectorTreeRowHeight)
        vg.fillColor(
          if row.selected:
            rgba(90, 105, 120, 180)
          else:
            rgba(70, 80, 90, 130)
        )
        vg.fill()

      let textX = treeX + 4.0 + row.depth.float * LayoutInspectorTreeIndent
      let disclosure =
        if row.hasChildren:
          if row.collapsed: "+" else: "-"
        else:
          "."
      discard vg.text(textX, rowY + 2.0, disclosure)
      vg.fillColor(
        if row.errorCount > 0:
          rgba(255, 190, 90, 255)
        elif row.selected:
          rgba(255, 255, 255, 255)
        elif row.hovered:
          rgba(230, 235, 240, 255)
        else:
          rgba(200, 205, 210, 255)
      )
      discard vg.text(textX + LayoutInspectorTreeDisclosureWidth, rowY + 2.0, row.label)
      vg.fillColor(rgba(235, 235, 235, 255))
    vg.restore()

    y = treeY + treeH + 12.0
    var lines =
      @[
        &"hovered: {int32(capturedHover)}",
        &"selected: {int32(capturedSelected)}",
        &"detail: {int32(capturedDetail)}",
        "",
      ]
    lines.add(capturedDetailLines)
    lines.add("")
    lines.add(capturedErrorLines)

    for line in lines:
      if y + 17.0 > panelH - 10.0:
        discard vg.text(panelX + 12, y, "...")
        break
      discard vg.text(panelX + 12, y, line)
      y += 17.0
