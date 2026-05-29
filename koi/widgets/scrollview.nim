import std/math
import std/tables

import nanovg

import koi/types
import koi/core
import koi/drawing
import koi/layout
import koi/rect
import koi/input
import koi/defaults
import koi/widgets/scrollbar
import koi/utils

type ScrollViewState = ref object of RootObj
  x, y, w, h: float
  hitBounds: Rect
  viewStartX: float
  viewStartY: float
  contentWidth: float
  contentHeight: float
  autoContentWidth: bool
  autoContentHeight: bool
  viewportNode: LayoutNodeId
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

proc beginViewWithSlot*(slot: LayoutSlot)

proc beginView*(id: ItemId, x, y, w, h: float) =
  let (x, y) = addDrawOffset(x, y)
  let slot = beginLayoutContainerSlot(id, rect(x, y, w, h))
  beginViewWithSlot(slot)

proc beginViewWithSlot*(slot: LayoutSlot) =
  alias(ui, g_uiState)
  addLayoutDrawLayer(ui.currentLayer, slot.nodeId, vg, bounds):
    vg.save()
    vg.intersectScissor(bounds.x, bounds.y, bounds.w, bounds.h)

  hitClip(
    slot.previousBounds.x, slot.previousBounds.y, slot.previousBounds.w,
    slot.previousBounds.h,
  )
  pushDrawOffset(DrawOffset(ox: slot.bounds.x, oy: slot.bounds.y))

template beginView*(x, y, w, h: float) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)
  beginView(id, x, y, w, h)

proc endView*() =
  alias(ui, g_uiState)
  addDrawStateLayer(ui.currentLayer, vg):
    vg.restore()
  popDrawOffset()
  endLayoutContainerSlot()
  autoLayoutFinal()
  resetHitClip()

proc prepareScrollViewState(
    id: ItemId,
    x, y, w, h: float,
    style: ScrollViewStyle,
): tuple[scrollX, scrollY: float] =
  alias(ui, g_uiState)

  discard
    ui.itemState.hasKeyOrPut(
      id,
      ScrollViewState(
        x: x, y: y, w: w, h: h, hitBounds: rect(x, y, w, h), style: style
      ),
    )

  var ss = cast[ScrollViewState](ui.itemState[id])
  ss.x = x
  ss.y = y
  ss.w = w
  ss.h = h
  ss.style = style

  let previousContent =
    previousLayoutContentSize(id, size(ss.contentWidth, ss.contentHeight))
  if ss.autoContentWidth:
    ss.contentWidth = max(previousContent.w, w)
  if ss.autoContentHeight:
    ss.contentHeight = max(previousContent.h, h)

  ui.itemState[id] = ss
  result.scrollX = ss.clampedStartX()
  result.scrollY = ss.clampedStartY()

proc beginScrollViewWithSlot*(
    id: ItemId,
    slot: LayoutSlot,
    drawOffsetBounds: Rect,
    style: ScrollViewStyle = borrowDefaultScrollViewStyle(),
) =
  alias(ui, g_uiState)

  addLayoutDrawLayer(ui.currentLayer, slot.nodeId, vg, bounds):
    vg.save()
    vg.intersectScissor(bounds.x, bounds.y, bounds.w, bounds.h)

  ui.scrollViewState.activeItem = id
  hitClip(
    slot.previousBounds.x, slot.previousBounds.y, slot.previousBounds.w,
    slot.previousBounds.h,
  )

  var ss = cast[ScrollViewState](ui.itemState[id])
  ss.hitBounds = slot.previousBounds
  ss.viewportNode = slot.nodeId
  ss.style = style
  pushDrawOffset(DrawOffset(ox: drawOffsetBounds.x, oy: drawOffsetBounds.y))
  ui.itemState[id] = ss

