template addLayoutDrawLayer*(
    layer: DrawLayer, nodeId: LayoutNodeId, vg, bounds, body: untyped
) =
  let capturedNodeId = nodeId
  addDrawLayerZ(layer, g_uiState.layoutArena.layoutZIndex(capturedNodeId), vg):
    let bounds {.inject.} = g_uiState.layoutArena.layoutRect(capturedNodeId)
    body

func contains(r: Rect, x, y: float): bool =
  x >= r.x and y >= r.y and x <= r.x + r.w and y <= r.y + r.h

proc setLayoutInspectorEnabled*(enabled: bool) =
  g_uiState.layoutDebug.enabled = enabled
  if g_uiState.layoutDebug.panelWidth <= 0.0:
    g_uiState.layoutDebug.panelWidth = 360.0
  if enabled:
    g_uiState.layoutDebug.hoveredNode = NullLayoutNodeId
    g_uiState.layoutDebug.selectedNode = NullLayoutNodeId

proc layoutInspectorEnabled*(): bool =
  g_uiState.layoutDebug.enabled

proc toggleLayoutInspector*() =
  setLayoutInspectorEnabled(not layoutInspectorEnabled())

proc layoutInspectorHoveredNode*(): LayoutNodeId =
  g_uiState.layoutDebug.hoveredNode

proc layoutInspectorSelectedNode*(): LayoutNodeId =
  g_uiState.layoutDebug.selectedNode

func layoutInspectorDetailNode(
    arena: LayoutArena, hovered, selected: LayoutNodeId
): LayoutNodeId =
  let selectedValid = int32(selected) >= 0 and int32(selected) < arena.nodes.len.int32
  if not hovered.isNull and (int32(hovered) != 0 or not selectedValid):
    hovered
  elif selectedValid:
    selected
  elif int32(hovered) >= 0 and int32(hovered) < arena.nodes.len.int32:
    hovered
  else:
    NullLayoutNodeId

proc layoutInspectorDetailNode*(): LayoutNodeId =
  g_uiState.layoutArena.layoutInspectorDetailNode(
    g_uiState.layoutDebug.hoveredNode, g_uiState.layoutDebug.selectedNode
  )

func validLayoutInspectorNode(arena: LayoutArena, id: LayoutNodeId): bool =
  int32(id) >= 0 and int32(id) < arena.nodes.len.int32

func layoutSizeDebugText(spec: LayoutSize): string =
  case spec.kind
  of lskFixed:
    &"fixed({spec.value:.1f})"
  of lskPercent:
    &"percent({spec.percent:.3f}, min={spec.min:.1f}, max={spec.max:.1f})"
  of lskFit:
    &"fit(min={spec.min:.1f}, max={spec.max:.1f})"
  of lskGrow:
    &"grow(min={spec.min:.1f}, max={spec.max:.1f})"

func paddingDebugText(p: Padding): string =
  &"{p.left:.1f}, {p.right:.1f}, {p.top:.1f}, {p.bottom:.1f}"

func sizeDebugText(s: Size): string =
  &"{s.w:.1f}, {s.h:.1f}"

func rectDebugText(r: Rect): string =
  &"{r.x:.1f}, {r.y:.1f}, {r.w:.1f}, {r.h:.1f}"

func siblingIndex(arena: LayoutArena, node: LayoutNode): int =
  if node.parent.isNull or not arena.validLayoutInspectorNode(node.parent):
    return -1

  let parent = arena.nodes[int32(node.parent)]
  for i in 0 ..< int(parent.childCount):
    let childId = arena.childIndices[int(parent.firstChild) + i]
    if int32(childId) == int32(node.id):
      return i
  -1

func parentChainDebugText(arena: LayoutArena, id: LayoutNodeId): string =
  if not arena.validLayoutInspectorNode(id):
    return "none"

  var chain: seq[string]
  var cursor = arena.nodes[int32(id)].parent
  while arena.validLayoutInspectorNode(cursor):
    chain.add($int32(cursor))
    cursor = arena.nodes[int32(cursor)].parent

  if chain.len == 0:
    return "none"

  result = chain[^1]
  if chain.len >= 2:
    for i in countdown(chain.high - 1, 0):
      result.add(" > " & chain[i])

func layoutPlacementDebugLines(node: LayoutNode): seq[string] =
  case node.placement.kind
  of lpkFlow:
    @["placement: flow"]
  of lpkManual:
    @[
      "placement: manual", &"manual pos: {node.placement.x:.1f}, {node.placement.y:.1f}"
    ]
  of lpkFollow:
    @[
      "placement: follow",
      &"follow target: {int32(node.placement.target)}",
      &"follow kind: {node.placement.followKind}",
      &"follow align: {node.placement.followAlign}",
      &"follow inset: {paddingDebugText(node.placement.followInset)}",
      &"follow window pad: {node.placement.windowPad:.1f}",
    ]
  of lpkAttach:
    let attach = node.placement.attach
    @[
      "placement: attach",
      &"attach target: {attach.targetKind} {int32(attach.targetNode)}",
      &"attach points: target={attach.targetPoint} self={attach.selfPoint}",
      &"attach offset: {sizeDebugText(attach.offset)}",
      &"attach pad/clip: {attach.windowPad:.1f} / {attach.clipToRoot}",
      &"attach capture: {attach.capturePointer}",
    ]

