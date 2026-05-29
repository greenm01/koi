import nanovg

import koi/types
import koi/core
import koi/drawing
import koi/layout
import koi/rect
import koi/defaults
import koi/input
import koi/widgets/scrollview
import koi/utils

proc groupBoxContentRect(x, y, w, h: float, style: GroupBoxStyle): Rect =
  rect(
    x + style.pad,
    y + style.titleHeight + style.pad,
    max(0.0, w - style.pad * 2),
    max(0.0, h - style.titleHeight - style.pad * 2),
  )

proc drawGroupBoxFrame(
    id: ItemId, x, y, w, h: float, title: string, style: GroupBoxStyle
) =
  alias(ui, g_uiState)
  let (sx, sy) = addDrawOffset(x, y)
  let slot = layoutDrawSlot(id, rect(sx, sy, w, h))

  addLayoutDrawLayer(ui.currentLayer, slot.nodeId, vg, bounds):
    let (rx, ry, rw, rh) =
      snapToGrid(bounds.x, bounds.y, bounds.w, bounds.h, style.strokeWidth)
    vg.fillColor(style.fillColor)
    vg.strokeColor(style.strokeColor)
    vg.strokeWidth(style.strokeWidth)
    vg.beginPath()
    vg.roundedRect(rx, ry, rw, rh, style.cornerRadius)
    vg.fill()
    vg.stroke()

    if title.len > 0:
      vg.fillColor(style.titleFillColor)
      vg.beginPath()
      vg.roundedRect(
        rx, ry, rw, style.titleHeight, style.cornerRadius, style.cornerRadius, 0, 0
      )
      vg.fill()
      vg.drawLabel(rx, ry, rw, style.titleHeight, title, wsNormal, style.titleLabel)

proc beginGroupBox*(
    id: ItemId,
    x, y, w, h: float,
    title: string,
    style: GroupBoxStyle = borrowDefaultGroupBoxStyle(),
): Rect =
  drawGroupBoxFrame(hashId($id & ":frame"), x, y, w, h, title, style)
  result = groupBoxContentRect(x, y, w, h, style)
  beginView(id, result.x, result.y, result.w, result.h)

proc endGroupBox*() =
  endView()

template groupBox*(x, y, w, h: float, title: string, body: untyped) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line, title)
  discard beginGroupBox(id, x, y, w, h, title)
  try:
    body
  finally:
    endGroupBox()

template groupBox*(
    x, y, w, h: float, title: string, style: GroupBoxStyle, body: untyped
) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line, title)
  discard beginGroupBox(id, x, y, w, h, title, style)
  try:
    body
  finally:
    endGroupBox()

proc beginTitledScrollView*(
    id: ItemId,
    x, y, w, h: float,
    title: string,
    groupStyle: GroupBoxStyle = borrowDefaultGroupBoxStyle(),
    scrollStyle: ScrollViewStyle = borrowDefaultScrollViewStyle(),
): Rect =
  drawGroupBoxFrame(hashId($id & ":frame"), x, y, w, h, title, groupStyle)
  result = groupBoxContentRect(x, y, w, h, groupStyle)
  beginScrollView(id, result.x, result.y, result.w, result.h, scrollStyle)

proc endTitledScrollView*(contentW, contentH: float) =
  endScrollView(contentW, contentH)

proc endTitledScrollView*(contentH: float = -1.0) =
  endScrollView(contentH)

template titledScrollView*(
    x, y, w, h: float, title: string, contentW, contentH: float, body: untyped
) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line, title)
  discard beginTitledScrollView(id, x, y, w, h, title)
  try:
    body
  finally:
    endTitledScrollView(contentW, contentH)

template titledScrollView*(
    x, y, w, h: float, title: string, contentH: float, body: untyped
) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line, title)
  discard beginTitledScrollView(id, x, y, w, h, title)
  try:
    body
  finally:
    endTitledScrollView(contentH)
