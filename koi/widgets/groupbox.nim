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

proc drawGroupBoxFrame(slot: LayoutSlot, title: string, style: GroupBoxStyle) =
  alias(ui, g_uiState)

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

func groupBoxContentInset(style: GroupBoxStyle): Padding =
  padding(style.pad, style.pad, style.titleHeight + style.pad, style.pad)

proc beginGroupBox*(
    id: ItemId,
    x, y, w, h: float,
    title: string,
    style: GroupBoxStyle = borrowDefaultGroupBoxStyle(),
): Rect =
  result = groupBoxContentRect(x, y, w, h, style)
  let
    (sx, sy) = addDrawOffset(x, y)
    frameSlot = layoutSlot(hashId($id & ":frame"), rect(sx, sy, w, h))
    contentFallback = groupBoxContentRect(sx, sy, w, h, style)
    contentSlot = beginLayoutFollowerContainerSlotAt(
      id,
      contentFallback,
      contentFallback,
      frameSlot.nodeId,
      lfkMatchTarget,
      followInset = groupBoxContentInset(style),
    )
  drawGroupBoxFrame(frameSlot, title, style)
  beginViewWithSlot(contentSlot)

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
    disabled: bool = false,
): Rect =
  result = groupBoxContentRect(x, y, w, h, groupStyle)
  let
    (sx, sy) = addDrawOffset(x, y)
    frameSlot = layoutSlot(hashId($id & ":frame"), rect(sx, sy, w, h))
    contentFallback = groupBoxContentRect(sx, sy, w, h, groupStyle)
  drawGroupBoxFrame(frameSlot, title, groupStyle)
  beginScrollViewWithFollowerSlot(
    id,
    contentFallback,
    frameSlot.nodeId,
    groupBoxContentInset(groupStyle),
    scrollStyle,
    disabled,
  )

proc endTitledScrollView*(contentW, contentH: float) =
  endScrollView(contentW, contentH)

proc endTitledScrollView*(contentH: float = -1.0) =
  endScrollView(contentH)

template titledScrollView*(
    x, y, w, h: float,
    title: string,
    contentW, contentH: float,
    disabled: bool = false,
    body: untyped,
) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line, title)
  discard beginTitledScrollView(
    id,
    x,
    y,
    w,
    h,
    title,
    borrowDefaultGroupBoxStyle(),
    borrowDefaultScrollViewStyle(),
    disabled,
  )
  try:
    body
  finally:
    endTitledScrollView(contentW, contentH)

template titledScrollView*(
    x, y, w, h: float,
    title: string,
    contentH: float,
    disabled: bool = false,
    body: untyped,
) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line, title)
  discard beginTitledScrollView(
    id,
    x,
    y,
    w,
    h,
    title,
    borrowDefaultGroupBoxStyle(),
    borrowDefaultScrollViewStyle(),
    disabled,
  )
  try:
    body
  finally:
    endTitledScrollView(contentH)
