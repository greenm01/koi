import std/math

import nanovg

import koi/types
import koi/core
import koi/input
import koi/drawing
import koi/defaults
import koi/utils

const
  TooltipShowDelay       = 0.4
  TooltipFadeOutDelay    = 0.1
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
        tt.t0 = getTime()
      setFramesLeft()

    if (isActive(id) and ui.mbLeftDown) or
       (isHot(id) and ui.eventHandled and ui.currEvent.kind == ekScroll):
      tt.state = tsOff

    elif tt.state == tsOff and not ui.mbLeftDown and
         tt.lastHotItem != id:
      tt.state = tsShowDelay
      tt.t0 = getTime()
      setFramesLeft()

    elif tt.state >= tsShow:
      tt.state = tsShow
      tt.t0 = getTime()
      tt.text = tooltip
      setFramesLeft()

proc drawTooltip*(x, y: float, text: string, alpha: float = 1.0) =
  addDrawLayer(layerTooltip, vg):
    var w = 300.0
    let fontSize = 14.0
    let lineHeight = 1.4
    let padX = 10.0
    let padY = 10.0

    vg.setFont(fontSize, "sans-bold")

    var rows = textBreakLines(text, w-padX*2)
    var h = fontSize * lineHeight * rows.len.float + padY*2

    if rows.len == 1:
      w = vg.textWidth(text) + padX*2

    var (tx, ty) = fitRectWithinWindow(w, h, x-8, y-8, 30, 30, haLeft)
    let (_, _, rw, rh) = snapToGrid(tx, ty, w, h)
    tx = round(tx); ty = round(ty)

    vg.globalAlpha(alpha)
    drawShadow(vg, tx, ty, rw, rh, getDefaultShadowStyle())

    vg.beginPath()
    vg.roundedRect(tx, ty, rw, rh, 5)
    vg.fillColor(gray(0.1, 0.88))
    vg.fill()

    vg.fillColor(white(0.9))
    var curY = ty + padY + fontSize * lineHeight * 0.55
    for row in rows:
      discard vg.text(tx + padX, curY, text, row.startBytePos, row.endBytePos)
      curY += fontSize * lineHeight

    vg.globalAlpha(1.0)

proc tooltipPost*() =
  alias(ui, g_uiState)
  alias(tt, ui.tooltipState)

  let ttx = ui.mx
  let tty = ui.my

  case tt.state:
  of tsOff: discard
  of tsShowDelay:
    if getTime() - tt.t0 > TooltipShowDelay:
      tt.state = tsShow
  of tsShow:
    drawToolTip(ttx, tty, tt.text)
  of tsFadeOutDelay:
    drawToolTip(ttx, tty, tt.text)
    if getTime() - tt.t0 > TooltipFadeOutDelay:
      tt.state = tsFadeOut
      tt.t0 = getTime()
  of tsFadeOut:
    let t = getTime() - tt.t0
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
    tt.t0 = getTime()

  if tt.state > tsOff:
    setFramesLeft()

  tt.lastHotItem = ui.hotItem
