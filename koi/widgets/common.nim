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

proc drawTooltip*(x, y: float, text: string, alpha: float = 1.0) =
  let fontSize = 14.0
  let lineHeight = 1.4
  let padX = 10.0
  let padY = 10.0
  let measure = measureLayoutText(text, fontSize, "sans-bold", 300.0 - padX * 2)
  let
    tooltipW =
      if measure.lineCount <= 1:
        measure.prefWidth + padX * 2
      else:
        300.0
    tooltipH = fontSize * lineHeight * measure.lineCount.float + padY * 2
    (tx, ty) =
      fitRectWithinWindow(tooltipW, tooltipH, x - 8, y - 8, 30, 30, haLeft)
    slot = layoutDrawSlot(0, rect(round(tx), round(ty), tooltipW, tooltipH))

  addLayoutDrawLayer(layerTooltip, slot.nodeId, vg, bounds):
    vg.useFont(fontSize, "sans-bold")

    let rows = textBreakLines(text, bounds.w - padX * 2)

    let (_, _, rw, rh) = snapToGrid(bounds.x, bounds.y, bounds.w, bounds.h)

    vg.globalAlpha(alpha)
    drawShadow(vg, bounds.x, bounds.y, rw, rh, borrowDefaultShadowStyle())

    vg.beginPath()
    vg.roundedRect(bounds.x, bounds.y, rw, rh, 5)
    vg.fillColor(gray(0.1, 0.88))
    vg.fill()

    vg.fillColor(white(0.9))
    var curY = bounds.y + padY + fontSize * lineHeight * 0.55
    for row in rows:
      discard vg.text(
        bounds.x + padX, curY, text, row.startBytePos, row.endBytePos
      )
      curY += fontSize * lineHeight

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
