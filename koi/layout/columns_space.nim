proc beginColumn*(mode: ColMode, value: float = 0.0) =
  alias(ui, g_uiState)
  if ui.layoutStack.len > 0 and ui.layoutStack[^1].mode == lpmRow:
    alias(node, ui.layoutStack[^1])
    node.currentColumn = LayoutColumn(mode: mode, value: value)
    node.hasCurrentColumn = true

proc endColumn*() =
  alias(ui, g_uiState)
  if ui.layoutStack.len > 0 and ui.layoutStack[^1].mode == lpmRow:
    ui.layoutStack[^1].hasCurrentColumn = false

template layoutRow*(height: float, body: untyped) =
  beginRowLayout(height)
  try:
    body
  finally:
    endLayout()

template layoutRow*(height: float, columns: openArray[LayoutColumn], body: untyped) =
  beginRowLayout(height, columns)
  try:
    body
  finally:
    endLayout()

template layoutSpace*(height: float, body: untyped) =
  beginSpaceLayout(height)
  try:
    body
  finally:
    endLayout()

template col*(width: float, body: untyped) =
  beginColumn(cmStatic, width)
  try:
    body
  finally:
    endColumn()

template colDynamic*(body: untyped) =
  beginColumn(cmDynamic)
  try:
    body
  finally:
    endColumn()

template colRatio*(ratio: float, body: untyped) =
  beginColumn(cmRatio, ratio)
  try:
    body
  finally:
    endColumn()

template colVariable*(minWidth: float, body: untyped) =
  beginColumn(cmVariable, minWidth)
  try:
    body
  finally:
    endColumn()

proc layoutSpaceBounds*(): Rect =
  alias(ui, g_uiState)
  if ui.layoutStack.len > 0 and ui.layoutStack[^1].mode == lpmSpace:
    let node = ui.layoutStack[^1]
    result = rect(0, 0, node.w, node.h)
  else:
    result = autoLayoutNextBounds()

proc layoutSpaceRatioRect*(x, y, w, h: float): Rect =
  let b = layoutSpaceBounds()
  let
    rx = x.clamp(0.0, 1.0)
    ry = y.clamp(0.0, 1.0)
    rw = w.clamp(0.0, 1.0 - rx)
    rh = h.clamp(0.0, 1.0 - ry)
  rect(b.x + b.w * rx, b.y + b.h * ry, b.w * rw, b.h * rh)

proc layoutSpaceToScreen*(x, y: float): (float, float) =
  addDrawOffset(x, y)

proc layoutSpaceToLocal*(x, y: float): (float, float) =
  let offset = drawOffset()
  (x - offset.ox, y - offset.oy)

proc layoutSpaceRectToScreen*(r: Rect): Rect =
  let (x, y) = layoutSpaceToScreen(r.x, r.y)
  rect(x, y, r.w, r.h)

proc layoutSpaceRectToLocal*(r: Rect): Rect =
  let (x, y) = layoutSpaceToLocal(r.x, r.y)
  rect(x, y, r.w, r.h)

proc beginGroup*() =
  g_uiState.autoLayoutState.groupBegin = true

proc endGroup*() =
  discard

template group*(body: untyped) =
  beginGroup()
  body
  endGroup()

proc nextLayoutColumn*() =
  autoLayoutPre()
  autoLayoutPost()
