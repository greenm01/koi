import std/math
import std/tables

import nanovg

import koi/types
import koi/core
import koi/drawing
import koi/layout
import koi/input
import koi/defaults
import koi/widgets/scrollbar
import koi/utils

type ScrollViewState = ref object of RootObj
  x, y, w, h: float
  viewStartX: float
  viewStartY: float
  contentWidth: float
  contentHeight: float
  style: ScrollViewStyle

proc clampedStartX(ss: ScrollViewState): float =
  ss.viewStartX.clamp(0, max(ss.contentWidth - ss.w, 0))

proc clampedStartY(ss: ScrollViewState): float =
  ss.viewStartY.clamp(0, max(ss.contentHeight - ss.h, 0))

proc scrollViewStartX*(id: ItemId, startX: float) =
  alias(ui, g_uiState)
  var ss = cast[ScrollViewState](ui.itemState[id])
  ss.viewStartX = startX
  ui.itemState[id] = ss

proc setScrollViewStartX*(id: ItemId, startX: float) =
  scrollViewStartX(id, startX)

proc scrollViewStartX*(id: ItemId): float =
  alias(ui, g_uiState)
  var ss = cast[ScrollViewState](ui.itemState[id])
  result = ss.clampedStartX()

proc getScrollViewStartX*(id: ItemId): float =
  scrollViewStartX(id)

proc scrollViewStartY*(id: ItemId, startY: float) =
  alias(ui, g_uiState)
  var ss = cast[ScrollViewState](ui.itemState[id])
  ss.viewStartY = startY
  ui.itemState[id] = ss

proc setScrollViewStartY*(id: ItemId, startY: float) =
  scrollViewStartY(id, startY)

proc scrollViewStartY*(id: ItemId): float =
  alias(ui, g_uiState)
  var ss = cast[ScrollViewState](ui.itemState[id])
  result = ss.clampedStartY()

proc getScrollViewStartY*(id: ItemId): float =
  scrollViewStartY(id)

proc beginView*(id: ItemId, x, y, w, h: float) =
  alias(ui, g_uiState)
  let (x, y) = addDrawOffset(x, y)

  addDrawLayer(ui.currentLayer, vg):
    vg.save()
    vg.intersectScissor(x, y, w, h)

  hitClip(x, y, w, h)
  pushDrawOffset(DrawOffset(ox: x, oy: y))

template beginView*(x, y, w, h: float) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)
  beginView(id, x, y, w, h)

proc endView*() =
  alias(ui, g_uiState)
  addDrawLayer(ui.currentLayer, vg):
    vg.restore()
  popDrawOffset()
  autoLayoutFinal()
  resetHitClip()

proc beginScrollView*(
    id: ItemId,
    x, y, w, h: float,
    style: ScrollViewStyle = borrowDefaultScrollViewStyle(),
) =
  alias(ui, g_uiState)
  let (x, y) = addDrawOffset(x, y)

  addDrawLayer(ui.currentLayer, vg):
    vg.save()
    vg.intersectScissor(x, y, w, h)

  ui.scrollViewState.activeItem = id
  hitClip(x, y, w, h)

  discard
    ui.itemState.hasKeyOrPut(id, ScrollViewState(x: x, y: y, w: w, h: h, style: style))

  var ss = cast[ScrollViewState](ui.itemState[id])
  pushDrawOffset(DrawOffset(ox: x - ss.clampedStartX(), oy: y - ss.clampedStartY()))

  ss.x = x
  ss.y = y
  ss.w = w
  ss.h = h
  ss.style = style
  ui.itemState[id] = ss

template beginScrollView*(
    x, y, w, h: float, style: ScrollViewStyle = borrowDefaultScrollViewStyle()
) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line, "")
  beginScrollView(id, x, y, w, h, style)

proc endScrollView*(contentW, contentH: float) =
  alias(ui, g_uiState)
  alias(a, ui.autoLayoutState)

  addDrawLayer(ui.currentLayer, vg):
    vg.restore()

  popDrawOffset()

  let height = contentH
  let autoLayout = height < 0
  if autoLayout:
    autoLayoutFinal()

  let id = ui.scrollViewState.activeItem
  var ss = cast[ScrollViewState](ui.itemState[id])

  var viewStartX = ss.clampedStartX()
  var viewStartY = ss.clampedStartY()
  let
    visibleWidth = ss.w
    visibleHeight = ss.h
    contentWidth = max(if contentW < 0: ss.w else: contentW, ss.w)
    contentHeight = if autoLayout: a.y else: height

  if contentHeight > visibleHeight:
    let
      thumbSize = visibleHeight * ((contentHeight - visibleHeight) / contentHeight)
      endVal = contentHeight - visibleHeight

    if isHit(ss.x, ss.y, ss.w, ss.h):
      if hasEvent() and ui.currEvent.kind == ekScroll:
        viewStartY -= ui.currEvent.oy * ss.style.scrollWheelSensitivity
        markEventHandled()

    viewStartY = viewStartY.clamp(0, endVal)

    let sbId = hashId(lastIdString() & ":scrollBar")
    vertScrollBar(
      sbId,
      x = ss.x + ss.w - ss.style.vertScrollBarWidth,
      y = ss.y,
      w = ss.style.vertScrollBarWidth,
      h = visibleHeight,
      startVal = 0,
      endVal = endVal,
      value_out = viewStartY,
      thumbSize = thumbSize,
      clickStep = 20,
      style = ss.style.scrollBarStyle,
    )
  else:
    viewStartY = 0

  if contentWidth > visibleWidth:
    let
      thumbSize = visibleWidth * ((contentWidth - visibleWidth) / contentWidth)
      endVal = contentWidth - visibleWidth

    viewStartX = viewStartX.clamp(0, endVal)

    let sbId = hashId(lastIdString() & ":horizScrollBar")
    horizScrollBar(
      sbId,
      x = ss.x,
      y = ss.y + ss.h - ss.style.horizScrollBarHeight,
      w = visibleWidth,
      h = ss.style.horizScrollBarHeight,
      startVal = 0,
      endVal = endVal,
      value_out = viewStartX,
      thumbSize = thumbSize,
      clickStep = 20,
      style = ss.style.scrollBarStyle,
    )
  else:
    viewStartX = 0

  ss.viewStartX = viewStartX
  ss.viewStartY = viewStartY
  ss.contentWidth = contentWidth
  ss.contentHeight = contentHeight
  ui.itemState[id] = ss

  ui.scrollViewState.activeItem = 0
  ui.sectionHeaderState.openSubHeaders = false
  resetHitClip()

proc endScrollView*(height: float = -1.0) =
  endScrollView(-1.0, height)

template scrollView*(x, y, w, h: float, contentH: float, body: untyped) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)
  beginScrollView(id, x, y, w, h)
  try:
    body
  finally:
    endScrollView(contentH)

template scrollView*(x, y, w, h: float, contentW, contentH: float, body: untyped) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)
  beginScrollView(id, x, y, w, h)
  try:
    body
  finally:
    endScrollView(contentW, contentH)