proc beginScrollViewWithFollowerSlot*(
    id: ItemId,
    fallback: Rect,
    target: LayoutNodeId,
    followInset: Padding,
    style: ScrollViewStyle = borrowDefaultScrollViewStyle(),
) =
  let (scrollX, scrollY) =
    prepareScrollViewState(id, fallback.x, fallback.y, fallback.w, fallback.h, style)
  let drawBounds = rect(fallback.x - scrollX, fallback.y - scrollY, fallback.w,
    fallback.h)
  let slot = beginLayoutFollowerContainerSlotAt(
    id,
    fallback,
    drawBounds,
    target,
    lfkMatchTarget,
    followInset = followInset,
    scrollOffset = size(scrollX, scrollY),
  )
  beginScrollViewWithSlot(id, slot, drawBounds, style)

proc beginScrollView*(
    id: ItemId,
    x, y, w, h: float,
    style: ScrollViewStyle = borrowDefaultScrollViewStyle(),
) =
  let (x, y) = addDrawOffset(x, y)
  let (scrollX, scrollY) = prepareScrollViewState(id, x, y, w, h, style)
  let slot = beginLayoutContainerSlotAt(
    id,
    rect(x, y, w, h),
    rect(x - scrollX, y - scrollY, w, h),
    size(scrollX, scrollY),
  )
  beginScrollViewWithSlot(id, slot, rect(x - scrollX, y - scrollY, w, h), style)

template beginScrollView*(
    x, y, w, h: float, style: ScrollViewStyle = borrowDefaultScrollViewStyle()
) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line, "")
  beginScrollView(id, x, y, w, h, style)

proc endScrollView*(contentW, contentH: float) =
  alias(ui, g_uiState)
  alias(a, ui.autoLayoutState)

  addDrawStateLayer(ui.currentLayer, vg):
    vg.restore()

  popDrawOffset()

  let height = contentH
  let autoLayout = height < 0
  if autoLayout:
    autoLayoutFinal()

  let id = ui.scrollViewState.activeItem
  var ss = cast[ScrollViewState](ui.itemState[id])
  let viewportNode = ss.viewportNode

  var viewStartX = ss.clampedStartX()
  var viewStartY = ss.clampedStartY()
  let previousContent =
    previousLayoutContentSize(id, size(ss.contentWidth, ss.contentHeight))
  let
    visibleWidth = ss.w
    visibleHeight = ss.h
    contentWidth = max(if contentW < 0: previousContent.w else: contentW, ss.w)
    contentHeight = if autoLayout: max(previousContent.h, a.y) else: height

  endLayoutContainerSlot()
  let
    savedActiveSlotParent = a.activeSlotParent
    savedActiveSlotUsed = a.activeSlotUsed
  a.activeSlotParent = NullLayoutNodeId
  a.activeSlotUsed = false

  if contentHeight > visibleHeight:
    let
      thumbSize = visibleHeight * ((contentHeight - visibleHeight) / contentHeight)
      endVal = contentHeight - visibleHeight

    if isHit(ss.hitBounds.x, ss.hitBounds.y, ss.hitBounds.w, ss.hitBounds.h):
      if hasEvent() and ui.currEvent.kind == ekScroll:
        viewStartY -= ui.currEvent.oy * ss.style.scrollWheelSensitivity
        markEventHandled()

    viewStartY = viewStartY.clamp(0, endVal)

    let sbId = hashId(lastIdString() & ":scrollBar")
    let sbSlot = layoutFollowerSlot(
      sbId,
      rect(
        ss.x + ss.w - ss.style.vertScrollBarWidth,
        ss.y,
        ss.style.vertScrollBarWidth,
        visibleHeight,
      ),
      viewportNode,
      lfkVerticalScrollBar,
    )
    vertScrollBarWithSlot(
      sbSlot,
      sbId,
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
    let sbSlot = layoutFollowerSlot(
      sbId,
      rect(ss.x, ss.y + ss.h - ss.style.horizScrollBarHeight, visibleWidth,
        ss.style.horizScrollBarHeight),
      viewportNode,
      lfkHorizontalScrollBar,
    )
    horizScrollBarWithSlot(
      sbSlot,
      sbId,
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
  ss.autoContentWidth = contentW < 0
  ss.autoContentHeight = autoLayout
  ui.itemState[id] = ss
  a.activeSlotParent = savedActiveSlotParent
  a.activeSlotUsed = savedActiveSlotUsed

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
