import nanovg

import koi/types
import koi/core
import koi/drawing
import koi/layout
import koi/defaults
import koi/internal/algorithms
import koi/utils

proc drawChartFrame(
    vg: NVGContext, x, y, w, h: float, label: string, style: ChartStyle
) =
  let (x, y, w, h) = snapToGrid(x, y, w, h, style.strokeWidth)
  vg.fillColor(style.backgroundColor)
  vg.strokeColor(style.strokeColor)
  vg.strokeWidth(style.strokeWidth)
  vg.beginPath()
  vg.rect(x, y, w, h)
  vg.fill()
  vg.stroke()

  if label.len > 0:
    vg.drawLabel(x, y, w, h, label, wsNormal, style.label)

proc plotChart*(
    x, y, w, h: float,
    series: openArray[ChartSeries],
    minValue, maxValue: float,
    label: string = "",
    style: ChartStyle = borrowDefaultChartStyle(),
) =
  alias(ui, g_uiState)
  let (x, y) = addDrawOffset(x, y)
  let chartSeries = @series

  addDrawLayer(ui.currentLayer, vg):
    vg.drawChartFrame(x, y, w, h, label, style)

    let hasColumns = block:
      var found = false
      for s in chartSeries:
        if s.kind == ckColumns and s.values.len > 0:
          found = true
      found

    if hasColumns:
      let zeroY = chartValueY(0, minValue, maxValue, y, h)
      vg.strokeColor(style.zeroLineColor)
      vg.strokeWidth(1)
      vg.beginPath()
      vg.horizLine(x, zeroY, w)
      vg.stroke()

    var columnSeriesCount = 0
    for s in chartSeries:
      if s.kind == ckColumns:
        inc(columnSeriesCount)

    var columnSeriesIndex = 0
    for s in chartSeries:
      if s.values.len == 0:
        continue

      case s.kind
      of ckLine:
        vg.strokeColor(s.color)
        vg.strokeWidth(style.lineWidth)
        vg.beginPath()
        for i, value in s.values:
          let
            px = chartPointX(i.Natural, s.values.len.Natural, x, w)
            py = chartValueY(value, minValue, maxValue, y, h)
          if i == 0:
            vg.moveTo(px, py)
          else:
            vg.lineTo(px, py)
        vg.stroke()
      of ckColumns:
        vg.fillColor(s.color)
        for i, value in s.values:
          var r = chartColumnRect(
            i.Natural, s.values.len.Natural, value, minValue, maxValue, x, y, w, h,
            style.columnGap,
          )
          if columnSeriesCount > 1:
            let columnW = r.w / columnSeriesCount.float
            r.x += columnW * columnSeriesIndex.float
            r.w = max(1.0, columnW - style.columnGap)
          vg.beginPath()
          vg.rect(r.x, r.y, r.w, r.h)
          vg.fill()
        inc(columnSeriesIndex)

    var legendX = x + 6
    let legendY = y + 6
    for s in chartSeries:
      if s.label.len == 0:
        continue
      vg.fillColor(s.color)
      vg.beginPath()
      vg.rect(legendX, legendY + 4, 8, 8)
      vg.fill()
      vg.drawLabel(legendX + 12, legendY, 90, 16, s.label, wsNormal, style.label)
      legendX += 104

proc plotLine*(
    x, y, w, h: float,
    values: openArray[float],
    minValue, maxValue: float,
    label: string = "",
    style: ChartStyle = borrowDefaultChartStyle(),
) =
  let series =
    [ChartSeries(label: "", values: @values, kind: ckLine, color: style.lineColor)]
  plotChart(x, y, w, h, series, minValue, maxValue, label, style)

proc plotColumns*(
    x, y, w, h: float,
    values: openArray[float],
    minValue, maxValue: float,
    label: string = "",
    style: ChartStyle = borrowDefaultChartStyle(),
) =
  let series =
    [ChartSeries(label: "", values: @values, kind: ckColumns, color: style.columnColor)]
  plotChart(x, y, w, h, series, minValue, maxValue, label, style)

template plotChart*(
    series: openArray[ChartSeries],
    minValue, maxValue: float,
    label: string = "",
    style: ChartStyle = borrowDefaultChartStyle(),
) =
  autoLayoutPre()
  plotChart(
    g_uiState.autoLayoutState.x,
    autoLayoutNextY(),
    autoLayoutNextItemWidth(),
    autoLayoutNextItemHeight(),
    series,
    minValue,
    maxValue,
    label,
    style,
  )
  autoLayoutPost()

template plotLine*(
    values: openArray[float],
    minValue, maxValue: float,
    label: string = "",
    style: ChartStyle = borrowDefaultChartStyle(),
) =
  autoLayoutPre()
  plotLine(
    g_uiState.autoLayoutState.x,
    autoLayoutNextY(),
    autoLayoutNextItemWidth(),
    autoLayoutNextItemHeight(),
    values,
    minValue,
    maxValue,
    label,
    style,
  )
  autoLayoutPost()

template plotColumns*(
    values: openArray[float],
    minValue, maxValue: float,
    label: string = "",
    style: ChartStyle = borrowDefaultChartStyle(),
) =
  autoLayoutPre()
  plotColumns(
    g_uiState.autoLayoutState.x,
    autoLayoutNextY(),
    autoLayoutNextItemWidth(),
    autoLayoutNextItemHeight(),
    values,
    minValue,
    maxValue,
    label,
    style,
  )
  autoLayoutPost()
