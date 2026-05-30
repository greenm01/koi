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
