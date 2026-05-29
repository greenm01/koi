import std/options

import glfw
import nanovg

import koi/rect

type ItemId* = int64

type DrawLayer* = enum
  layerDefault
  layerDialog
  layerPopup
  layerWidgetOverlay
  layerTooltip
  layerGlobalOverlay
  layerWindowDecoration

type
  ColorPickerColorMode* = enum
    ccmRGB
    ccmHSV
    ccmHex

  ColorPickerMouseMode* = enum
    cmmNormal
    cmmLMBDown
    cmmDragWheel
    cmmDragTriangle

  ColorPickerStateVars* = object
    opened*: bool
    colorMode*: ColorPickerColorMode
    lastColorMode*: ColorPickerColorMode
    mouseMode*: ColorPickerMouseMode
    activeItem*: ItemId
    h*, s*, v*: float
    hexString*: string
    lastHue*: float
    colorCopyBuffer*: Color

type DialogStateVars* = object
  widgetInsidePopupCapturedFocus*: bool

type
  DropDownState* = enum
    dsClosed
    dsOpenLMBPressed
    dsOpen

  DropDownStateVars* = ref object of RootObj
    state*: DropDownState
    activeItem*: ItemId
    displayStartItem*: float
    keyboardItem*: int

type
  PopupState* = enum
    psOpenLMBDown
    psOpen

  PopupStateVars* = object
    state*: PopupState
    activeItem*: ItemId
    prevLayer*: DrawLayer
    prevHitClip*: Rect
    prevFocusCaptured*: bool
    closed*: bool
    widgetInsidePopupCapturedFocus*: bool

type RadioButtonStateVars* = object
  activeItem*: ItemId

type SectionHeaderStateVars* = object
  openSubHeaders*: bool

type MenuTraversalStateVars* = object
  activeMenu*: ItemId
  activeMenuIndex*: int
  activeItem*: int
  itemCount*: Natural
  moved*: int

type
  ScrollBarState* = enum
    sbsDefault
    sbsDragNormal
    sbsDragHidden
    sbsTrackClickFirst
    sbsTrackClickDelay
    sbsTrackClickRepeat

  ScrollBarStateVars* = object
    state*: ScrollBarState
    clickDir*: float

type ScrollViewStateVars* = object
  activeItem*: ItemId

type
  SliderState* = enum
    ssDefault
    ssDragHidden
    ssEditValue
    ssCancel

  SliderStateVars* = object
    state*: SliderState
    cursorMoved*: bool
    cursorPosX*: float
    cursorPosY*: float
    valueText*: string
    editModeItem*: ItemId
    textFieldId*: ItemId
    oldValue*: float

type TextSelection* = object
  startPos*: int
  endPos*: Natural

type
  TextAreaState* = enum
    tasDefault
    tasEditLMBPressed
    tasEdit
    tasDragStart
    tasDoubleClicked

  TextAreaStateVars* = ref object of RootObj
    state*: TextAreaState
    cursorPos*: Natural
    selection*: TextSelection
    activeItem*: ItemId
    displayStartRow*: float
    originalText*: string
    lastCursorXPos*: Option[float]

type
  TextFieldState* = enum
    tfsDefault
    tfsEditLMBPressed
    tfsEdit
    tfsDragStart
    tfsDragDelay
    tfsDragScroll
    tfsDoubleClicked

  TextFieldStateVars* = object
    state*: TextFieldState
    cursorPos*: Natural
    selection*: TextSelection
    activeItem*: ItemId
    displayStartPos*: Natural
    displayStartX*: float
    originalText*: string

type
  TooltipState* = enum
    tsOff
    tsShowDelay
    tsShow
    tsFadeOutDelay
    tsFadeOut

  TooltipStateVars* = object
    state*: TooltipState
    lastState*: TooltipState
    t0*: float
    text*: string
    lastHotItem*: ItemId

type WidgetState* = enum
  wsNormal
  wsHover
  wsDown
  wsActive
  wsActiveHover
  wsActiveDown
  wsDisabled

type WidgetGrouping* = enum
  wgNone
  wgStart
  wgMiddle
  wgEnd

