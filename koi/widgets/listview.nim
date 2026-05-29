import std/tables

import koi/types
import koi/core
import koi/drawing
import koi/input
import koi/rect
import koi/internal/algorithms
import koi/widgets/scrollview
import koi/utils

proc listViewRange*(
    itemCount: Natural, rowHeight, viewHeight, scrollY: float
): ListViewRange =
  algorithms.listViewRange(itemCount, rowHeight, viewHeight, scrollY)

proc beginListView*(
    id: ItemId, x, y, w, h: float, itemCount: Natural, rowHeight: float
): ListViewRange =
  alias(ui, g_uiState)

  let scrollY =
    if ui.itemState.hasKey(id):
      scrollViewStartY(id)
    else:
      0.0

  result = listViewRange(itemCount, rowHeight, h, scrollY)
  beginScrollView(id, x, y, w, h)
  let baseOffset = drawOffset()
  pushDrawOffset(DrawOffset(ox: baseOffset.ox, oy: baseOffset.oy + result.startY))

proc beginListViewWithSlot*(
    id: ItemId, slot: LayoutSlot, itemCount: Natural, rowHeight: float
): ListViewRange =
  alias(ui, g_uiState)

  let scrollY =
    if ui.itemState.hasKey(id):
      scrollViewStartY(id)
    else:
      0.0

  result = listViewRange(itemCount, rowHeight, slot.bounds.h, scrollY)
  beginScrollViewWithSlot(
    id,
    slot,
    rect(slot.bounds.x, slot.bounds.y - scrollY, slot.bounds.w, slot.bounds.h),
  )
  let baseOffset = drawOffset()
  pushDrawOffset(DrawOffset(ox: baseOffset.ox, oy: baseOffset.oy + result.startY))

proc endListView*(range: ListViewRange) =
  popDrawOffset()
  endScrollView(range.contentHeight)

template listView*(
    x, y, w, h: float,
    itemCount: Natural,
    rowHeight: float,
    index: untyped,
    body: untyped,
) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)
  let range = beginListView(id, x, y, w, h, itemCount, rowHeight)
  try:
    if itemCount > 0 and rowHeight > 0:
      for index in range.first .. range.last:
        body
  finally:
    endListView(range)
