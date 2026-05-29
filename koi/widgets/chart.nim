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

proc plotLine*(
    x, y, w, h: float,
    values: openArray[float],
    minValue, maxValue: float,
    label: string = "",
    style: ChartStyle = borrowDefaultChartStyle(),
) =
  alias(ui, g_uiState)
  let (x, y) = addDrawOffset(x, y)
  let chartValues = @values

  addDrawLayer(ui.currentLayer, vg):
    vg.drawChartFrame(x, y, w, h, label, style)
    if chartValues.len > 0:
      vg.strokeColor(style.lineColor)
      vg.strokeWidth(style.lineWidth)
      vg.beginPath()
      for i, value in chartValues:
        let
          px = chartPointX(i.Natural, chartValues.len.Natural, x, w)
          py = chartValueY(value, minValue, maxValue, y, h)
        if i == 0:
          vg.moveTo(px, py)
        else:
          vg.lineTo(px, py)
      vg.stroke()

proc plotColumns*(
    x, y, w, h: float,
    values: openArray[float],
    minValue, maxValue: float,
    label: string = "",
    style: ChartStyle = borrowDefaultChartStyle(),
) =
  alias(ui, g_uiState)
  let (x, y) = addDrawOffset(x, y)
  let chartValues = @values

  addDrawLayer(ui.currentLayer, vg):
    vg.drawChartFrame(x, y, w, h, label, style)
    if chartValues.len > 0:
      let zeroY = chartValueY(0, minValue, maxValue, y, h)
      vg.strokeColor(style.zeroLineColor)
      vg.strokeWidth(1)
      vg.beginPath()
      vg.horizLine(x, zeroY, w)
      vg.stroke()

      vg.fillColor(style.columnColor)
      for i, value in chartValues:
        let r = chartColumnRect(
          i.Natural, chartValues.len.Natural, value, minValue, maxValue, x, y, w, h,
          style.columnGap,
        )
        vg.beginPath()
        vg.rect(r.x, r.y, r.w, r.h)
        vg.fill()

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