func layoutInspectorNodeLines(arena: LayoutArena, nodeId: LayoutNodeId): seq[string] =
  if not arena.validLayoutInspectorNode(nodeId):
    return @["No node selected"]

  let node = arena.nodes[int32(nodeId)]
  let sibling = arena.siblingIndex(node)
  result =
    @[
      &"node: {int32(node.id)} item: {node.itemId}",
      &"parent: {int32(node.parent)} kind: {node.kind}",
      &"parents: {arena.parentChainDebugText(node.id)}",
      &"children: {node.childCount} sibling: {sibling}",
      &"rect: {rectDebugText(node.rect)}",
      &"content: {sizeDebugText(node.contentSize)}",
      &"scroll: {sizeDebugText(node.scrollOffset)}",
      &"intrinsic min: {sizeDebugText(node.intrinsicMin)}",
      &"intrinsic pref: {sizeDebugText(node.intrinsicPref)}",
      &"width: {layoutSizeDebugText(node.width)}",
      &"height: {layoutSizeDebugText(node.height)}",
      &"direction: {node.direction}",
      &"padding: {paddingDebugText(node.padding)}",
      &"gap: {node.childGap:.1f}",
      &"align: main={node.alignMain} cross={node.alignCross}",
      &"z-index: {arena.layoutZIndex(node.id)}",
      &"aspect: {node.aspectRatio:.3f}",
    ]
  result.add(node.layoutPlacementDebugLines)

proc layoutInspectorNodeLines*(nodeId: LayoutNodeId): seq[string] =
  g_uiState.layoutArena.layoutInspectorNodeLines(nodeId)

proc layoutInspectorDetailLines*(): seq[string] =
  layoutInspectorNodeLines(layoutInspectorDetailNode())

func layoutErrorDebugText(index: int, error: LayoutError): string =
  &"#{index} {error.kind} node={int32(error.nodeId)} item={error.itemId}: {error.message}"

proc layoutInspectorErrorLines*(): seq[string] =
  let
    detail = layoutInspectorDetailNode()
    detailValid = g_uiState.layoutArena.validLayoutInspectorNode(detail)
    detailItem =
      if detailValid:
        g_uiState.layoutArena.nodes[int32(detail)].itemId
      else:
        0

  result = @["errors: " & $g_uiState.layoutArena.errors.len]
  if g_uiState.layoutArena.errors.len == 0:
    return

  var used = newSeq[bool](g_uiState.layoutArena.errors.len)
  var relatedCount = 0
  for i, error in g_uiState.layoutArena.errors:
    let relatedByNode =
      detailValid and int32(error.nodeId) >= 0 and int32(error.nodeId) == int32(detail)
    let relatedByItem = detailItem != 0 and error.itemId == detailItem
    if relatedByNode or relatedByItem:
      if relatedCount == 0:
        result.add("related errors:")
      result.add(layoutErrorDebugText(i, error))
      used[i] = true
      inc relatedCount

  var globalCount = 0
  for i in countdown(g_uiState.layoutArena.errors.high, 0):
    if used[i]:
      continue
    if globalCount == 0:
      result.add("recent errors:")
    result.add(layoutErrorDebugText(i, g_uiState.layoutArena.errors[i]))
    inc globalCount

const
  LayoutInspectorTreeRowHeight = 18.0
  LayoutInspectorTreeIndent = 14.0
  LayoutInspectorTreeDisclosureWidth = 14.0

func hasCollapsedLayoutNode(debug: LayoutDebugState, key: string): bool =
  for collapsed in debug.collapsedNodes:
    if collapsed == key:
      return true

proc toggleCollapsedLayoutNode(debug: var LayoutDebugState, key: string) =
  for i, collapsed in debug.collapsedNodes:
    if collapsed == key:
      debug.collapsedNodes.delete(i)
      return
  debug.collapsedNodes.add(key)

func layoutInspectorErrorCountFor(arena: LayoutArena, node: LayoutNode): int =
  for error in arena.errors:
    let matchesNode = int32(error.nodeId) >= 0 and int32(error.nodeId) == int32(node.id)
    let matchesItem = node.itemId != 0 and error.itemId == node.itemId
    if matchesNode or matchesItem:
      inc result

func layoutInspectorCollapseKey(node: LayoutNode, path: string): string =
  if node.itemId != 0:
    "item:" & $node.itemId
  else:
    "path:" & path

