import nanovg

import koi/types
import koi/core
import koi/drawing
import koi/input
import koi/layout
import koi/rect
import koi/utils

proc image*(id: ItemId, x, y, w, h: float, paint: Paint) =
  alias(ui, g_uiState)
  let (x, y) = addDrawOffset(x, y)
  let slot = layoutSlot(id, rect(x, y, w, h))

  addLayoutDrawLayer(ui.currentLayer, slot.nodeId, vg, bounds):
    vg.drawImage(bounds.x, bounds.y, bounds.w, bounds.h, paint)

proc image*(x, y, w, h: float, paint: Paint) =
  alias(ui, g_uiState)
  let (x, y) = addDrawOffset(x, y)
  let slot = layoutDrawSlot(0, rect(x, y, w, h))

  addLayoutDrawLayer(ui.currentLayer, slot.nodeId, vg, bounds):
    vg.drawImage(bounds.x, bounds.y, bounds.w, bounds.h, paint)

template image*(paint: Paint) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)

  autoLayoutPre()
  image(
    id,
    g_uiState.autoLayoutState.x,
    autoLayoutNextY(),
    autoLayoutNextItemWidth(),
    autoLayoutNextItemHeight(),
    paint,
  )
  autoLayoutPost()