type
  EventKind* = enum
    ekKey
    ekMouseButton
    ekScroll

  Event* = object
    case kind*: EventKind
    of ekKey:
      key*: Key
      action*: KeyAction
    of ekMouseButton:
      button*: MouseButton
      pressed*: bool
      x*, y*: float64
    of ekScroll:
      ox*, oy*: float64
    mods*: set[ModifierKey]

  KeyShortcut* = object
    key*: Key
    mods*: set[ModifierKey]

  TextEditShortcuts* = enum
    tesCursorOneCharLeft
    tesCursorOneCharRight
    tesCursorToPreviousWord
    tesCursorToNextWord
    tesCursorToLineStart
    tesCursorToLineEnd
    tesCursorToDocumentStart
    tesCursorToDocumentEnd
    tesCursorToPreviousLine
    tesCursorToNextLine
    tesCursorPageUp
    tesCursorPageDown
    tesSelectionAll
    tesSelectionOneCharLeft
    tesSelectionOneCharRight
    tesSelectionToPreviousWord
    tesSelectionToNextWord
    tesSelectionToLineStart
    tesSelectionToLineEnd
    tesSelectionToDocumentStart
    tesSelectionToDocumentEnd
    tesSelectionToPreviousLine
    tesSelectionToNextLine
    tesSelectionPageUp
    tesSelectionPageDown
    tesDeleteOneCharLeft
    tesDeleteOneCharRight
    tesDeleteWordToRight
    tesDeleteWordToLeft
    tesDeleteToLineStart
    tesDeleteToLineEnd
    tesCutText
    tesCopyText
    tesPasteText
    tesInsertNewline
    tesPrevTextField
    tesNextTextField
    tesAccept
    tesCancel

  ShortcutMode* = enum
    smWindows = (0, "Windows")
    smMac = (1, "Mac")
    smLinux = (2, "Linux")

  Size* = object
    w*, h*: float

  Padding* = object
    left*, right*, top*, bottom*: float

  LayoutNodeId* = distinct int32

  LayoutSizeKind* = enum
    lskFit
    lskGrow
    lskFixed
    lskPercent

  LayoutSize* = object
    min*: float
    max*: float
    case kind*: LayoutSizeKind
    of lskFixed:
      value*: float
    of lskPercent:
      percent*: float
    of lskFit, lskGrow:
      discard

  LayoutAlign* = enum
    laStart
    laCenter
    laEnd
    laSpaceBetween

  LayoutCrossAlign* = enum
    lcaStart
    lcaCenter
    lcaEnd
    lcaStretch

  LayoutDirection* = enum
    ldLeftToRight
    ldTopToBottom

  LayoutNodeKind* = enum
    lnkContainer
    lnkText
    lnkWidget

  LayoutPlacementKind* = enum
    lpkFlow
    lpkManual
    lpkFollow

  LayoutFollowerKind* = enum
    lfkVerticalScrollBar
    lfkHorizontalScrollBar

  LayoutPlacement* = object
    case kind*: LayoutPlacementKind
    of lpkFlow:
      discard
    of lpkManual:
      x*, y*: float
    of lpkFollow:
      target*: LayoutNodeId
      followKind*: LayoutFollowerKind

  TextMeasure* = object
    minWidth*: float
    prefWidth*: float
    lineHeight*: float
    lineCount*: int

  MeasureTextProc* = proc(
    text: string, fontSize: float, fontFace: string, maxWidth: float
  ): TextMeasure {.closure.}

  LayoutNode* = object
    id*: LayoutNodeId
    itemId*: ItemId
    parent*: LayoutNodeId
    firstChild*: int32
    childCount*: int32
    kind*: LayoutNodeKind
    placement*: LayoutPlacement
    direction*: LayoutDirection
    width*: LayoutSize
    height*: LayoutSize
    padding*: Padding
    childGap*: float
    alignMain*: LayoutAlign
    alignCross*: LayoutCrossAlign
    intrinsicMin*: Size
    intrinsicPref*: Size
    rect*: Rect
    contentSize*: Size
    scrollOffset*: Size
    text*: string
    fontSize*: float
    fontFace*: string

  LayoutArena* = object
    nodes*: seq[LayoutNode]
    childIndices*: seq[LayoutNodeId]
    childLists*: seq[seq[LayoutNodeId]]
    nodeStack*: seq[LayoutNodeId]
    measureText*: MeasureTextProc

  LayoutSlot* = object
    itemId*: ItemId
    nodeId*: LayoutNodeId
    bounds*: Rect
    previousBounds*: Rect

  ColMode* = enum
    cmStatic
    cmDynamic
    cmVariable
    cmRatio

  LayoutColumn* = object
    mode*: ColMode
    value*: float

  LayoutPresetMode* = enum
    lpmRow
    lpmSpace
    lpmViewport

  LayoutPresetFrame* = object
    mode*: LayoutPresetMode
    x*, y*, w*, h*: float
    rowHeight*: float
    availableWidth*: float
    currentX*: float
    itemSpacing*: float
    colIndex*: int
    columns*: seq[LayoutColumn]
    resolvedWidths*: seq[float]
    resolvedSizes*: seq[LayoutSize]
    currentColumn*: LayoutColumn
    hasCurrentColumn*: bool
    nodeId*: LayoutNodeId
    rowSlotOwned*: bool
    savedActiveSlotParent*: LayoutNodeId
    savedActiveSlotUsed*: bool

