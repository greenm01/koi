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
