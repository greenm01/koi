import std/options

import nanovg

import koi/types
import koi/core
import koi/drawing
import koi/layout
import koi/defaults
import koi/utils

proc label*(
    x, y, w, h: float,
    labelText: string,
    state: WidgetState = wsNormal,
    style: LabelStyle = defaultLabelStyle(),
) =
  alias(ui, g_uiState)

  let (x, y) = addDrawOffset(x, y)

  addDrawLayer(ui.currentLayer, vg):
    vg.drawLabel(x, y, w, h, labelText, state, style)

proc label*(
    labelText: string,
    state: WidgetState = wsNormal,
    style: LabelStyle = defaultLabelStyle(),
) =
  alias(ui, g_uiState)

  autoLayoutPre()

  label(
    ui.autoLayoutState.x,
    autoLayoutNextY(),
    autoLayoutNextItemWidth(),
    autoLayoutNextItemHeight(),
    labelText,
    state,
    style,
  )

  autoLayoutPost()