type
  DrawOffset* = object
    ox*, oy*: float

  AutoLayoutParams* = object
    itemsPerRow*: Natural
    rowWidth*: float
    labelWidth*: float
    sectionPad*: float
    leftPad*: float
    rightPad*: float
    rowPad*: float
    rowGroupPad*: float
    defaultRowHeight*: float
    defaultItemHeight*: float

  AutoLayoutStateVars* = object
    rowWidth*: float
    rowHeight*: float
    x*, y*: float
    autoRoot*: LayoutNodeId
    autoRow*: LayoutNodeId
    activeSlotParent*: LayoutNodeId
    activeSlotUsed*: bool
    currColIndex*: Natural
    nextRowHeight*: Option[float]
    nextItemWidth*: float
    nextItemHeight*: float
    lastItemWidth*: float
    nextItemWidthOverride*: Option[float]
    nextItemHeightOverride*: Option[float]
    firstRow*: bool
    prevSection*: bool
    groupBegin*: bool

  TabActivationStateVars* = object
    prevItem*: ItemId
    itemToActivate*: ItemId
    activateNext*: bool
    activatePrev*: bool

type TextRow* = object
  startPos*: Natural
  startBytePos*: Natural
  endPos*: Natural
  endBytePos*: Natural
  nextRowPos*: int
  nextRowBytePos*: int
  width*: float

type ListViewRange* = object
  first*: Natural
  last*: Natural
  startY*: float
  contentHeight*: float

# Style Types

type ShadowStyle* = ref object
  enabled*: bool
  cornerRadius*: float
  xOffset*: float
  yOffset*: float
  widthOffset*: float
  heightOffset*: float
  feather*: float
  color*: Color

type LabelStyle* = ref object
  fontSize*: float
  fontFace*: string
  vertAlignFactor*: float
  padHoriz*: float
  align*: HorizontalAlign
  multiLine*: bool
  lineHeight*: float
  color*: Color
  colorHover*: Color
  colorDown*: Color
  colorActive*: Color
  colorActiveHover*: Color
  colorDisabled*: Color

type PopupStyle* = ref object
  autoClose*: bool
  autoCloseBorder*: float
  backgroundCornerRadius*: float
  backgroundStrokeWidth*: float
  backgroundStrokeColor*: Color
  backgroundFillColor*: Color
  shadow*: ShadowStyle

type ButtonStyle* = ref object
  cornerRadius*: float
  strokeWidth*: float
  strokeColor*: Color
  strokeColorHover*: Color
  strokeColorDown*: Color
  strokeColorDisabled*: Color
  fillColor*: Color
  fillColorHover*: Color
  fillColorDown*: Color
  fillColorDisabled*: Color
  label*: LabelStyle

type SelectableStyle* = ref object
  cornerRadius*: float
  strokeWidth*: float
  strokeColor*: Color
  strokeColorHover*: Color
  strokeColorDown*: Color
  strokeColorActive*: Color
  strokeColorActiveHover*: Color
  strokeColorDisabled*: Color
  fillColor*: Color
  fillColorHover*: Color
  fillColorDown*: Color
  fillColorActive*: Color
  fillColorActiveHover*: Color
  fillColorDisabled*: Color
  label*: LabelStyle

type ToggleButtonStyle* = ref object
  cornerRadius*: float
  strokeWidth*: float
  strokeColor*: Color
  strokeColorHover*: Color
  strokeColorDown*: Color
  strokeColorActive*: Color
  strokeColorActiveHover*: Color
  strokeColorDisabled*: Color
  fillColor*: Color
  fillColorHover*: Color
  fillColorDown*: Color
  fillColorActive*: Color
  fillColorActiveHover*: Color
  fillColorDisabled*: Color
  label*: LabelStyle
  labelActive*: LabelStyle

