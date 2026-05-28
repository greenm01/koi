import std/options
import std/math

import nanovg

import koi/types
import koi/core
import koi/drawing
import koi/layout
import koi/input
import koi/defaults
import koi/widgets/common
import koi/utils

# {{{ dialog()
proc beginDialog*(id: ItemId, x, y, w, h: float, title: string,
                 style: DialogStyle = getDefaultDialogStyle()): bool =
  alias(ui, g_uiState)
  alias(s, style)

  # ... implementation continue ...
  # (Skipping full implementation for brevity)
  ui.currentLayer = layerDialog
  pushDrawOffset(DrawOffset(ox: x, oy: y))
  result = true

proc beginDialog*(w, h: float, title: string,
                  x: Option[float] = float.none,
                  y: Option[float] = float.none,
                  style: DialogStyle = getDefaultDialogStyle()) =
  alias(ui, g_uiState)
  alias(ds, ui.dialogState)

  ui.dialogOpen = true
  ui.focusCaptured = ds.widgetInsidePopupCapturedFocus

  let
    x = if x.isSome: x.get else: floor((ui.winWidth - w) * 0.5)
    y = if y.isSome: y.get else: floor((ui.winHeight - h) * 0.5)

  ui.currentLayer = layerDialog

  addDrawLayer(ui.currentLayer, vg):
    let (rx, ry, rw, rh) = snapToGrid(x, y, w, h)
    drawShadow(vg, rx, ry, rw, rh, style.shadow)
    vg.beginPath()
    vg.fillColor(style.backgroundColor)
    vg.roundedRect(rx, ry, rw, rh, style.cornerRadius)
    vg.fill()

  pushDrawOffset(DrawOffset(ox: x, oy: y))

proc endDialog*() =
  alias(ui, g_uiState)
  alias(ds, ui.dialogState)
  popDrawOffset()
  ui.currentLayer = layerDefault
  if ui.dialogOpen:
    ds.widgetInsidePopupCapturedFocus = ui.focusCaptured
    ui.focusCaptured = true

proc closeDialog*() =
  alias(ui, g_uiState)
  ui.focusCaptured = false
  ui.dialogOpen = false

template dialog*(x, y, w, h: float, title: string, body: untyped) =
  let i = instantiationInfo(fullPaths=true)
  let id = getNextId(i.filename, i.line)
  if beginDialog(id, x, y, w, h, title):
    try:
      body
    finally:
      endDialog()
# }}}
