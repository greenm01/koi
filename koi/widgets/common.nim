import std/math

import nanovg

import koi/types
import koi/core
import koi/input
import koi/drawing
import koi/layout
import koi/rect
import koi/defaults
import koi/utils

const
  TooltipShowDelay = 0.4
  TooltipFadeOutDelay = 0.1
  TooltipFadeOutDuration = 0.4
  TooltipFontSize = 14.0
  TooltipLineHeight = 1.4
  TooltipPadX = 10.0
  TooltipPadY = 10.0
  TooltipMaxWidth = 300.0

# Common widget utilities

proc handleTooltip*(id: ItemId, tooltip: string) =
  alias(ui, g_uiState)
  alias(tt, ui.tooltipState)

  if tooltip != "":
    tt.state = tt.lastState

    if tt.state == tsShowDelay:
      let cursorMoved = ui.mx != ui.lastmx or ui.my != ui.lastmy
      if cursorMoved:
        tt.t0 = currentTime()
      requestFrames()

    if (isActive(id) and ui.mbLeftDown) or
        (isHot(id) and ui.eventHandled and ui.currEvent.kind == ekScroll):
      tt.state = tsOff
    elif tt.state == tsOff and not ui.mbLeftDown and tt.lastHotItem != id:
      tt.state = tsShowDelay
      tt.t0 = currentTime()
      requestFrames()
    elif tt.state >= tsShow:
      tt.state = tsShow
      tt.t0 = currentTime()
      tt.text = tooltip
      requestFrames()

proc tooltipBounds*(x, y: float, text: string): Rect =
  let
    textMaxW = TooltipMaxWidth - TooltipPadX * 2
    measure = measureLayoutText(text, TooltipFontSize, "sans-bold", textMaxW)
    rows = textBreakLines(text, textMaxW)

  var textW = 0.0
  for row in rows:
    textW = max(textW, row.width)

  if textW <= 0:
    textW = min(measure.prefWidth, textMaxW)

  let
    lineCount = max(1, max(measure.lineCount, rows.len))
    tooltipW = min(max(textW, 1.0), textMaxW) + TooltipPadX * 2
    tooltipH = TooltipFontSize * TooltipLineHeight * lineCount.float + TooltipPadY * 2
    (tx, ty) = fitRectWithinWindow(tooltipW, tooltipH, x - 8, y - 8, 30, 30, haLeft)

  rect(round(tx), round(ty), tooltipW, tooltipH)

proc drawTooltip*(x, y: float, text: string, alpha: float = 1.0) =
  let
    bounds = tooltipBounds(x, y, text)
    slot = layoutDrawSlot(0, bounds)

  addLayoutDrawLayer(layerTooltip, slot.nodeId, vg, bounds):
    vg.useFont(TooltipFontSize, "sans-bold")

    let rows = textBreakLines(text, bounds.w - TooltipPadX * 2)

    let (_, _, rw, rh) = snapToGrid(bounds.x, bounds.y, bounds.w, bounds.h)

    vg.globalAlpha(alpha)
    drawShadow(vg, bounds.x, bounds.y, rw, rh, borrowDefaultShadowStyle())

    vg.beginPath()
    vg.roundedRect(bounds.x, bounds.y, rw, rh, 5)
    vg.fillColor(gray(0.1, 0.88))
    vg.fill()

    vg.fillColor(white(0.9))
    var curY = bounds.y + TooltipPadY + TooltipFontSize * TooltipLineHeight * 0.55
    for row in rows:
      discard
        vg.text(bounds.x + TooltipPadX, curY, text, row.startBytePos, row.endBytePos)
      curY += TooltipFontSize * TooltipLineHeight

    vg.globalAlpha(1.0)

proc tooltipPost*() =
  alias(ui, g_uiState)
  alias(tt, ui.tooltipState)

  let ttx = ui.mx
  let tty = ui.my

  case tt.state
  of tsOff:
    discard
  of tsShowDelay:
    if currentTime() - tt.t0 > TooltipShowDelay:
      tt.state = tsShow
  of tsShow:
    drawToolTip(ttx, tty, tt.text)
  of tsFadeOutDelay:
    drawToolTip(ttx, tty, tt.text)
    if currentTime() - tt.t0 > TooltipFadeOutDelay:
      tt.state = tsFadeOut
      tt.t0 = currentTime()
  of tsFadeOut:
    let t = currentTime() - tt.t0
    if t > TooltipFadeOutDuration:
      tt.state = tsOff
    else:
      let alpha = 1.0 - t / TooltipFadeOutDuration
      drawToolTip(ttx, tty, tt.text, alpha)

  tt.lastState = tt.state
  if tt.state == tsShowDelay:
    tt.state = tsOff
  elif tt.state == tsShow:
    tt.state = tsFadeOutDelay
    tt.t0 = currentTime()

  if tt.state > tsOff:
    requestFrames()

  tt.lastHotItem = ui.hotItem
