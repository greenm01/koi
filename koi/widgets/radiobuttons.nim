import std/options
import std/math
import std/sets

import nanovg

import koi/types
import koi/core
import koi/drawing
import koi/layout
import koi/rect
import koi/input
import koi/defaults
import koi/internal/widget_behavior
import koi/widgets/common
import koi/utils

# RadioButtonsDrawProc*
type RadioButtonsDrawProc* = proc(
  vg: NVGContext,
  id: ItemId,
  x, y, w, h: float,
  buttonIdx, numButtons: Natural,
  label: string,
  state: WidgetState,
  style: RadioButtonsStyle,
)

# DefaultRadioButtonDrawProc
let DefaultRadioButtonDrawProc*: RadioButtonsDrawProc = proc(
    vg: NVGContext,
    id: ItemId,
    x, y, w, h: float,
    buttonIdx, numButtons: Natural,
    label: string,
    state: WidgetState,
    style: RadioButtonsStyle,
) =
  alias(s, style)

  let (fillColor, strokeColor) =
    case state
    of wsNormal, wsDisabled:
      (s.buttonFillColor, s.buttonStrokeColor)
    of wsHover:
      (s.buttonFillColorHover, s.buttonStrokeColorHover)
    of wsDown, wsActiveDown:
      (s.buttonFillColorDown, s.buttonStrokeColorDown)
    of wsActive:
      (s.buttonFillColorActive, s.buttonStrokeColorActive)
    of wsActiveHover:
      (s.buttonFillColorActiveHover, s.buttonStrokeColorActiveHover)

  vg.fillColor(fillColor)
  vg.strokeColor(strokeColor)
  vg.strokeWidth(s.buttonStrokeWidth)

  vg.beginPath()

  let
    first = (buttonIdx == 0)
    last = (buttonIdx == numButtons - 1)

  let cr = s.buttonCornerRadius
  if first:
    vg.roundedRect(x, y, w, h, cr, 0, 0, cr)
  elif last:
    vg.roundedRect(x, y, w, h, 0, cr, cr, 0)
  else:
    vg.rect(x, y, w, h)

  vg.fill()
  vg.stroke()

  vg.drawLabel(x, y, w, h, label, state, s.label)
# DefaultRadioButtonGridDrawProc
let DefaultRadioButtonGridDrawProc*: RadioButtonsDrawProc = proc(
    vg: NVGContext,
    id: ItemId,
    x, y, w, h: float,
    buttonIdx, numButtons: Natural,
    label: string,
    state: WidgetState,
    style: RadioButtonsStyle,
) =
  alias(s, style)

  let (x, y, w, h) = snapToGrid(x, y, w, h, s.buttonStrokeWidth)

  let (fillColor, strokeColor) =
    case state
    of wsNormal, wsDisabled:
      (s.buttonFillColor, s.buttonStrokeColor)
    of wsHover:
      (s.buttonFillColorHover, s.buttonStrokeColorHover)
    of wsDown, wsActiveDown:
      (s.buttonFillColorDown, s.buttonStrokeColorDown)
    of wsActive:
      (s.buttonFillColorActive, s.buttonStrokeColorActive)
    of wsActiveHover:
      (s.buttonFillColorActiveHover, s.buttonStrokeColorActiveHover)

  vg.fillColor(fillColor)
  vg.strokeColor(strokeColor)
  vg.strokeWidth(s.buttonStrokeWidth)

  vg.beginPath()
  vg.roundedRect(x, y, w, h, s.buttonCornerRadius)
  vg.fill()
  vg.stroke()

  vg.drawLabel(x, y, w, h, label, state, s.label)
