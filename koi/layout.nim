import std/options
import std/math

import koi/utils
import koi/types
import koi/core
import koi/defaults
import koi/drawing

# Layout engine: standard auto-layout and hierarchical blocks

# {{{ initAutoLayout*()
proc initAutoLayout*(params: AutoLayoutParams) =
  alias(ui, g_uiState)
  alias(a, ui.autoLayoutState)
  ui.autoLayoutParams = params

  a = AutoLayoutStateVars.default

  a.rowWidth       = params.rowWidth
  a.nextItemHeight = params.defaultItemHeight
  a.firstRow       = true

# }}}
# {{{ nextRowHeight*()
proc nextRowHeight*(h: float) =
  g_uiState.autoLayoutState.nextRowHeight = h.some

# }}}
# {{{ nextItemWidth*()
proc nextItemWidth*(w: float) =
  g_uiState.autoLayoutState.nextItemWidth = w

# }}}
# {{{ nextItemHeight*()
proc nextItemHeight*(h: float) =
  g_uiState.autoLayoutState.nextItemHeight = h

# }}}

proc autoLayoutNextY*(): float =
  alias(a, g_uiState.autoLayoutState)
  result = a.y
  let dy = a.rowHeight - a.nextItemHeight.clamp(0, a.rowHeight)
  if dy > 0:
    result += round(dy*0.5)

proc autoLayoutNextX*(): float =
  g_uiState.autoLayoutState.x

proc autoLayoutNextItemWidth*(): float =
  alias(a, g_uiState.autoLayoutState)
  a.nextItemWidth

proc autoLayoutNextItemHeight*(): float =
  alias(a, g_uiState.autoLayoutState)
  a.nextItemHeight.clamp(0, a.rowHeight)

proc autoLayoutPre*(section: bool = false) =
  alias(ui, g_uiState)
  alias(a,  ui.autoLayoutState)
  alias(ap, ui.autoLayoutParams)

  if ui.layoutStack.len > 0:
    let node = ui.layoutStack[^1]
    if node.mode == lmRow:
      a.rowHeight = node.rowHeight
      a.x = node.currentX
      a.y = node.y
      
      case node.colMode:
      of cmStatic:
        a.nextItemWidth = node.colWidth
      of cmRatio:
        # Use available width minus horizontal padding
        let totalW = node.availableWidth - ap.leftPad - ap.rightPad
        a.nextItemWidth = totalW * node.colWidth
      of cmDynamic:
        # Take remaining width
        a.nextItemWidth = node.availableWidth - (a.x - node.x) - ap.rightPad
      of cmVariable:
        a.nextItemWidth = node.colWidth

      a.nextItemHeight = ap.defaultItemHeight
      return

    elif node.mode == lmSpace:
      # Space mode has its own DrawOffset, so auto-layout coordinates
      # should be relative to its top-left (0,0).
      a.x = 0
      a.y = 0
      a.nextItemWidth = node.w
      a.nextItemHeight = node.h
      return

  let firstColumn = (a.currColIndex == 0)

  if firstColumn:
    a.rowHeight = if a.nextRowHeight.isSome: a.nextRowHeight.get
                  else: ap.defaultRowHeight
    a.nextRowHeight = float.none

    a.x = ap.leftPad
    if not a.firstRow:
      a.y += ap.rowPad

    if a.groupBegin:
      a.y += ap.rowGroupPad

  else:
    a.x += a.nextItemWidth + ap.rightPad + ap.leftPad

  a.nextItemWidth  = (a.rowWidth - ap.leftPad - ap.rightPad -
                     (ap.leftPad + ap.rightPad) * (ap.itemsPerRow-1).float) /
                     ap.itemsPerRow.float

  a.nextItemHeight = ap.defaultItemHeight

proc autoLayoutPost*(section: bool = false) =
  alias(ui, g_uiState)
  alias(a,  ui.autoLayoutState)
  alias(ap, ui.autoLayoutParams)

  if ui.layoutStack.len > 0:
    alias(node, ui.layoutStack[^1])
    if node.mode == lmRow:
      node.currentX += a.nextItemWidth
      return
    elif node.mode == lmSpace:
      return

  let lastColumn = (a.currColIndex == ap.itemsPerRow-1)

  if lastColumn or section:
    # Progress to next row
    a.currColIndex = 0

    a.y += a.rowHeight
    a.y += ap.sectionPad
    a.prevSection = section
    a.firstRow    = false

  else:
    # Progress to next column
    inc(a.currColIndex)

  a.groupBegin = false

proc autoLayoutFinal*() =
  alias(ui, g_uiState)
  alias(a, ui.autoLayoutState)

  if a.prevSection:
    a.y -= ui.autoLayoutParams.sectionPad

# {{{ Layout Stack procs & templates

proc beginRowLayout*(height: float) =
  alias(ui, g_uiState)
  alias(a, ui.autoLayoutState)
  alias(ap, ui.autoLayoutParams)
  
  if a.currColIndex > 0:
    autoLayoutPost(section=true)

  let startX = if a.currColIndex == 0 and a.x == 0: ap.leftPad else: a.x
  let availableW = if ui.layoutStack.len > 0: a.nextItemWidth else: a.rowWidth

  var node = LayoutNode(
    mode: lmRow,
    x: startX,
    y: a.y,
    w: availableW,
    h: height,
    rowHeight: height,
    availableWidth: availableW,
    currentX: startX,
    colMode: cmDynamic # Default
  )
  ui.layoutStack.add(node)

proc beginSpaceLayout*(height: float) =
  alias(ui, g_uiState)
  alias(a, ui.autoLayoutState)
  
  let (x, y) = addDrawOffset(a.x, a.y)

  var node = LayoutNode(
    mode: lmSpace,
    x: x,
    y: y,
    w: a.rowWidth,
    h: height
  )
  ui.layoutStack.add(node)
  pushDrawOffset(DrawOffset(ox: x, oy: y))

proc endLayout*() =
  alias(ui, g_uiState)
  if ui.layoutStack.len > 0:
    let node = ui.layoutStack.pop()
    if node.mode == lmSpace:
      popDrawOffset()
    
    # Advance the vertical auto-layout by the height of the layout
    ui.autoLayoutState.y += node.h
    ui.autoLayoutState.y += ui.autoLayoutParams.sectionPad

proc beginColumn*(mode: ColMode, value: float = 0.0) =
  alias(ui, g_uiState)
  if ui.layoutStack.len > 0 and ui.layoutStack[^1].mode == lmRow:
    alias(node, ui.layoutStack[^1])
    node.colMode = mode
    node.colWidth = value # For static, it's width; for ratio, it's ratio

proc endColumn*() =
  alias(ui, g_uiState)
  if ui.layoutStack.len > 0 and ui.layoutStack[^1].mode == lmRow:
    inc(ui.layoutStack[^1].colIndex)

template layoutRow*(height: float, body: untyped) =
  beginRowLayout(height)
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

# }}}

# {{{ beginGroup*()
proc beginGroup*() =
  g_uiState.autoLayoutState.groupBegin = true

# }}}
# {{{ endGroup*()
proc endGroup*() =
  discard

# }}}
# {{{ group*()
template group*(body: untyped) =
  beginGroup()
  body
  endGroup()

# }}}
# {{{ nextLayoutColumn*()
proc nextLayoutColumn*() =
  autoLayoutPre()
  autoLayoutPost()

# }}}