type CheckBoxStyle* = ref object
  cornerRadius*: float
  strokeWidth*: float
  strokeColor*: Color
  strokeColorHover*: Color
  strokeColorDown*: Color
  strokeColorActive*: Color
  strokeColorActiveHover*: Color
  strokeColorDisabled*: Color
  fillColor*: Color
  fillColorHover*: Color
  fillColorDown*: Color
  fillColorActive*: Color
  fillColorActiveHover*: Color
  fillColorDisabled*: Color
  icon*: LabelStyle
  iconActive*: string
  iconInactive*: string

type
  RadioButtonsLayoutKind* = enum
    rblHoriz
    rblGridHoriz
    rblGridVert

  RadioButtonsLayout* = object
    case kind*: RadioButtonsLayoutKind
    of rblHoriz: discard
    of rblGridHoriz: itemsPerRow*: Natural
    of rblGridVert: itemsPerColumn*: Natural

type RadioButtonsStyle* = ref object
  buttonPadHoriz*: float
  buttonPadVert*: float
  buttonCornerRadius*: float
  buttonStrokeWidth*: float
  buttonStrokeColor*: Color
  buttonStrokeColorHover*: Color
  buttonStrokeColorDown*: Color
  buttonStrokeColorActive*: Color
  buttonStrokeColorActiveHover*: Color
  buttonFillColor*: Color
  buttonFillColorHover*: Color
  buttonFillColorDown*: Color
  buttonFillColorActive*: Color
  buttonFillColorActiveHover*: Color
  label*: LabelStyle

type ScrollBarStyle* = ref object
  trackCornerRadius*: float
  trackStrokeWidth*: float
  trackStrokeColor*: Color
  trackStrokeColorHover*: Color
  trackStrokeColorDown*: Color
  trackFillColor*: Color
  trackFillColorHover*: Color
  trackFillColorDown*: Color
  thumbCornerRadius*: float
  thumbPad*: float
  thumbMinSize*: float
  thumbStrokeWidth*: float
  thumbStrokeColor*: Color
  thumbStrokeColorHover*: Color
  thumbStrokeColorDown*: Color
  thumbFillColor*: Color
  thumbFillColorHover*: Color
  thumbFillColorDown*: Color
  autoFade*: bool
  autoFadeStartAlpha*: float
  autoFadeEndAlpha*: float
  autoFadeDistance*: float

type DropDownStyle* = ref object
  buttonCornerRadius*: float
  buttonStrokeWidth*: float
  buttonStrokeColor*: Color
  buttonStrokeColorHover*: Color
  buttonStrokeColorDown*: Color
  buttonStrokeColorDisabled*: Color
  buttonFillColor*: Color
  buttonFillColorHover*: Color
  buttonFillColorDown*: Color
  buttonFillColorDisabled*: Color
  label*: LabelStyle
  itemListAlign*: HorizontalAlign
  itemListPadHoriz*: float
  itemListPadVert*: float
  itemListCornerRadius*: float
  itemListStrokeWidth*: float
  itemListStrokeColor*: Color
  itemListFillColor*: Color
  item*: LabelStyle
  itemBackgroundColorHover*: Color
  shadow*: ShadowStyle
  scrollBarWidth*: float
  scrollBarStyle*: ScrollBarStyle

type
  TextFieldFilterKind* = enum
    tffAny
    tffInteger
    tffFloat
    tffHex
    tffBinary

  TextFieldConstraintKind* = enum
    tckString
    tckInteger

  TextFieldConstraint* = object
    case kind*: TextFieldConstraintKind
    of tckString:
      minLen*: Natural
      maxLen*: Option[Natural]
    of tckInteger:
      minInt*, maxInt*: int

type TextFieldStyle* = ref object
  bgCornerRadius*: float
  bgStrokeWidth*: float
  bgStrokeColor*: Color
  bgStrokeColorHover*: Color
  bgStrokeColorActive*: Color
  bgStrokeColorDisabled*: Color
  bgFillColor*: Color
  bgFillColorHover*: Color
  bgFillColorActive*: Color
  bgFillColorDisabled*: Color
  textPadHoriz*: float
  textPadVert*: float
  textFontSize*: float
  textFontFace*: string
  textColor*: Color
  textColorHover*: Color
  textColorActive*: Color
  textColorDisabled*: Color
  cursorWidth*: float
  cursorColor*: Color
  selectionColor*: Color

type TextAreaConstraint* = object
  maxLen*: Option[Natural]