# radioButtons()
proc radioButtons*[T](
    id: ItemId,
    x, y, w, h: float,
    labels: seq[string],
    activeButtons_out: var seq[T],
    tooltips: seq[string] = @[],
    multiselect: bool = false,
    allowNoSelection: bool = false,
    layout: RadioButtonsLayout = RadioButtonsLayout(kind: rblHoriz),
    drawProc: Option[RadioButtonsDrawProc] = RadioButtonsDrawProc.none,
    style: RadioButtonsStyle = borrowDefaultRadioButtonsStyle(),
) =
  if multiselect:
    assert activeButtons_out.len <= labels.len
    if not allowNoSelection:
      assert activeButtons_out.len >= 1
  else:
    assert activeButtons_out.len == 1

  for i in 0 .. activeButtons_out.high:
    assert activeButtons_out[i].ord >= 0 and activeButtons_out[i].ord <= labels.high

    activeButtons_out[i] = activeButtons_out[i].clamp(T.low, T.high)

  alias(ui, g_uiState)
  alias(rs, ui.radioButtonState)
  alias(s, style)

  let (xo, yo) = addDrawOffset(x, y)
  let (x, y, w, h) = snapToGrid(xo, yo, w, h, s.buttonStrokeWidth)

  let numButtons = labels.len
  let
    fallbackBounds =
      case layout.kind
      of rblHoriz:
        rect(x, y, w, h)
      of rblGridHoriz:
        let
          itemsPerRow = max(layout.itemsPerRow, 1)
          numRows = ceil(numButtons.float / itemsPerRow.float).Natural
        rect(x, y, itemsPerRow.float * w, numRows.float * h)
      of rblGridVert:
        let
          itemsPerColumn = max(layout.itemsPerColumn, 1)
          numCols = ceil(numButtons.float / itemsPerColumn.float).Natural
        rect(x, y, numCols.float * w, itemsPerColumn.float * h)
    slot = layoutSlot(id, fallbackBounds)
    hitBounds = slot.previousBounds

  # Hit testing
  var hotButton = -1

  proc markHotAndActive() =
    captureSimpleWidget(id, disabled = false)
    if isActive(id):
      rs.activeItem = hotButton

  proc markHotButton(button: int) =
    if hasNoActiveItem() or (hasActiveItem() and button == rs.activeItem):
      hotButton = button

  func calcHorizButtonIdx(x, w: float, numButtons: Natural): int =
    if x < 0 or x > w:
      -1
    else:
      let bw = w / numButtons.float
      min(floor(x / bw).int, numButtons - 1)

  case layout.kind
  of rblHoriz:
    let button = calcHorizButtonIdx(x = ui.mx - hitBounds.x, hitBounds.w, numButtons)
    markHotButton(button)

    if isHit(hitBounds.x, hitBounds.y, hitBounds.w, hitBounds.h) and hotButton > -1:
      markHotAndActive()
  of rblGridHoriz:
    let
      itemsPerRow = max(layout.itemsPerRow, 1)
      numRows = max(ceil(numButtons.float / itemsPerRow.float).Natural, 1)
      buttonW = hitBounds.w / itemsPerRow.float
      buttonH = hitBounds.h / numRows.float
      row = ((ui.my - hitBounds.y) / buttonH).int
      col = ((ui.mx - hitBounds.x) / buttonW).int
      button = row * itemsPerRow + col

    if row >= 0 and col >= 0 and button < numButtons:
      markHotButton(button)

    if isHit(hitBounds.x, hitBounds.y, hitBounds.w, hitBounds.h) and hotButton > -1:
      markHotAndActive()
  of rblGridVert:
    let
      itemsPerColumn = max(layout.itemsPerColumn, 1)
      numCols = max(ceil(numButtons.float / itemsPerColumn.float).Natural, 1)
      buttonW = hitBounds.w / numCols.float
      buttonH = hitBounds.h / itemsPerColumn.float
      row = ((ui.my - hitBounds.y) / buttonH).int
      col = ((ui.mx - hitBounds.x) / buttonW).int
      button = col * itemsPerColumn + row

    if row >= 0 and col >= 0 and button < numButtons:
      markHotButton(button)

    if isHit(hitBounds.x, hitBounds.y, hitBounds.w, hitBounds.h) and hotButton > -1:
      markHotAndActive()

  # LMB released over active widget means it was clicked
  if simpleWidgetBehavior(id, disabled = false).clicked and rs.activeItem == hotButton:
    let activeButton = T(hotButton)

    if multiselect and not ctrlDown():
      let idx = activeButtons_out.find(activeButton)
      if idx < 0:
        activeButtons_out.add(activeButton)
      else:
        if allowNoSelection or activeButtons_out.len > 1:
          activeButtons_out.del(idx)
    else:
      activeButtons_out = @[activeButton]

  let activeButtons = activeButtons_out

  # Draw radio buttons
  proc buttonDrawState(i: Natural): WidgetState =
    radioButtonState(
      isHot(id),
      isActive(id),
      hasNoActiveItem(),
      T(i) in activeButtons,
      hotButton,
      i.int,
    )

  addLayoutDrawLayer(ui.currentLayer, slot.nodeId, vg, bounds):
    var x = bounds.x
    var y = bounds.y
    let
      drawGroupW = bounds.w
      drawGroupH = bounds.h

    let drawProc =
      if drawProc.isSome:
        drawProc.get
      else:
        case layout.kind
        of rblHoriz: DefaultRadioButtonDrawProc
        else: DefaultRadioButtonGridDrawProc

    case layout.kind
    of rblHoriz:
      let bw =
        (drawGroupW - (s.buttonPadHoriz * (numButtons - 1).float)) /
        numButtons.float
      for i, label in labels:
        let
          state = buttonDrawState(i)
          last = (i == labels.len - 1)
          w = round(x + bw) - round(x)

        drawProc(
          vg,
          id,
          round(x),
          y,
          w,
          drawGroupH,
          buttonIdx = i,
          numButtons = labels.len,
          label,
          state,
          style,
        )

        x += bw
        if not last:
          x += s.buttonPadHoriz
    of rblGridHoriz:
      let startX = x
      let
        itemsPerRow = max(layout.itemsPerRow, 1)
        numRows = max(ceil(numButtons.float / itemsPerRow.float).Natural, 1)
        buttonW = drawGroupW / itemsPerRow.float
        buttonH = drawGroupH / numRows.float
      var itemsInRow = 0
      for i, label in labels:
        let state = buttonDrawState(i)
        drawProc(
          vg,
          id,
          x,
          y,
          buttonW,
          buttonH,
          buttonIdx = i,
          numButtons = labels.len,
          label,
          state,
          style,
        )

        inc(itemsInRow)
        if itemsInRow == itemsPerRow:
          y += buttonH
          x = startX
          itemsInRow = 0
        else:
          x += buttonW
    of rblGridVert:
      let startY = y
      let
        itemsPerColumn = max(layout.itemsPerColumn, 1)
        numCols = max(ceil(numButtons.float / itemsPerColumn.float).Natural, 1)
        buttonW = drawGroupW / numCols.float
        buttonH = drawGroupH / itemsPerColumn.float
      var itemsInColumn = 0
      for i, label in labels:
        let state = buttonDrawState(i)
        drawProc(
          vg,
          id,
          x,
          y,
          buttonW,
          buttonH,
          buttonIdx = i,
          numButtons = labels.len,
          label,
          state,
          style,
        )

        inc(itemsInColumn)
        if itemsInColumn == itemsPerColumn:
          x += buttonW
          y = startY
          itemsInColumn = 0
        else:
          y += buttonH

  if isHot(id):
    let tt =
      if hotButton >= 0 and hotButton <= tooltips.high:
        tooltips[hotButton]
      else:
        ""

    handleTooltip(id, tt)

