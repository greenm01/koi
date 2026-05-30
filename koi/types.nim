import std/options

import nanovg

import koi/rect

when not defined(waylandBackend):
  from glfw as glfwLib import nil
  type
    Window* = glfwLib.Window
    Cursor* = glfwLib.Cursor

else:
  type
    Window* = ref object
    Cursor* = pointer

type ItemId* = int64

type MouseButton* {.size: int32.sizeof.} = enum
  mb1 = (0, "left mouse button")
  mb2 = (1, "right mouse button")
  mb3 = (2, "middle mouse button")
  mb4 = (3, "mouse button 4")
  mb5 = (4, "mouse button 5")
  mb6 = (5, "mouse button 6")
  mb7 = (6, "mouse button 7")
  mb8 = (7, "mouse button 8")

const
  mbLeft* = mb1
  mbRight* = mb2
  mbMiddle* = mb3

type
  ModifierKey* {.size: int32.sizeof.} = enum
    mkShift = (0x00000001, "shift")
    mkCtrl = (0x00000002, "ctrl")
    mkAlt = (0x00000004, "alt")
    mkSuper = (0x00000008, "super")
    mkCapsLock = (0x00000010, "capslock")
    mkNumLock = (0x00000020, "numlock")

  Key* {.size: int32.sizeof.} = enum
    keyUnknown = (-1, "unknown")
    keySpace = (32, "space")
    keyApostrophe = (39, "apostrophe")
    keyComma = (44, "comma")
    keyMinus = (45, "minus")
    keyPeriod = (46, "period")
    keySlash = (47, "slash")
    key0 = (48, "0")
    key1 = (49, "1")
    key2 = (50, "2")
    key3 = (51, "3")
    key4 = (52, "4")
    key5 = (53, "5")
    key6 = (54, "6")
    key7 = (55, "7")
    key8 = (56, "8")
    key9 = (57, "9")
    keySemicolon = (59, "semicolon")
    keyEqual = (61, "equal")
    keyA = (65, "a")
    keyB = (66, "b")
    keyC = (67, "c")
    keyD = (68, "d")
    keyE = (69, "e")
    keyF = (70, "f")
    keyG = (71, "g")
    keyH = (72, "h")
    keyI = (73, "i")
    keyJ = (74, "j")
    keyK = (75, "k")
    keyl = (76, "L")
    keyM = (77, "m")
    keyN = (78, "n")
    keyO = (79, "o")
    keyP = (80, "p")
    keyQ = (81, "q")
    keyR = (82, "r")
    keyS = (83, "s")
    keyT = (84, "t")
    keyU = (85, "u")
    keyV = (86, "v")
    keyW = (87, "w")
    keyX = (88, "x")
    keyY = (89, "y")
    keyZ = (90, "z")
    keyLeftBracket = (91, "left bracket")
    keyBackslash = (92, "backslash")
    keyRightBracket = (93, "right bracket")
    keyGraveAccent = (96, "grave accent")
    keyWorld1 = (161, "world1")
    keyWorld2 = (162, "world2")
    keyEscape = (256, "escape")
    keyEnter = (257, "enter")
    keyTab = (258, "tab")
    keyBackspace = (259, "backspace")
    keyInsert = (260, "insert")
    keyDelete = (261, "delete")
    keyRight = (262, "right")
    keyLeft = (263, "left")
    keyDown = (264, "down")
    keyUp = (265, "up")
    keyPageUp = (266, "page up")
    keyPageDown = (267, "page down")
    keyHome = (268, "home")
    keyEnd = (269, "end")
    keyCapsLock = (280, "caps lock")
    keyScrollLock = (281, "scroll lock")
    keyNumLock = (282, "num lock")
    keyPrintScreen = (283, "print screen")
    keyPause = (284, "pause")
    keyF1 = (290, "f1")
    keyF2 = (291, "f2")
    keyF3 = (292, "f3")
    keyF4 = (293, "f4")
    keyF5 = (294, "f5")
    keyF6 = (295, "f6")
    keyF7 = (296, "f7")
    keyF8 = (297, "f8")
    keyF9 = (298, "f9")
    keyF10 = (299, "f10")
    keyF11 = (300, "f11")
    keyF12 = (301, "f12")
    keyF13 = (302, "f13")
    keyF14 = (303, "f14")
    keyF15 = (304, "f15")
    keyF16 = (305, "f16")
    keyF17 = (306, "f17")
    keyF18 = (307, "f18")
    keyF19 = (308, "f19")
    keyF20 = (309, "f20")
    keyF21 = (310, "f21")
    keyF22 = (311, "f22")
    keyF23 = (312, "f23")
    keyF24 = (313, "f24")
    keyF25 = (314, "f25")
    keyKp0 = (320, "kp0")
    keyKp1 = (321, "kp1")
    keyKp2 = (322, "kp2")
    keyKp3 = (323, "kp3")
    keyKp4 = (324, "kp4")
    keyKp5 = (325, "kp5")
    keyKp6 = (326, "kp6")
    keyKp7 = (327, "kp7")
    keyKp8 = (328, "kp8")
    keyKp9 = (329, "kp9")
    keyKpDecimal = (330, "kp decimal")
    keyKpDivide = (331, "kp divide")
    keyKpMultiply = (332, "kp multiply")
    keyKpSubtract = (333, "kp subtract")
    keyKpAdd = (334, "kp add")
    keyKpEnter = (335, "kp enter")
    keyKpEqual = (336, "kp equal")
    keyLeftShift = (340, "left shift")
    keyLeftControl = (341, "left control")
    keyLeftAlt = (342, "left alt")
    keyLeftSuper = (343, "left super")
    keyRightShift = (344, "right shift")
    keyRightControl = (345, "right control")
    keyRightAlt = (346, "right alt")
    keyRightSuper = (347, "right super")
    keyMenu = (348, "menu")

  KeyAction* {.size: int32.sizeof.} = enum
    kaUp = (0, "up")
    kaDown = (1, "down")
    kaRepeat = (2, "repeat")

  CursorShape* {.size: int32.sizeof.} = enum
    csArrow = 0x00036001
    csIBeam = 0x00036002
    csCrosshair = 0x00036003
    csHand = 0x00036004
    csResizeEW = 0x00036005
    csResizeNS = 0x00036006
    csResizeNWSE = 0x00036007
    csResizeNESW = 0x00036008
    csResizeAll = 0x00036009
    csNotAllowed = 0x0003600a

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
    prevActiveSlotParent*: int32
    prevActiveSlotUsed*: bool
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
    lpkAttach

  LayoutFollowerKind* = enum
    lfkVerticalScrollBar
    lfkHorizontalScrollBar
    lfkMatchTarget
    lfkDropdownPopup
    lfkInsetFixed

  LayoutAttachPoint* = enum
    lapTopLeft
    lapTopCenter
    lapTopRight
    lapCenterLeft
    lapCenter
    lapCenterRight
    lapBottomLeft
    lapBottomCenter
    lapBottomRight

  LayoutAttachTarget* = enum
    latParent
    latRoot
    latNode

  LayoutAttach* = object
    targetKind*: LayoutAttachTarget
    targetNode*: LayoutNodeId
    targetPoint*: LayoutAttachPoint
    selfPoint*: LayoutAttachPoint
    offset*: Size
    windowPad*: float
    clipToRoot*: bool
    zIndex*: int
    capturePointer*: bool

  LayoutPlacement* = object
    case kind*: LayoutPlacementKind
    of lpkFlow:
      discard
    of lpkManual:
      x*, y*: float
    of lpkFollow:
      target*: LayoutNodeId
      followKind*: LayoutFollowerKind
      followAlign*: HorizontalAlign
      followInset*: Padding
      windowPad*: float
    of lpkAttach:
      attach*: LayoutAttach

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
    aspectRatio*: float
    intrinsicMin*: Size
    intrinsicPref*: Size
    rect*: Rect
    contentSize*: Size
    scrollOffset*: Size
    text*: string
    fontSize*: float
    fontFace*: string

  LayoutErrorKind* = enum
    lekDuplicateItemId
    lekInvalidPercent
    lekMissingAttachTarget
    lekExceededMaxNodes
    lekUnbalancedLayoutStack
    lekInternal

  LayoutError* = object
    kind*: LayoutErrorKind
    itemId*: ItemId
    nodeId*: LayoutNodeId
    message*: string

  LayoutErrorHandler* = proc(error: LayoutError) {.closure.}

  LayoutArena* = object
    nodes*: seq[LayoutNode]
    childIndices*: seq[LayoutNodeId]
    childLists*: seq[seq[LayoutNodeId]]
    nodeStack*: seq[LayoutNodeId]
    measureText*: MeasureTextProc
    errors*: seq[LayoutError]
    errorHandler*: LayoutErrorHandler
    maxNodes*: int
    seenItemIds*: seq[ItemId]

  LayoutSlot* = object
    itemId*: ItemId
    nodeId*: LayoutNodeId
    bounds*: Rect
    previousBounds*: Rect

  LayoutInspectorTreeRow* = object
    nodeId*: LayoutNodeId
    depth*: int
    label*: string
    hasChildren*: bool
    collapsed*: bool
    selected*: bool
    hovered*: bool
    errorCount*: int
    collapseKey*: string

  LayoutDebugState* = object
    enabled*: bool
    hoveredNode*: LayoutNodeId
    selectedNode*: LayoutNodeId
    panelWidth*: float
    treeScroll*: float
    treeHoveredNode*: LayoutNodeId
    collapsedNodes*: seq[string]

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
    savedHitClip*: Rect
    savedFocusCaptured*: bool
    capturePointer*: bool

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

type TooltipStyle* = ref object
  fontSize*: float
  fontFace*: string
  lineHeight*: float
  padX*: float
  padY*: float
  maxWidth*: float
  cornerRadius*: float
  backgroundColor*: Color
  textColor*: Color
  shadow*: ShadowStyle

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
  commitOnPress*: bool

type ProgressStyle* = ref object
  cornerRadius*: float
  strokeWidth*: float
  strokeColor*: Color
  strokeColorDisabled*: Color
  fillColor*: Color
  fillColorDisabled*: Color
  valueColor*: Color
  valueColorDisabled*: Color
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
  presetColors*: seq[Color]
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
