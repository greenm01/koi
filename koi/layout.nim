import std/math
import std/options
import std/strutils
import std/tables
import std/unicode

import nanovg
import koi/core
import koi/drawing
import koi/internal/layout_solver
import koi/rect
import koi/types
import koi/utils

export layout_solver

# Layout engine: standard auto-layout and hierarchical blocks

const LayoutTextBreakChars = [
  " ", "\u2000", "\u2001", "\u2002", "\u2003", "\u2004", "\u2005", "\u2006", "\u2008",
  "\u2009", "\u200a", "\u205f", "\u3000", "-", "\u00ad", "\u2010", "\u2012", "\u2013",
  "|", "\n",
]

func isLayoutTextBreak(r: Rune): bool =
  let s = $r
  for ch in LayoutTextBreakChars:
    if s == ch:
      return true

func textMeasureSegments(text: string): seq[string] =
  var segment = ""
  for rune in text.runes:
    if rune.isLayoutTextBreak:
      if segment.len > 0:
        result.add(segment)
        segment.setLen(0)
    else:
      segment.add($rune)

  if segment.len > 0:
    result.add(segment)

  if result.len == 0:
    result.add("")

func explicitLineCount(text: string): int =
  max(1, text.count("\n") + 1)

proc fallbackMeasureText(text: string, fontSize, maxWidth: float): TextMeasure =
  let
    fontSize = if fontSize > 0: fontSize else: 14.0
    advance = max(1.0, fontSize * 0.5)
    prefWidth = text.runeLen.float * advance
    lineHeight = fontSize * 1.4

  var longest = 0
  for segment in text.textMeasureSegments:
    longest = max(longest, segment.runeLen)

  let lineCount =
    if maxWidth <= 0 or maxWidth >= LayoutInfinity * 0.5:
      text.explicitLineCount
    else:
      max(text.explicitLineCount, ceil(prefWidth / maxWidth).int)

  TextMeasure(
    minWidth: longest.float * advance,
    prefWidth: prefWidth,
    lineHeight: lineHeight,
    lineCount: lineCount,
  )

proc measureLayoutText*(
    text: string, fontSize: float, fontFace: string, maxWidth: float
): TextMeasure =
  let
    fontSize = if fontSize > 0: fontSize else: 14.0
    fontFace = if fontFace.len > 0: fontFace else: "sans-bold"
    lineHeight = fontSize * 1.4

  if g_nvgContext == nil:
    return fallbackMeasureText(text, fontSize, maxWidth)

  g_nvgContext.useFont(fontSize, name = fontFace)

  var minWidth = 0.0
  for segment in text.textMeasureSegments:
    minWidth = max(minWidth, g_nvgContext.textWidth(segment))

  let lineCount =
    if maxWidth <= 0 or maxWidth >= LayoutInfinity * 0.5:
      text.explicitLineCount
    else:
      max(1, textBreakLines(text, maxWidth).len)

  TextMeasure(
    minWidth: minWidth,
    prefWidth: g_nvgContext.textWidth(text),
    lineHeight: lineHeight,
    lineCount: lineCount,
  )

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
    of lpmSpace:
      result = manual(fallback.x - frame.x, fallback.y - frame.y)

proc previousLayoutRect*(id: ItemId, fallback: Rect): Rect =
  alias(ui, g_uiState)
  if ui.layoutRects.hasKey(id):
    ui.layoutRects[id]
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