func layoutInspectorNodeLabel(node: LayoutNode, errorCount: int): string =
  result = &"#{int32(node.id)} {node.kind}"
  if node.itemId != 0:
    result.add(&" item={node.itemId}")
  if node.kind == lnkText:
    result.add(" text")
  if node.placement.kind == lpkAttach:
    result.add(" attach")
  elif node.placement.kind == lpkFollow:
    result.add(" follow")
  if node.aspectRatio > 0:
    result.add(" aspect")
  if errorCount > 0:
    result.add(&" !{errorCount}")

proc layoutInspectorTreeRows(
    arena: LayoutArena, debug: LayoutDebugState
): seq[LayoutInspectorTreeRow] =
  var stack: seq[tuple[id: LayoutNodeId, depth: int, path: string]]
  var roots: seq[LayoutNodeId]
  for node in arena.nodes:
    if node.parent.isNull:
      roots.add(node.id)

  for i in countdown(roots.high, 0):
    stack.add((roots[i], 0, $i))

  while stack.len > 0:
    let entry = stack.pop()
    if not arena.validLayoutInspectorNode(entry.id):
      continue

    let node = arena.nodes[int32(entry.id)]
    let errorCount = arena.layoutInspectorErrorCountFor(node)
    let collapseKey = node.layoutInspectorCollapseKey(entry.path)
    let collapsed = debug.hasCollapsedLayoutNode(collapseKey)
    result.add(
      LayoutInspectorTreeRow(
        nodeId: entry.id,
        depth: entry.depth,
        label: node.layoutInspectorNodeLabel(errorCount),
        hasChildren: node.childCount > 0,
        collapsed: collapsed,
        selected: int32(entry.id) == int32(debug.selectedNode),
        hovered: int32(entry.id) == int32(debug.treeHoveredNode),
        errorCount: errorCount,
        collapseKey: collapseKey,
      )
    )

    if collapsed:
      continue

    for i in countdown(int(node.childCount) - 1, 0):
      let childId = arena.childIndices[int(node.firstChild) + i]
      stack.add((childId, entry.depth + 1, entry.path & "." & $i))

proc layoutInspectorTreeRows*(): seq[LayoutInspectorTreeRow] =
  g_uiState.layoutArena.layoutInspectorTreeRows(g_uiState.layoutDebug)

func clampLayoutInspectorTreeScroll(scroll, treeHeight: float, rowCount: int): float =
  let maxScroll = max(0.0, rowCount.float * LayoutInspectorTreeRowHeight - treeHeight)
  scroll.clamp(0.0, maxScroll)

func layoutInspectorTreeAreaHeight(panelHeight: float): float =
  let preferred = max(120.0, panelHeight * 0.4)
  min(preferred, max(0.0, panelHeight - 120.0))

proc updateLayoutInspectorTreeInteraction(
    ui: var UIState, treeX, treeY, treeW, treeH: float
) =
  if treeH <= 0:
    ui.layoutDebug.treeHoveredNode = NullLayoutNodeId
    return

  let insideTree =
    ui.mx >= treeX and ui.mx <= treeX + treeW and ui.my >= treeY and
    ui.my <= treeY + treeH
  var rows = ui.layoutArena.layoutInspectorTreeRows(ui.layoutDebug)
  ui.layoutDebug.treeScroll =
    clampLayoutInspectorTreeScroll(ui.layoutDebug.treeScroll, treeH, rows.len)

  ui.layoutDebug.treeHoveredNode = NullLayoutNodeId
  if insideTree:
    let rowIndex = floor(
      (ui.my - treeY + ui.layoutDebug.treeScroll) / LayoutInspectorTreeRowHeight
    ).int
    if rowIndex >= 0 and rowIndex < rows.len:
      let row = rows[rowIndex]
      ui.layoutDebug.treeHoveredNode = row.nodeId
      ui.layoutDebug.hoveredNode = row.nodeId

      if ui.hasEvent and not ui.eventHandled and ui.currEvent.kind == ekScroll:
        ui.layoutDebug.treeScroll = clampLayoutInspectorTreeScroll(
          ui.layoutDebug.treeScroll -
            ui.currEvent.oy.float * LayoutInspectorTreeRowHeight * 3,
          treeH,
          rows.len,
        )
        markEventHandled()
      elif ui.hasEvent and not ui.eventHandled and ui.currEvent.kind == ekMouseButton and
          ui.currEvent.button == mbLeft and ui.currEvent.pressed:
        let disclosureX = treeX + 4.0 + row.depth.float * LayoutInspectorTreeIndent
        if row.hasChildren and ui.mx >= disclosureX and
            ui.mx <= disclosureX + LayoutInspectorTreeDisclosureWidth:
          ui.layoutDebug.toggleCollapsedLayoutNode(row.collapseKey)
        ui.layoutDebug.selectedNode = row.nodeId
        markEventHandled()
  elif ui.hasEvent and not ui.eventHandled and ui.currEvent.kind == ekScroll:
    discard