# radioButtons templates - seq[string]

template radioButtons*[T](
    x, y, w, h: float,
    labels: seq[string],
    activeButton: var T,
    tooltips: seq[string] = @[],
    layout: RadioButtonsLayout = RadioButtonsLayout(kind: rblHoriz),
    drawProc: Option[RadioButtonsDrawProc] = RadioButtonsDrawProc.none,
    style: RadioButtonsStyle = borrowDefaultRadioButtonsStyle(),
) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)

  var activeButtons = @[activeButton]

  radioButtons(
    id,
    x,
    y,
    w,
    h,
    labels,
    activeButtons,
    tooltips,
    multiselect = false,
    allowNoSelection = false,
    layout,
    drawProc,
    style,
  )

  activeButton = activeButtons[0]

template radioButtons*[T](
    labels: seq[string],
    activeButton: var T,
    tooltips: seq[string] = @[],
    layout: RadioButtonsLayout = RadioButtonsLayout(kind: rblHoriz),
    drawProc: Option[RadioButtonsDrawProc] = RadioButtonsDrawProc.none,
    style: RadioButtonsStyle = borrowDefaultRadioButtonsStyle(),
) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)

  autoLayoutPre()

  var activeButtons = @[activeButton]

  radioButtons(
    id,
    g_uiState.autoLayoutState.x,
    autoLayoutNextY(),
    autoLayoutNextItemWidth(),
    autoLayoutNextItemHeight(),
    labels,
    activeButtons,
    tooltips,
    multiselect = false,
    allowNoSelection = false,
    layout,
    drawProc,
    style,
  )

  autoLayoutPost()
  activeButton = activeButtons[0]

