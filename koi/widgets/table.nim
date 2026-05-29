import nanovg

import koi/types
import koi/core
import koi/drawing
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

proc drawTableHeader*(
    x, y, w: float,
    columns: openArray[TableColumn],
    style: TableStyle = borrowDefaultTableStyle(),
) =
  alias(ui, g_uiState)
  let
    (sx, sy) = addDrawOffset(x, y)
    tableColumns = @columns
    widths = tableColumnWidths(columns, w)

  addDrawLayer(ui.currentLayer, vg):
    vg.fillColor(style.headerFillColor)
    vg.strokeColor(style.strokeColor)
    vg.strokeWidth(style.strokeWidth)
    vg.beginPath()
    vg.rect(sx, sy, w, style.headerHeight)
    vg.fill()
    vg.stroke()

    var cx = sx
    for i, column in tableColumns:
      let cw = widths[i]
      vg.drawLabel(
        cx, sy, cw, style.headerHeight, column.label, wsNormal, style.headerLabel
      )
      cx += cw

proc drawTableHeader*(
    id: ItemId,
    x, y, w: float,
    columns: openArray[TableColumn],
    widths: var seq[float],
    sortState: var TableSortState,
    style: TableStyle = borrowDefaultTableStyle(),
) =
  alias(ui, g_uiState)
  let
    (sx, sy) = addDrawOffset(x, y)
    tableColumns = @columns

  ensureTableColumnWidths(columns, w, widths)

  var cx = sx
  for i, column in tableColumns:
    let
      cw = widths[i]
      sortId = hashId($id & ":sort:" & $i)
      resizeId = hashId($id & ":resize:" & $i)
      headerHit = isHit(cx, sy, cw, style.headerHeight)
      resizeHit =
        i < tableColumns.high and
        isHit(
          cx + cw - TableResizeHitWidth * 0.5,
          sy,
          TableResizeHitWidth,
          style.headerHeight,
        )

    if resizeHit:
      discard captureDragWidget(resizeId, true)
    elif headerHit:
      captureSimpleWidget(sortId, disabled = false)

    if i < tableColumns.high and isActive(resizeId) and ui.mbLeftDown:
      widths =
        resizedTableColumnWidths(widths, i, ui.mx - ui.lastmx, TableMinColumnWidth)

    let behavior = simpleWidgetBehavior(sortId, disabled = false)
    if behavior.clicked:
      sortState = nextTableSortState(sortState, i)

    cx += cw

  let
    drawWidths = widths
    drawSortState = sortState

  addDrawLayer(ui.currentLayer, vg):
    vg.fillColor(style.headerFillColor)
    vg.strokeColor(style.strokeColor)
    vg.strokeWidth(style.strokeWidth)
    vg.beginPath()
    vg.rect(sx, sy, w, style.headerHeight)
    vg.fill()
    vg.stroke()

    var cx = sx
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
      vg.drawLabel(
        cx,
        sy,
        cw,
        style.headerHeight,
        column.label & sortMark,
        wsNormal,
        style.headerLabel,
      )
      if i < tableColumns.high:
        vg.beginPath()
        vg.vertLine(cx + cw, sy, style.headerHeight)
        vg.stroke()
      cx += cw

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

  addDrawLayer(ui.currentLayer, vg):
    let fill = if rowIndex mod 2 == 0: style.rowFillColor else: style.rowAltFillColor
    vg.fillColor(fill)
    vg.beginPath()
    vg.rect(0, rowY, tableW, rowH)
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
  addDrawLayer(ui.currentLayer, vg):
    vg.drawLabel(x, y, w, h, text, wsNormal, style.rowLabel)

  tableCellX += w
  inc(tableCellIndex)

template tableView*(
    x, y, w, h: float,
    columns: openArray[TableColumn],
    itemCount: Natural,
    index: untyped,
    body: untyped,
    style: TableStyle = borrowDefaultTableStyle(),
) =
  let
    widths = tableColumnWidths(columns, w)
    rowH = style.rowHeight
    headerH = style.headerHeight

  drawTableHeader(x, y, w, columns, style)
  listView(x, y + headerH, w, max(0.0, h - headerH), itemCount, rowH, index):
    beginTableRow(index.Natural, widths, index.float * rowH, rowH, w, style)
    body

template tableView*(
    x, y, w, h: float,
    columns: openArray[TableColumn],
    columnWidths: var seq[float],
    sortState: var TableSortState,
    itemCount: Natural,
    index: untyped,
    body: untyped,
    style: TableStyle = borrowDefaultTableStyle(),
) =
  let
    i = instantiationInfo(fullPaths = true)
    id = nextId(i.filename, i.line)
    rowH = style.rowHeight
    headerH = style.headerHeight

  ensureTableColumnWidths(columns, w, columnWidths)
  drawTableHeader(id, x, y, w, columns, columnWidths, sortState, style)
  listView(x, y + headerH, w, max(0.0, h - headerH), itemCount, rowH, index):
    beginTableRow(index.Natural, columnWidths, index.float * rowH, rowH, w, style)
    body
