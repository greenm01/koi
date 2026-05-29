import nanovg

import koi/types
import koi/core
import koi/drawing
import koi/layout
import koi/rect
import koi/defaults
import koi/utils

proc labelWithSlot*(
    slot: LayoutSlot,
    id: ItemId,
    labelText: string,
    state: WidgetState = wsNormal,
    style: LabelStyle = borrowDefaultLabelStyle(),
) =
  alias(ui, g_uiState)

  addLayoutDrawLayer(ui.currentLayer, slot.nodeId, vg, bounds):
    vg.drawLabel(bounds.x, bounds.y, bounds.w, bounds.h, labelText, state, style)

proc label*(
    id: ItemId,
    x, y, w, h: float,
    labelText: string,
    state: WidgetState = wsNormal,
    style: LabelStyle = borrowDefaultLabelStyle(),
) =
  let (x, y) = addDrawOffset(x, y)
  let slot = textLayoutSlot(id, rect(x, y, w, h), labelText, style)
  labelWithSlot(slot, id, labelText, state, style)

proc label*(
    x, y, w, h: float,
    labelText: string,
    state: WidgetState = wsNormal,
    style: LabelStyle = borrowDefaultLabelStyle(),
) =
  label(0, x, y, w, h, labelText, state, style)

proc label*(
    labelText: string,
    state: WidgetState = wsNormal,
    style: LabelStyle = borrowDefaultLabelStyle(),
) =
  alias(ui, g_uiState)

  autoLayoutPre()

  label(
    0,
    ui.autoLayoutState.x,
    autoLayoutNextY(),
    autoLayoutNextItemWidth(),
    autoLayoutNextItemHeight(),
    labelText,
    state,
    style,
  )

  autoLayoutPost()