template radioButtons*[T](
    x, y, w, h: float,
    labels: seq[string],
    activeButtons: var seq[T],
    tooltips: seq[string] = @[],
    multiselect: bool = true,
    allowNoSelection: bool = false,
    layout: RadioButtonsLayout = RadioButtonsLayout(kind: rblHoriz),
    drawProc: Option[RadioButtonsDrawProc] = RadioButtonsDrawProc.none,
    style: RadioButtonsStyle = borrowDefaultRadioButtonsStyle(),
) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)

  radioButtons(
    id, x, y, w, h, labels, activeButtons, tooltips, multiselect, allowNoSelection,
    layout, drawProc, style,
  )

template radioButtons*[T](
    labels: seq[string],
    activeButtons: var seq[T],
    tooltips: seq[string] = @[],
    multiselect: bool = true,
    allowNoSelection: bool = false,
    layout: RadioButtonsLayout = RadioButtonsLayout(kind: rblHoriz),
    drawProc: Option[RadioButtonsDrawProc] = RadioButtonsDrawProc.none,
    style: RadioButtonsStyle = borrowDefaultRadioButtonsStyle(),
) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)

  autoLayoutPre()

  radioButtons(
    id,
    g_uiState.autoLayoutState.x,
    autoLayoutNextY(),
    autoLayoutNextItemWidth(),
    autoLayoutNextItemHeight(),
    labels,
    activeButtons,
    tooltips,
    multiselect,
    allowNoSelection,
    layout,
    drawProc,
    style,
  )

  autoLayoutPost()

template radioButtons*[E: enum](
    x, y, w, h: float,
    activeButton: var E,
    tooltips: seq[string] = @[],
    layout: RadioButtonsLayout = RadioButtonsLayout(kind: rblHoriz),
    drawProc: Option[RadioButtonsDrawProc] = RadioButtonsDrawProc.none,
    style: RadioButtonsStyle = borrowDefaultRadioButtonsStyle(),
) =
  let
    i = instantiationInfo(fullPaths = true)
    id = nextId(i.filename, i.line)
    labels = enumToSeq[E]()

  var activeButtons = @[activeButton]
  radioButtons(
    id,
    x,
    y,
    w,
    h,
    labels,
    activeButtons,
    tooltips,
    multiselect = false,
    allowNoSelection = false,
    layout,
    drawProc,
    style,
  )
  activeButton = activeButtons[0]

template radioButtons*[E: enum](
    activeButton: var E,
    tooltips: seq[string] = @[],
    layout: RadioButtonsLayout = RadioButtonsLayout(kind: rblHoriz),
    drawProc: Option[RadioButtonsDrawProc] = RadioButtonsDrawProc.none,
    style: RadioButtonsStyle = borrowDefaultRadioButtonsStyle(),
) =
  let
    i = instantiationInfo(fullPaths = true)
    id = nextId(i.filename, i.line)
    labels = enumToSeq[E]()

  autoLayoutPre()
  var activeButtons = @[activeButton]
  radioButtons(
    id,
    g_uiState.autoLayoutState.x,
    autoLayoutNextY(),
    autoLayoutNextItemWidth(),
    autoLayoutNextItemHeight(),
    labels,
    activeButtons,
    tooltips,
    multiselect = false,
    allowNoSelection = false,
    layout,
    drawProc,
    style,
  )
  activeButton = activeButtons[0]
  autoLayoutPost()

