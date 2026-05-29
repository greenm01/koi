import std/tables

import nanovg

import koi/types
import koi/core
import koi/drawing
import koi/layout
import koi/rect
import koi/defaults
import koi/input
import koi/internal/algorithms
import koi/internal/widget_behavior
import koi/widgets/listview
import koi/utils

var
  tableCellX = 0.0
  tableCellY = 0.0
  tableCellH = 0.0
  tableCellIndex = 0
  tableColumnWidthsCache: seq[float]
  activeTableStyle = borrowDefaultTableStyle()

const TableResizeHitWidth = 6.0
const TableMinColumnWidth = 24.0

proc ensureTableColumnWidths(
    columns: openArray[TableColumn], availableWidth: float, widths: var seq[float]
) =
  if widths.len != columns.len:
    widths = tableColumnWidths(columns, availableWidth)

proc drawTableHeaderWithSlot*(
    slot: LayoutSlot,
    columns: openArray[TableColumn],
    style: TableStyle = borrowDefaultTableStyle(),
    disabled: bool = false,
) =
  alias(ui, g_uiState)
  let
    tableColumns = @columns
    widths = tableColumnWidths(columns, slot.bounds.w)

  addLayoutDrawLayer(ui.currentLayer, slot.nodeId, vg, bounds):
    vg.fillColor(style.headerFillColor)
    vg.strokeColor(style.strokeColor)
    vg.strokeWidth(style.strokeWidth)
    vg.beginPath()
    vg.rect(bounds.x, bounds.y, bounds.w, bounds.h)
    vg.fill()
    vg.stroke()

    var cx = bounds.x
    let state = if disabled: wsDisabled else: wsNormal
    for i, column in tableColumns:
      let cw = widths[i]
      vg.drawLabel(cx, bounds.y, cw, bounds.h, column.label, state, style.headerLabel)
      cx += cw

proc drawTableHeader*(
    x, y, w: float,
    columns: openArray[TableColumn],
    style: TableStyle = borrowDefaultTableStyle(),
    disabled: bool = false,
) =
  let
    (sx, sy) = addDrawOffset(x, y)
    slot = layoutDrawSlot(0, rect(sx, sy, w, style.headerHeight))
  drawTableHeaderWithSlot(slot, columns, style, disabled)

proc drawTableHeaderWithSlot*(
    slot: LayoutSlot,
    id: ItemId,
    columns: openArray[TableColumn],
    widths: var seq[float],
    sortState: var TableSortState,
    style: TableStyle = borrowDefaultTableStyle(),
    disabled: bool = false,
) =
  alias(ui, g_uiState)
  let
    tableColumns = @columns
    hitBounds = slot.previousBounds

  ensureTableColumnWidths(columns, slot.bounds.w, widths)

  var cx = hitBounds.x
  for i, column in tableColumns:
    let
      cw = widths[i]
      sortId = hashId($id & ":sort:" & $i)
      resizeId = hashId($id & ":resize:" & $i)
      headerHit = isHit(cx, hitBounds.y, cw, hitBounds.h)
      resizeHit =
        i < tableColumns.high and
        isHit(
          cx + cw - TableResizeHitWidth * 0.5,
          hitBounds.y,
          TableResizeHitWidth,
          hitBounds.h,
        )

    if resizeHit:
      discard captureDragWidget(resizeId, true, disabled = disabled)
    elif headerHit:
      captureSimpleWidget(sortId, disabled)

    if not disabled and i < tableColumns.high and isActive(resizeId) and ui.mbLeftDown:
      widths =
        resizedTableColumnWidths(widths, i, ui.mx - ui.lastmx, TableMinColumnWidth)

    let behavior = simpleWidgetBehavior(sortId, disabled)
    if behavior.clicked:
      sortState = nextTableSortState(sortState, i)

    cx += cw

  let
    drawWidths = widths
    drawSortState = sortState

  addLayoutDrawLayer(ui.currentLayer, slot.nodeId, vg, bounds):
    vg.fillColor(style.headerFillColor)
    vg.strokeColor(style.strokeColor)
    vg.strokeWidth(style.strokeWidth)
    vg.beginPath()
    vg.rect(bounds.x, bounds.y, bounds.w, bounds.h)
    vg.fill()
    vg.stroke()

    var cx = bounds.x
    for i, column in tableColumns:
      let
        cw = drawWidths[i]
        sortMark =
          if drawSortState.column == i and drawSortState.direction == tsdAsc:
            " ^"
          elif drawSortState.column == i and drawSortState.direction == tsdDesc:
            " v"
          else:
            ""
      let state = if disabled: wsDisabled else: wsNormal
      vg.drawLabel(
        cx, bounds.y, cw, bounds.h, column.label & sortMark, state, style.headerLabel
      )
      if i < tableColumns.high:
        vg.beginPath()
        vg.vertLine(cx + cw, bounds.y, bounds.h)
        vg.stroke()
      cx += cw

proc drawTableHeader*(
    id: ItemId,
    x, y, w: float,
    columns: openArray[TableColumn],
    widths: var seq[float],
    sortState: var TableSortState,
    style: TableStyle = borrowDefaultTableStyle(),
    disabled: bool = false,
) =
  let
    (sx, sy) = addDrawOffset(x, y)
    slot = layoutSlot(id, rect(sx, sy, w, style.headerHeight))
  drawTableHeaderWithSlot(slot, id, columns, widths, sortState, style, disabled)

