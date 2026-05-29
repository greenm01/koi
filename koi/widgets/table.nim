import nanovg

import koi/types
import koi/core
import koi/drawing
import koi/defaults
import koi/internal/algorithms
import koi/widgets/listview
import koi/utils

var
  tableCellX = 0.0
  tableCellY = 0.0
  tableCellH = 0.0
  tableCellIndex = 0
  tableColumnWidthsCache: seq[float]
  activeTableStyle = borrowDefaultTableStyle()

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
