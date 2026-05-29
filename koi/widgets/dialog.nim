import std/options
import std/math

import nanovg

import koi/types
import koi/core
import koi/drawing
import koi/layout
import koi/rect
import koi/defaults
import koi/utils

proc beginDialogFrame(
    id: ItemId, x, y, w, h: float, style: DialogStyle
) =
  alias(ui, g_uiState)
  alias(ds, ui.dialogState)

  ui.dialogOpen = true
  ui.focusCaptured = ds.widgetInsidePopupCapturedFocus
  ui.currentLayer = layerDialog

  let slot = layoutDrawSlot(id, rect(x, y, w, h))
  addLayoutDrawLayer(ui.currentLayer, slot.nodeId, vg, bounds):
    let (rx, ry, rw, rh) =
      snapToGrid(bounds.x, bounds.y, bounds.w, bounds.h)
    drawShadow(vg, rx, ry, rw, rh, style.shadow)
    vg.beginPath()
    vg.fillColor(style.backgroundColor)
    vg.roundedRect(rx, ry, rw, rh, style.cornerRadius)
    vg.fill()

  beginLayoutViewportForSlot(slot)

  pushDrawOffset(DrawOffset(ox: x, oy: y))

# dialog()
proc beginDialog*(
    id: ItemId,
    x, y, w, h: float,
    title: string,
    style: DialogStyle = borrowDefaultDialogStyle(),
): bool =
  beginDialogFrame(id, x, y, w, h, style)
  result = true

proc beginDialog*(
    w, h: float,
    title: string,
    x: Option[float] = float.none,
    y: Option[float] = float.none,
    style: DialogStyle = borrowDefaultDialogStyle(),
) =
  alias(ui, g_uiState)
  let
    dialogX =
      if x.isSome:
        x.get
      else:
        floor((ui.winWidth - w) * 0.5)
    dialogY =
      if y.isSome:
        y.get
      else:
        floor((ui.winHeight - h) * 0.5)

  beginDialogFrame(0, dialogX, dialogY, w, h, style)

proc endDialog*() =
  alias(ui, g_uiState)
  alias(ds, ui.dialogState)
  popDrawOffset()
  endLayoutViewportForSlot()
  ui.currentLayer = layerDefault
  if ui.dialogOpen:
    ds.widgetInsidePopupCapturedFocus = ui.focusCaptured
    ui.focusCaptured = true

proc closeDialog*() =
  alias(ui, g_uiState)
  ui.focusCaptured = false
  ui.dialogOpen = false

template dialog*(x, y, w, h: float, title: string, body: untyped) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)
  if beginDialog(id, x, y, w, h, title):
    try:
      body
    finally:
      endDialog()