type TextAreaStyle* = object
  bgCornerRadius*: float
  bgStrokeWidth*: float
  bgStrokeColor*: Color
  bgStrokeColorHover*: Color
  bgStrokeColorActive*: Color
  bgStrokeColorDisabled*: Color
  bgFillColor*: Color
  bgFillColorHover*: Color
  bgFillColorActive*: Color
  bgFillColorDisabled*: Color
  textPadHoriz*: float
  textPadVert*: float
  textFontSize*: float
  textFontFace*: string
  textLineHeight*: float
  textColor*: Color
  textColorHover*: Color
  textColorActive*: Color
  textColorDisabled*: Color
  cursorWidth*: float
  cursorColor*: Color
  selectionColor*: Color
  scrollBarWidth*: float
  scrollBarStyleNormal*: ScrollBarStyle
  scrollBarStyleEdit*: ScrollBarStyle

type SliderStyle* = ref object
  trackCornerRadius*: float
  trackPad*: float
  trackStrokeWidth*: float
  trackStrokeColor*: Color
  trackStrokeColorHover*: Color
  trackStrokeColorDown*: Color
  trackFillColor*: Color
  trackFillColorHover*: Color
  trackFillColorDown*: Color
  valuePrecision*: Natural
  valueSuffix*: string
  valueCornerRadius*: float
  sliderColor*: Color
  sliderColorHover*: Color
  sliderColorDown*: Color
  label*: LabelStyle
  value*: LabelStyle
  cursorFollowsValue*: bool

type ProgressStyle* = ref object
  cornerRadius*: float
  strokeWidth*: float
  strokeColor*: Color
  fillColor*: Color
  valueColor*: Color
  label*: LabelStyle

type PropertyStyle* = ref object
  labelWidth*: float
  buttonWidth*: float
  gap*: float
  valuePrecision*: Natural
  label*: LabelStyle
  button*: ButtonStyle
  textField*: TextFieldStyle

type MenuStyle* = ref object
  menuBarHeight*: float
  menuButtonWidth*: float
  menuItemHeight*: float
  popupWidth*: float
  popupPad*: float
  barFillColor*: Color
  button*: ButtonStyle
  item*: SelectableStyle
  popup*: PopupStyle

type ChartKind* = enum
  ckLine
  ckColumns

type ChartSeries* = object
  label*: string
  values*: seq[float]
  kind*: ChartKind
  color*: Color

type ChartStyle* = ref object
  backgroundColor*: Color
  strokeColor*: Color
  lineColor*: Color
  columnColor*: Color
  zeroLineColor*: Color
  strokeWidth*: float
  lineWidth*: float
  columnGap*: float
  label*: LabelStyle

type TableSortDirection* = enum
  tsdNone
  tsdAsc
  tsdDesc

type TableSortState* = object
  column*: int
  direction*: TableSortDirection

type TableColumn* = object
  label*: string
  width*: float

type TableStyle* = ref object
  headerHeight*: float
  rowHeight*: float
  headerFillColor*: Color
  rowFillColor*: Color
  rowAltFillColor*: Color
  rowHoverFillColor*: Color
  strokeColor*: Color
  strokeWidth*: float
  headerLabel*: LabelStyle
  rowLabel*: LabelStyle

type ColorComboStyle* = ref object
  popupWidth*: float
  popupHeight*: float
  popupPad*: float
  swatchSize*: float
  swatchGap*: float
  button*: ButtonStyle
  popup*: PopupStyle
  label*: LabelStyle

type GroupBoxStyle* = ref object
  titleHeight*: float
  pad*: float
  cornerRadius*: float
  strokeWidth*: float
  strokeColor*: Color
  fillColor*: Color
  titleFillColor*: Color
  titleLabel*: LabelStyle

type SectionHeaderStyle* = ref object
  label*: LabelStyle
  labelLeftPad*: float
  height*: float
  hitRightPad*: float
  backgroundColor*: Color
  separatorColor*: Color
  triangleSize*: float
  triangleLeftPad*: float
  triangleColor*: Color

type ScrollViewStyle* = ref object
  vertScrollBarWidth*: float
  horizScrollBarHeight*: float
  scrollBarStyle*: ScrollBarStyle
  scrollWheelSensitivity*: float

type DialogStyle* = ref object
  cornerRadius*: float
  backgroundColor*: Color
  drawTitleBar*: bool
  titleBarBgColor*: Color
  titleBarTextColor*: Color
  outerBorderColor*: Color
  innerBorderColor*: Color
  outerBorderWidth*: float
  innerBorderWidth*: float
  shadow*: ShadowStyle