template multiRadioButtons*[T](
    x, y, w, h: float,
    labels: seq[string],
    activeButtons: var seq[T],
    allowNoSelection: bool = false,
    tooltips: seq[string] = @[],
    layout: RadioButtonsLayout = RadioButtonsLayout(kind: rblHoriz),
    drawProc: Option[RadioButtonsDrawProc] = RadioButtonsDrawProc.none,
    style: RadioButtonsStyle = borrowDefaultRadioButtonsStyle(),
) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)
  radioButtons(
    id,
    x,
    y,
    w,
    h,
    labels,
    activeButtons,
    tooltips,
    multiselect = true,
    allowNoSelection,
    layout,
    drawProc,
    style,
  )

template multiRadioButtons*[T](
    labels: seq[string],
    activeButtons: var seq[T],
    allowNoSelection: bool = false,
    tooltips: seq[string] = @[],
    layout: RadioButtonsLayout = RadioButtonsLayout(kind: rblHoriz),
    drawProc: Option[RadioButtonsDrawProc] = RadioButtonsDrawProc.none,
    style: RadioButtonsStyle = borrowDefaultRadioButtonsStyle(),
) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)

  autoLayoutPre()
  radioButtons(
    id,
    g_uiState.autoLayoutState.x,
    autoLayoutNextY(),
    autoLayoutNextItemWidth(),
    autoLayoutNextItemHeight(),
    labels,
    activeButtons,
    tooltips,
    multiselect = true,
    allowNoSelection,
    layout,
    drawProc,
    style,
  )
  autoLayoutPost()

template multiRadioButtons*[E: enum](
    x, y, w, h: float,
    activeButtons: var set[E],
    allowNoSelection: bool = false,
    tooltips: seq[string] = @[],
    layout: RadioButtonsLayout = RadioButtonsLayout(kind: rblHoriz),
    drawProc: Option[RadioButtonsDrawProc] = RadioButtonsDrawProc.none,
    style: RadioButtonsStyle = borrowDefaultRadioButtonsStyle(),
) =
  let
    i = instantiationInfo(fullPaths = true)
    id = nextId(i.filename, i.line)
    labels = enumToSeq[E]()

  var activeButtonsSeq: seq[E] = @[]
  for b in activeButtons:
    activeButtonsSeq.add(b)

  radioButtons(
    id,
    x,
    y,
    w,
    h,
    labels,
    activeButtonsSeq,
    tooltips,
    multiselect = true,
    allowNoSelection,
    layout,
    drawProc,
    style,
  )

  activeButtons = {}
  for b in activeButtonsSeq:
    activeButtons.incl(b)

template multiRadioButtons*[E: enum](
    activeButtons: var set[E],
    allowNoSelection: bool = false,
    tooltips: seq[string] = @[],
    layout: RadioButtonsLayout = RadioButtonsLayout(kind: rblHoriz),
    drawProc: Option[RadioButtonsDrawProc] = RadioButtonsDrawProc.none,
    style: RadioButtonsStyle = borrowDefaultRadioButtonsStyle(),
) =
  let
    i = instantiationInfo(fullPaths = true)
    id = nextId(i.filename, i.line)
    labels = enumToSeq[E]()

  autoLayoutPre()
  var activeButtonsSeq: seq[E] = @[]
  for b in activeButtons:
    activeButtonsSeq.add(b)

  radioButtons(
    id,
    g_uiState.autoLayoutState.x,
    autoLayoutNextY(),
    autoLayoutNextItemWidth(),
    autoLayoutNextItemHeight(),
    labels,
    activeButtonsSeq,
    tooltips,
    multiselect = true,
    allowNoSelection,
    layout,
    drawProc,
    style,
  )

  activeButtons = {}
  for b in activeButtonsSeq:
    activeButtons.incl(b)
  autoLayoutPost()
