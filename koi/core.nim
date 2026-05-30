import std/tables
import std/times

when not defined(waylandBackend):
  from glfw as glfwLib import nil
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

type
  PlatformCursorMode* = enum
    pcmNormal
    pcmHidden
    pcmDisabled

  PlatformWindowSizeProc* = proc(): tuple[w, h: float]
  PlatformSurfaceSizeProc* = proc(): tuple[w, h: float]
  PlatformContentScaleProc* = proc(): tuple[x, y: float]
  PlatformCursorPosProc* = proc(): tuple[x, y: float]
  PlatformSetCursorPosProc* = proc(x, y: float)
  PlatformSetCursorShapeProc* = proc(shape: CursorShape)
  PlatformSetCursorModeProc* = proc(mode: PlatformCursorMode)
  PlatformClipboardGetProc* = proc(): string
  PlatformClipboardSetProc* = proc(text: string)

  PlatformHooks* = object
    windowSize*: PlatformWindowSizeProc
    surfaceSize*: PlatformSurfaceSizeProc
    contentScale*: PlatformContentScaleProc
    cursorPos*: PlatformCursorPosProc
    setCursorPos*: PlatformSetCursorPosProc
    setCursorShape*: PlatformSetCursorShapeProc
    setCursorMode*: PlatformSetCursorModeProc
    clipboardGet*: PlatformClipboardGetProc
    clipboardSet*: PlatformClipboardSetProc

var
  g_nvgContext*: NVGContext
  g_uiState*: UIState
  g_window*: Window
  g_platformHooks*: PlatformHooks

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

proc setPlatformHooks*(hooks: PlatformHooks) =
  g_platformHooks = hooks

proc platformWindowSize*(): tuple[w, h: float] =
  if g_platformHooks.windowSize != nil:
    g_platformHooks.windowSize()
  else:
    (0.0, 0.0)

proc platformSurfaceSize*(): tuple[w, h: float] =
  if g_platformHooks.surfaceSize != nil:
    g_platformHooks.surfaceSize()
  else:
    platformWindowSize()

proc platformContentScale*(): tuple[x, y: float] =
  if g_platformHooks.contentScale != nil:
    g_platformHooks.contentScale()
  else:
    (1.0, 1.0)

proc platformCursorPos*(): tuple[x, y: float] =
  if g_platformHooks.cursorPos != nil:
    g_platformHooks.cursorPos()
  else:
    (g_uiState.mx, g_uiState.my)

proc platformSetCursorPos*(x, y: float) =
  if g_platformHooks.setCursorPos != nil:
    g_platformHooks.setCursorPos(x, y)

proc platformSetCursorShape*(shape: CursorShape) =
  if g_platformHooks.setCursorShape != nil:
    g_platformHooks.setCursorShape(shape)

proc platformSetCursorMode*(mode: PlatformCursorMode) =
  if g_platformHooks.setCursorMode != nil:
    g_platformHooks.setCursorMode(mode)

proc platformClipboardGet*(): string =
  if g_platformHooks.clipboardGet != nil:
    g_platformHooks.clipboardGet()
  else:
    ""

proc platformClipboardSet*(text: string) =
  if g_platformHooks.clipboardSet != nil:
    g_platformHooks.clipboardSet(text)

proc initCore*(vg: NVGContext, glfwGetProcAddress: proc) =
  when not defined(koiWebGpu):
    if not gladLoadGL(glfwGetProcAddress):
      quit "Error initialising OpenGL"

  g_nvgContext = vg

  when not defined(waylandBackend):
    g_cursorArrow = glfwLib.createStandardCursor(glfwLib.CursorShape(ord(csArrow)))
    g_cursorIBeam = glfwLib.createStandardCursor(glfwLib.CursorShape(ord(csIBeam)))
    g_cursorCrosshair =
      glfwLib.createStandardCursor(glfwLib.CursorShape(ord(csCrosshair)))
    g_cursorHand = glfwLib.createStandardCursor(glfwLib.CursorShape(ord(csHand)))
    g_cursorResizeEW =
      glfwLib.createStandardCursor(glfwLib.CursorShape(ord(csResizeEW)))
    g_cursorResizeNS =
      glfwLib.createStandardCursor(glfwLib.CursorShape(ord(csResizeNS)))
    g_cursorResizeNWSE =
      glfwLib.createStandardCursor(glfwLib.CursorShape(ord(csResizeNWSE)))
    g_cursorResizeNESW =
      glfwLib.createStandardCursor(glfwLib.CursorShape(ord(csResizeNESW)))
    g_cursorResizeAll =
      glfwLib.createStandardCursor(glfwLib.CursorShape(ord(csResizeAll)))

  g_eventBuf = initRingBuffer[Event](64)
  scale(1.0)
  requestFrames()

proc deinitCore*() =
  when not defined(waylandBackend):
    glfwLib.destroyCursor(g_cursorArrow)
    glfwLib.destroyCursor(g_cursorIBeam)
    glfwLib.destroyCursor(g_cursorCrosshair)
    glfwLib.destroyCursor(g_cursorHand)
    glfwLib.destroyCursor(g_cursorResizeEW)
    glfwLib.destroyCursor(g_cursorResizeNS)
    glfwLib.destroyCursor(g_cursorResizeNWSE)
    glfwLib.destroyCursor(g_cursorResizeNESW)
    glfwLib.destroyCursor(g_cursorResizeAll)