proc layoutDrawSlot*(id: ItemId, fallback: Rect): LayoutSlot =
  layoutSlotWithSizing(
    id, fallback, fixed(fallback.w), fixed(fallback.h), NullLayoutNodeId
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

template addLayoutDrawLayer*(
    layer: DrawLayer, nodeId: LayoutNodeId, vg, bounds, body: untyped
) =
  let capturedNodeId = nodeId
  addDrawLayer(layer, vg):
    let bounds {.inject.} = g_uiState.layoutArena.layoutRect(capturedNodeId)
    body

proc finishFrameLayout*() =
  alias(ui, g_uiState)

  while ui.layoutArena.nodeStack.len > 0:
    discard ui.layoutArena.endLayoutNode()

  ui.layoutArena.solveLayout(rect(0, 0, ui.winWidth, ui.winHeight), ui.layoutRoot)

  var solvedRects: Table[ItemId, Rect]
  for node in ui.layoutArena.nodes:
    if node.itemId != 0:
      solvedRects[node.itemId] = node.rect
  ui.layoutRects = solvedRects

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

proc initAutoLayout*(params: AutoLayoutParams) =
  alias(ui, g_uiState)
  alias(a, ui.autoLayoutState)
  ui.autoLayoutParams = params

  a = AutoLayoutStateVars.default

  a.rowWidth = params.rowWidth
  a.nextItemHeight = params.defaultItemHeight
  a.firstRow = true
  a.autoRoot = NullLayoutNodeId
  a.autoRow = NullLayoutNodeId
  a.activeSlotParent = NullLayoutNodeId

proc nextRowHeight*(h: float) =
  g_uiState.autoLayoutState.nextRowHeight = h.some

proc nextItemWidth*(w: float) =
  alias(a, g_uiState.autoLayoutState)
  a.nextItemWidth = w
  a.nextItemWidthOverride = w.some

proc nextItemHeight*(h: float) =
  alias(a, g_uiState.autoLayoutState)
  a.nextItemHeight = h
  a.nextItemHeightOverride = h.some

proc autoLayoutNextY*(): float =
  alias(a, g_uiState.autoLayoutState)
  result = a.y
  let dy = a.rowHeight - a.nextItemHeight.clamp(0, a.rowHeight)
  if dy > 0:
    result += round(dy * 0.5)

proc autoLayoutNextX*(): float =
  g_uiState.autoLayoutState.x

proc autoLayoutNextItemWidth*(): float =
  g_uiState.autoLayoutState.nextItemWidth

proc autoLayoutNextItemHeight*(): float =
  alias(a, g_uiState.autoLayoutState)
  a.nextItemHeight.clamp(0, a.rowHeight)

proc autoLayoutNextBounds*(): Rect =
  rect(
    autoLayoutNextX(),
    autoLayoutNextY(),
    autoLayoutNextItemWidth(),
    autoLayoutNextItemHeight(),
  )

proc nextWidgetBounds*(): Rect =
  autoLayoutNextBounds()

func effectiveItemsPerRow(ap: AutoLayoutParams): Natural =
  max(ap.itemsPerRow, 1)

func resolvedRowWidths(
    columns: openArray[LayoutColumn],
    availableWidth, itemSpacing: float,
    ap: AutoLayoutParams,
): seq[float] =
  result = newSeq[float](columns.len)
  if columns.len == 0:
    return

  let spacingWidth = itemSpacing * max(columns.len - 1, 0).float
  let usableWidth = max(0.0, availableWidth - ap.leftPad - ap.rightPad - spacingWidth)

  var staticWidth = 0.0
  var variableMinWidth = 0.0
  var ratioWidth = 0.0
  var dynamicCount = 0
  var variableCount = 0

  for column in columns:
    case column.mode
    of cmStatic:
      staticWidth += max(0.0, column.value)
    of cmVariable:
      variableMinWidth += max(0.0, column.value)
      if column.mode == cmVariable:
        inc(variableCount)
    of cmRatio:
      ratioWidth += usableWidth * column.value.clamp(0.0, 1.0)
    of cmDynamic:
      inc(dynamicCount)

  let remainingWidth =
    max(0.0, usableWidth - staticWidth - variableMinWidth - ratioWidth)
  let flexibleCount = dynamicCount + variableCount
  let flexibleWidth =
    if flexibleCount > 0:
      remainingWidth / flexibleCount.float
    else:
      0.0

  for i, column in columns:
    result[i] =
      case column.mode
      of cmStatic:
        max(0.0, column.value)
      of cmVariable:
        max(0.0, column.value) + flexibleWidth
      of cmRatio:
        usableWidth * column.value.clamp(0.0, 1.0)
      of cmDynamic:
        flexibleWidth

func rowColumnLayoutSize(column: LayoutColumn): LayoutSize =
  case column.mode
  of cmStatic:
    fixed(max(0.0, column.value))
  of cmRatio:
    percent(column.value.clamp(0.0, 1.0))
  of cmDynamic:
    grow()
  of cmVariable:
    grow(min = max(0.0, column.value))

func resolvedRowSizes(columns: openArray[LayoutColumn]): seq[LayoutSize] =
  result = newSeq[LayoutSize](columns.len)
  for i, column in columns:
    result[i] = column.rowColumnLayoutSize()

func legacyColumnWidth(
    node: LayoutPresetFrame, column: LayoutColumn, ap: AutoLayoutParams
): float =
  case column.mode
  of cmStatic:
    max(0.0, column.value)
  of cmRatio:
    let totalW = max(0.0, node.availableWidth - ap.leftPad - ap.rightPad)
    totalW * column.value.clamp(0.0, 1.0)
  of cmDynamic:
    max(0.0, node.availableWidth - (node.currentX - node.x) - ap.rightPad)
  of cmVariable:
    max(0.0, column.value)

proc currentRowColumn(node: LayoutPresetFrame): LayoutColumn =
  if node.columns.len > 0:
    let i = min(node.colIndex, node.columns.high)
    result = node.columns[i]
  elif node.hasCurrentColumn:
    result = node.currentColumn
  else:
    result = colDynamic()

proc currentRowWidth(node: LayoutPresetFrame, ap: AutoLayoutParams): float =
  if node.columns.len > 0:
    let i = min(node.colIndex, node.resolvedWidths.high)
    result = node.resolvedWidths[i]
  else:
    result = node.legacyColumnWidth(node.currentRowColumn(), ap)

proc currentRowLayoutSize(node: LayoutPresetFrame, ap: AutoLayoutParams): LayoutSize =
  if node.columns.len > 0:
    let i = min(node.colIndex, node.resolvedSizes.high)
    result = node.resolvedSizes[i]
  else:
    result = node.currentRowColumn().rowColumnLayoutSize()

proc applyNextItemOverrides(a: var AutoLayoutStateVars) =
  if a.nextItemWidthOverride.isSome:
    a.nextItemWidth = a.nextItemWidthOverride.get
    a.nextItemWidthOverride = float.none

  if a.nextItemHeightOverride.isSome:
    a.nextItemHeight = a.nextItemHeightOverride.get
    a.nextItemHeightOverride = float.none

proc ensureAutoLayoutRoot(ui: var UIState): LayoutNodeId =
  alias(a, ui.autoLayoutState)
  if not ui.frameLayoutActive():
    return NullLayoutNodeId
  if not a.autoRoot.isNull:
    return a.autoRoot

  let offset = drawOffset()
  a.autoRoot = ui.layoutArena.addLayoutNode(
    layoutNode(
      width = fixed(a.rowWidth),
      height = fit(),
      direction = ldTopToBottom,
      placement = manual(offset.ox, offset.oy),
    ),
    ui.layoutRoot,
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

  if ui.layoutStack.len != 0:
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

  let rowSlotOwned =
    ui.layoutStack.len > 0 and ui.layoutStack[^1].mode == lpmRow
  if rowSlotOwned:
    autoLayoutPre()

  let width =
    if rowSlotOwned or ui.layoutStack.len > 0:
      a.nextItemWidth
    else:
      a.rowWidth
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
    ui.autoLayoutState.firstRow = false

proc beginColumn*(mode: ColMode, value: float = 0.0) =
  alias(ui, g_uiState)
  if ui.layoutStack.len > 0 and ui.layoutStack[^1].mode == lpmRow:
    alias(node, ui.layoutStack[^1])
    node.currentColumn = LayoutColumn(mode: mode, value: value)
    node.hasCurrentColumn = true

proc endColumn*() =
  alias(ui, g_uiState)
  if ui.layoutStack.len > 0 and ui.layoutStack[^1].mode == lpmRow:
    ui.layoutStack[^1].hasCurrentColumn = false

template layoutRow*(height: float, body: untyped) =
  beginRowLayout(height)
  try:
    body
  finally:
    endLayout()

template layoutRow*(height: float, columns: openArray[LayoutColumn], body: untyped) =
  beginRowLayout(height, columns)
  try:
    body
  finally:
    endLayout()

template layoutSpace*(height: float, body: untyped) =
  beginSpaceLayout(height)
  try:
    body
  finally:
    endLayout()

template col*(width: float, body: untyped) =
  beginColumn(cmStatic, width)
  try:
    body
  finally:
    endColumn()

template colDynamic*(body: untyped) =
  beginColumn(cmDynamic)
  try:
    body
  finally:
    endColumn()

template colRatio*(ratio: float, body: untyped) =
  beginColumn(cmRatio, ratio)
  try:
    body
  finally:
    endColumn()

template colVariable*(minWidth: float, body: untyped) =
  beginColumn(cmVariable, minWidth)
  try:
    body
  finally:
    endColumn()

proc layoutSpaceBounds*(): Rect =
  alias(ui, g_uiState)
  if ui.layoutStack.len > 0 and ui.layoutStack[^1].mode == lpmSpace:
    let node = ui.layoutStack[^1]
    result = rect(0, 0, node.w, node.h)
  else:
    result = autoLayoutNextBounds()

proc layoutSpaceRatioRect*(x, y, w, h: float): Rect =
  let b = layoutSpaceBounds()
  let
    rx = x.clamp(0.0, 1.0)
    ry = y.clamp(0.0, 1.0)
    rw = w.clamp(0.0, 1.0 - rx)
    rh = h.clamp(0.0, 1.0 - ry)
  rect(b.x + b.w * rx, b.y + b.h * ry, b.w * rw, b.h * rh)

proc layoutSpaceToScreen*(x, y: float): (float, float) =
  addDrawOffset(x, y)

proc layoutSpaceToLocal*(x, y: float): (float, float) =
  let offset = drawOffset()
  (x - offset.ox, y - offset.oy)

proc layoutSpaceRectToScreen*(r: Rect): Rect =
  let (x, y) = layoutSpaceToScreen(r.x, r.y)
  rect(x, y, r.w, r.h)

proc layoutSpaceRectToLocal*(r: Rect): Rect =
  let (x, y) = layoutSpaceToLocal(r.x, r.y)
  rect(x, y, r.w, r.h)

proc beginGroup*() =
  g_uiState.autoLayoutState.groupBegin = true

proc endGroup*() =
  discard

template group*(body: untyped) =
  beginGroup()
  body
  endGroup()

proc nextLayoutColumn*() =
  autoLayoutPre()
  autoLayoutPost()
