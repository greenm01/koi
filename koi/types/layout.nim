type
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
