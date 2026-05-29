import std/tables
import std/times

import glfw
import nanovg
when not defined(koiWebGpu):
  import koi/glad/gl

import koi/rect
import koi/types
import koi/ringbuffer

type UIState* = object
  # General state
  # *************
  hasEvent*: bool
  currEvent*: Event
  eventHandled*: bool

  # Frames left to render; this is decremented in endFrame()
  framesLeft*: Natural

  # Scale factor
  scale*: float

  # This is the draw layer all widgets will draw on
  # TODO bit hacky, it's needed only for drawing the CSD decoration on top
  # of everything
  currentLayer*: DrawLayer

  # Window dimensions (in virtual pixels)
  winWidth*, winHeight*: float

  # Set if a widget has captured the focus (e.g., a textfield in edit mode)
  # so all other UI interactions (hovers, tooltips, etc.) should be disabled
  focusCaptured*: bool

  tooltipState*: TooltipStateVars

  # True if a dialog is currently open
  dialogOpen*: bool

  # Reset to empty seq at the start of the frame
  drawOffsetStack*: seq[DrawOffset]

  # Layout stack
  layoutStack*: seq[LayoutPresetFrame]
  layoutArena*: LayoutArena
  layoutRoot*: LayoutNodeId
  layoutRects*: Table[ItemId, Rect]
  layoutContentSizes*: Table[ItemId, Size]
  layoutDebug*: LayoutDebugState

  # Hit checking clip rectangle (e.g., when inside a scrollview)
  # TODO should dialog and popup use this as well? or instead of
  # focuscaptured?
  hitClipRect*: Rect
  oldHitClipRect*: Rect

  # Mouse state
  # -----------
  mx*, my*: float

  # When widgetMouseDrag is true, only dx and dy are updated instead
  # of mx and my
  widgetMouseDrag*: bool
  dx*, dy*: float

  # Mouse cursor position from the last frame
  lastmx*, lastmy*: float

  mbLeftDown*: bool
  mbRightDown*: bool
  mbMiddleDown*: bool

  # Time and position of the last left mouse button down event (for
  # double-click detenction)
  mbLeftDownT*: float
  mbLeftDownX*: float
  mbLeftDownY*: float

  lastMbLeftDownT*: float
  lastMbLeftDownX*: float
  lastMbLeftDownY*: float

  cursorShape*: CursorShape

  # Keyboard state
  # --------------
  keyStates*: array[ord(Key.high), bool]

  # Active & hot items
  # ------------------
  hotItem*: ItemId # reset at the start of the frame to 0
  activeItem*: ItemId

  # General purpose widget states
  # -----------------------------
  # For relative mouse movement calculations
  x0*, y0*: float

  # For delays & timeouts
  t0*: float

  # For keeping track of the cursor in hidden drag mode.
  # Dragging can be only active along the X or Y-axis, but not both:
  # - in horizontal drag mode: dragX >= 0, dragY  < 0
  # - in vertical drag mode:   dragX  < 0, dragY >= 0
  dragX*, dragY*: float

  # Widget-specific states
  # **********************

  # Global widget states (per widget type)
  colorPickerState*: ColorPickerStateVars
  dialogState*: DialogStateVars
  popupState*: PopupStateVars
  radioButtonState*: RadioButtonStateVars
  scrollBarState*: ScrollBarStateVars
  scrollViewState*: ScrollViewStateVars
  menuTraversalState*: MenuTraversalStateVars
  sectionHeaderState*: SectionHeaderStateVars
  sliderState*: SliderStateVars
  textFieldState*: TextFieldStateVars

  # Per-instance data storage for widgets that require it (e.g., ScrollView)
  itemState*: Table[ItemId, ref RootObj]

  # Auto-layout
  # ***********
  autoLayoutParams*: AutoLayoutParams
  autoLayoutState*: AutoLayoutStateVars

  # Tab-activation
  # **************
  tabActivationState*: TabActivationStateVars

var
  g_nvgContext*: NVGContext
  g_uiState*: UIState
  g_window*: Window

  g_cursorArrow*: Cursor
  g_cursorIBeam*: Cursor
  g_cursorCrosshair*: Cursor
  g_cursorHand*: Cursor
  g_cursorResizeEW*: Cursor
  g_cursorResizeNS*: Cursor
  g_cursorResizeNWSE*: Cursor
  g_cursorResizeNESW*: Cursor
  g_cursorResizeAll*: Cursor

  g_eventBuf*: RingBuffer[Event]

let
  HighlightColor* = rgb(1.0, 0.65, 0.0)
  HighlightLowColor* = rgb(0.9, 0.55, 0.0)

proc currentTime*(): float =
  times.epochTime()

proc getTime*(): float =
  currentTime()

proc winWidth*(): float =
  g_uiState.winWidth

proc winHeight*(): float =
  g_uiState.winHeight

proc isDialogOpen*(): bool =
  g_uiState.dialogOpen

proc focusCaptured*(): bool =
  g_uiState.focusCaptured

proc focusCaptured*(c: bool) =
  g_uiState.focusCaptured = c

proc setFocusCaptured*(c: bool) =
  focusCaptured(c)

proc requestFrames*(n: Natural = 5) =
  g_uiState.framesLeft = n

proc setFramesLeft*(n: Natural = 5) =
  requestFrames(n)

proc shouldRenderNextFrame*(): bool =
  g_uiState.framesLeft > 0

proc scale*(s: float) =
  g_uiState.scale = s

proc setScale*(s: float) =
  scale(s)

proc scale*(): float =
  g_uiState.scale

proc getScale*(): float =
  scale()

proc initCore*(vg: NVGContext, glfwGetProcAddress: proc) =
  when not defined(koiWebGpu):
    if not gladLoadGL(glfwGetProcAddress):
      quit "Error initialising OpenGL"

  g_nvgContext = vg

  g_cursorArrow = createStandardCursor(csArrow)
  g_cursorIBeam = createStandardCursor(csIBeam)
  g_cursorCrosshair = createStandardCursor(csCrosshair)
  g_cursorHand = createStandardCursor(csHand)
  g_cursorResizeEW = createStandardCursor(csResizeEW)
  g_cursorResizeNS = createStandardCursor(csResizeNS)
  g_cursorResizeNWSE = createStandardCursor(csResizeNWSE)
  g_cursorResizeNESW = createStandardCursor(csResizeNESW)
  g_cursorResizeAll = createStandardCursor(csResizeAll)

  g_eventBuf = initRingBuffer[Event](64)
  scale(1.0)
  requestFrames()

proc deinitCore*() =
  destroyCursor(g_cursorArrow)
  destroyCursor(g_cursorIBeam)
  destroyCursor(g_cursorCrosshair)
  destroyCursor(g_cursorHand)
  destroyCursor(g_cursorResizeEW)
  destroyCursor(g_cursorResizeNS)
  destroyCursor(g_cursorResizeNWSE)
  destroyCursor(g_cursorResizeNESW)
  destroyCursor(g_cursorResizeAll)
