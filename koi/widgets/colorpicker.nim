import nanovg

import koi/types
import koi/core
import koi/drawing
import koi/layout
import koi/input
import koi/defaults
import koi/widgets/common
import koi/utils

proc color*(id: ItemId, x, y, w, h: float, color_out: var Color) =
  alias(ui, g_uiState)
  let (x, y) = addDrawOffset(x, y)

  if isHit(x, y, w, h):
    setHot(id)
    if ui.mbLeftDown and hasNoActiveItem():
      setActive(id)

  let color = color_out
  addDrawLayer(ui.currentLayer, vg):
    let
      sw = 1.0
      (rx, ry, rw, rh) = snapToGrid(x, y, w, h, sw)
      cr = 5.0
      colorWidth = rw * 0.5

    vg.fillColor(color.withAlpha(1.0))
    vg.beginPath()
    vg.roundedRect(rx, ry, colorWidth, rh, cr, 0, 0, cr)
    vg.fill()

    vg.fillColor(color)
    vg.beginPath()
    vg.roundedRect(rx + colorWidth, ry, rw - colorWidth, rh, 0, cr, cr, 0)
    vg.fill()

    vg.strokeColor(gray(0.1))
    vg.strokeWidth(sw)
    vg.beginPath()
    vg.roundedRect(rx, ry, rw, rh, cr)
    vg.stroke()

proc colorPicker*(id: ItemId, x, y, w, h: float, color: var Color) =
  color(id, x, y, w, h, color)

template color*(x, y, w, h: float, color: var Color) =
  let i = instantiationInfo(fullPaths=true)
  let id = getNextId(i.filename, i.line)
  color(id, x, y, w, h, color)

template color*(col: var Color) =
  let i = instantiationInfo(fullPaths=true)
  let id = getNextId(i.filename, i.line)
  autoLayoutPre()
  color(id,
        g_uiState.autoLayoutState.x, autoLayoutNextY(),
        autoLayoutNextItemWidth(), autoLayoutNextItemHeight(),
        col)
  autoLayoutPost()

template colorPicker*(x, y, w, h: float, color: var Color) =
  let i = instantiationInfo(fullPaths=true)
  let id = getNextId(i.filename, i.line)
  colorPicker(id, x, y, w, h, color)

template colorPicker*(color: var Color) =
  let i = instantiationInfo(fullPaths=true)
  let id = getNextId(i.filename, i.line)
  autoLayoutPre()
  colorPicker(id,
              g_uiState.autoLayoutState.x, autoLayoutNextY(),
              autoLayoutNextItemWidth(), autoLayoutNextItemHeight(),
              color)
  autoLayoutPost()
