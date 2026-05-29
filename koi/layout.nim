import std/math
import std/options

import koi/core
import koi/drawing
import koi/rect
import koi/types
import koi/utils

# Layout engine: standard auto-layout and hierarchical blocks

func col*(width: float): LayoutColumn =
  LayoutColumn(mode: cmStatic, value: width)

func colDynamic*(): LayoutColumn =
  LayoutColumn(mode: cmDynamic)

func colRatio*(ratio: float): LayoutColumn =
  LayoutColumn(mode: cmRatio, value: ratio)

func colVariable*(minWidth: float): LayoutColumn =
  LayoutColumn(mode: cmVariable, value: minWidth)

proc initAutoLayout*(params: AutoLayoutParams) =
  alias(ui, g_uiState)
  alias(a, ui.autoLayoutState)
  ui.autoLayoutParams = params

  a = AutoLayoutStateVars.default

  a.rowWidth = params.rowWidth
  a.nextItemHeight = params.defaultItemHeight
  a.firstRow = true

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

  var fixedWidth = 0.0
  var ratioWidth = 0.0
  var dynamicCount = 0
  var variableCount = 0

  for column in columns:
    case column.mode
    of cmStatic, cmVariable:
      fixedWidth += max(0.0, column.value)
      if column.mode == cmVariable:
        inc(variableCount)
    of cmRatio:
      ratioWidth += usableWidth * column.value.clamp(0.0, 1.0)
    of cmDynamic:
      inc(dynamicCount)

  let remainingWidth = max(0.0, usableWidth - fixedWidth - ratioWidth)
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
        max(max(0.0, column.value), flexibleWidth)
      of cmRatio:
        usableWidth * column.value.clamp(0.0, 1.0)
      of cmDynamic:
        flexibleWidth

func legacyColumnWidth(
    node: LayoutNode, column: LayoutColumn, ap: AutoLayoutParams
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

proc currentRowColumn(node: var LayoutNode): LayoutColumn =
  if node.columns.len > 0:
    let i = min(node.colIndex, node.columns.high)
    result = node.columns[i]
  elif node.hasCurrentColumn:
    result = node.currentColumn
  else:
    result = colDynamic()

proc currentRowWidth(node: var LayoutNode, ap: AutoLayoutParams): float =
  if node.columns.len > 0:
    let i = min(node.colIndex, node.resolvedWidths.high)
    result = node.resolvedWidths[i]
  else:
    result = node.legacyColumnWidth(node.currentRowColumn(), ap)

proc applyNextItemOverrides(a: var AutoLayoutStateVars) =
  if a.nextItemWidthOverride.isSome:
    a.nextItemWidth = a.nextItemWidthOverride.get
    a.nextItemWidthOverride = float.none

  if a.nextItemHeightOverride.isSome:
    a.nextItemHeight = a.nextItemHeightOverride.get
    a.nextItemHeightOverride = float.none

proc autoLayoutPre*(section: bool = false) =
  alias(ui, g_uiState)
  alias(a, ui.autoLayoutState)
  alias(ap, ui.autoLayoutParams)

  if ui.layoutStack.len > 0:
    alias(node, ui.layoutStack[^1])
    case node.mode
    of lmRow:
      a.rowHeight = node.rowHeight
      a.x = node.currentX
      a.y = node.y
      a.nextItemWidth = node.currentRowWidth(ap)
      a.nextItemHeight = ap.defaultItemHeight
      a.applyNextItemOverrides()
      return
    of lmSpace:
      a.x = 0
      a.y = 0
      a.rowHeight = node.h
      a.nextItemWidth = node.w
      a.nextItemHeight = node.h
      a.applyNextItemOverrides()
      return
    of lmNone:
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

proc autoLayoutPost*(section: bool = false) =
  alias(ui, g_uiState)
  alias(a, ui.autoLayoutState)
  alias(ap, ui.autoLayoutParams)

  if ui.layoutStack.len > 0:
    alias(node, ui.layoutStack[^1])
    case node.mode
    of lmRow:
      node.currentX += a.nextItemWidth
      if node.columns.len > 0 and node.colIndex < node.columns.high:
        node.currentX += node.itemSpacing
      inc(node.colIndex)
      node.hasCurrentColumn = false
      return
    of lmSpace:
      return
    of lmNone:
      discard

  let lastColumn = a.currColIndex == ap.effectiveItemsPerRow() - 1

  if lastColumn or section:
    a.currColIndex = 0
    a.y += a.rowHeight
    a.y += ap.sectionPad
    a.prevSection = section
    a.firstRow = false
  else:
    inc(a.currColIndex)

  a.lastItemWidth = a.nextItemWidth
  a.groupBegin = false

proc autoLayoutFinal*() =
  alias(ui, g_uiState)
  alias(a, ui.autoLayoutState)

  if a.prevSection:
    a.y -= ui.autoLayoutParams.sectionPad

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

  ui.layoutStack.add(
    LayoutNode(
      mode: lmRow,
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
    )
  )

proc beginSpaceLayout*(height: float) =
  alias(ui, g_uiState)
  alias(a, ui.autoLayoutState)

  let
    (x, y) = addDrawOffset(a.x, a.y)
    width = if ui.layoutStack.len > 0: a.nextItemWidth else: a.rowWidth

  ui.layoutStack.add(LayoutNode(mode: lmSpace, x: x, y: y, w: width, h: height))
  pushDrawOffset(DrawOffset(ox: x, oy: y))

proc endLayout*() =
  alias(ui, g_uiState)
  if ui.layoutStack.len > 0:
    let node = ui.layoutStack.pop()
    if node.mode == lmSpace:
      popDrawOffset()

    ui.autoLayoutState.y += node.h
    ui.autoLayoutState.y += ui.autoLayoutParams.sectionPad
    ui.autoLayoutState.firstRow = false

proc beginColumn*(mode: ColMode, value: float = 0.0) =
  alias(ui, g_uiState)
  if ui.layoutStack.len > 0 and ui.layoutStack[^1].mode == lmRow:
    alias(node, ui.layoutStack[^1])
    node.currentColumn = LayoutColumn(mode: mode, value: value)
    node.hasCurrentColumn = true

proc endColumn*() =
  alias(ui, g_uiState)
  if ui.layoutStack.len > 0 and ui.layoutStack[^1].mode == lmRow:
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
  if ui.layoutStack.len > 0 and ui.layoutStack[^1].mode == lmSpace:
    let node = ui.layoutStack[^1]
    result = rect(0, 0, node.w, node.h)
  else:
    result = autoLayoutNextBounds()

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