proc beginTableRow*(
    rowIndex: Natural,
    widths: openArray[float],
    rowY, rowH, tableW: float,
    style: TableStyle = borrowDefaultTableStyle(),
) =
  alias(ui, g_uiState)
  tableCellX = 0
  tableCellY = rowY
  tableCellH = rowH
  tableCellIndex = 0
  tableColumnWidthsCache = @widths
  activeTableStyle = style
  let slot = layoutDrawSlot(0, rect(0, rowY, tableW, rowH))

  addLayoutDrawLayer(ui.currentLayer, slot.nodeId, vg, bounds):
    let fill = if rowIndex mod 2 == 0: style.rowFillColor else: style.rowAltFillColor
    vg.fillColor(fill)
    vg.beginPath()
    vg.rect(bounds.x, bounds.y, bounds.w, bounds.h)
    vg.fill()

proc tableCell*(text: string, style: TableStyle = activeTableStyle) =
  if tableCellIndex > tableColumnWidthsCache.high:
    return

  let
    x = tableCellX
    y = tableCellY
    w = tableColumnWidthsCache[tableCellIndex]
    h = tableCellH

  alias(ui, g_uiState)
  let slot = layoutDrawSlot(0, rect(x, y, w, h))
  addLayoutDrawLayer(ui.currentLayer, slot.nodeId, vg, bounds):
    vg.drawLabel(bounds.x, bounds.y, bounds.w, bounds.h, text, wsNormal, style.rowLabel)

  tableCellX += w
  inc(tableCellIndex)

template tableView*(
    x, y, w, h: float,
    columns: openArray[TableColumn],
    itemCount: Natural,
    index: untyped,
    body: untyped,
    style: TableStyle = borrowDefaultTableStyle(),
    disabled: bool = false,
) =
  let
    i = instantiationInfo(fullPaths = true)
    id = nextId(i.filename, i.line)
    headerId = hashId($id & ":header")
    bodyId = hashId($id & ":body")
    widths = tableColumnWidths(columns, w)
    rowH = style.rowHeight
    headerH = style.headerHeight
    (sx, sy) = addDrawOffset(x, y)
    tableSlot = layoutContainerSlot(
      id, rect(sx, sy, w, h), direction = ldTopToBottom, alignCross = lcaStretch
    )
    headerSlot = layoutChildSlot(
      tableSlot.nodeId, headerId, rect(sx, sy, w, headerH), grow(), fixed(headerH)
    )
    bodyH = max(0.0, h - headerH)
    bodyScrollY =
      if g_uiState.itemState.hasKey(bodyId):
        scrollViewStartY(bodyId)
      else:
        0.0
    bodySlot = beginLayoutChildContainerSlotAt(
      tableSlot.nodeId,
      bodyId,
      rect(sx, sy + headerH, w, bodyH),
      rect(sx, sy + headerH - bodyScrollY, w, bodyH),
      grow(),
      grow(min = 0.0),
      scrollOffset = size(0, bodyScrollY),
    )
    range = beginListViewWithSlot(bodyId, bodySlot, itemCount, rowH)

  drawTableHeaderWithSlot(headerSlot, columns, style, disabled)
  try:
    if itemCount > 0 and rowH > 0:
      for index in range.first .. range.last:
        beginTableRow(index.Natural, widths, index.float * rowH, rowH, w, style)
        body
  finally:
    endListView(range)

template tableView*(
    x, y, w, h: float,
    columns: openArray[TableColumn],
    columnWidths: var seq[float],
    sortState: var TableSortState,
    itemCount: Natural,
    index: untyped,
    body: untyped,
    style: TableStyle = borrowDefaultTableStyle(),
    disabled: bool = false,
) =
  let
    i = instantiationInfo(fullPaths = true)
    id = nextId(i.filename, i.line)
    tableId = hashId($id & ":table")
    bodyId = hashId($id & ":body")
    rowH = style.rowHeight
    headerH = style.headerHeight

  ensureTableColumnWidths(columns, w, columnWidths)
  let
    (sx, sy) = addDrawOffset(x, y)
    tableSlot = layoutContainerSlot(
      tableId, rect(sx, sy, w, h), direction = ldTopToBottom, alignCross = lcaStretch
    )
    headerSlot = layoutChildSlot(
      tableSlot.nodeId, id, rect(sx, sy, w, headerH), grow(), fixed(headerH)
    )
    bodyH = max(0.0, h - headerH)
    bodyScrollY =
      if g_uiState.itemState.hasKey(bodyId):
        scrollViewStartY(bodyId)
      else:
        0.0
    bodySlot = beginLayoutChildContainerSlotAt(
      tableSlot.nodeId,
      bodyId,
      rect(sx, sy + headerH, w, bodyH),
      rect(sx, sy + headerH - bodyScrollY, w, bodyH),
      grow(),
      grow(min = 0.0),
      scrollOffset = size(0, bodyScrollY),
    )
    range = beginListViewWithSlot(bodyId, bodySlot, itemCount, rowH)

  drawTableHeaderWithSlot(
    headerSlot, id, columns, columnWidths, sortState, style, disabled
  )
  try:
    if itemCount > 0 and rowH > 0:
      for index in range.first .. range.last:
        beginTableRow(index.Natural, columnWidths, index.float * rowH, rowH, w, style)
        body
  finally:
    endListView(range)
