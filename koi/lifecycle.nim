import std/options
import std/math

import glfw
import nanovg
when not defined(koiWebGpu):
  import koi/glad/gl

import koi/utils
import koi/types
import koi/core
import koi/drawing
import koi/layout
import koi/input
import koi/defaults
import koi/ringbuffer
import koi/widgets/common
import koi/widgets/scrollbar
import koi/widgets/slider

proc beginFrame*() =
  alias(ui, g_uiState)
  alias(vg, g_nvgContext)

  let win = activeWindow()
  let (winWidth, winHeight) = win.size

  ui.winWidth = winWidth.float / g_uiState.scale
  ui.winHeight = winHeight.float / g_uiState.scale

  ui.drawOffsetStack = @[DrawOffset(ox: 0, oy: 0)]

  ui.currentLayer = layerDefault

  # Store mouse state
  ui.lastmx = ui.mx
  ui.lastmy = ui.my

  if ui.widgetMouseDrag:
    (ui.dx, ui.dy) = win.cursorPos()
    ui.dx /= g_uiState.scale
    ui.dy /= g_uiState.scale
  else:
    (ui.mx, ui.my) = win.cursorPos()
    ui.mx /= g_uiState.scale
    ui.my /= g_uiState.scale

  ui.hasEvent = false
  ui.eventHandled = false

  # Get next pending event from the queue
  if g_eventBuf.canRead():
    ui.currEvent = g_eventBuf.read().get
    ui.hasEvent = true
    let ev = ui.currEvent

    requestFrames()

    # Update current mouse button state
    if ev.kind == ekMouseButton:
      case ev.button
      of mbLeft:
        ui.mbLeftDown = ev.pressed
        ui.lastMbLeftDownX = ui.mbLeftDownX
        ui.lastMbLeftDownY = ui.mbLeftDownY
        ui.lastMbLeftDownT = ui.mbLeftDownT
        ui.mbLeftDownT = core.currentTime()
        ui.mbLeftDownX = ui.mx
        ui.mbLeftDownY = ui.my
      of mbRight:
        ui.mbRightDown = ev.pressed
      of mbMiddle:
        ui.mbMiddleDown = ev.pressed
      else:
        discard

  # Reset hot item
  ui.hotItem = 0

  # Reset hit area clipping
  resetHitClip()

  # Reset layout params
  ui.autoLayoutParams = DefaultAutoLayoutParams
  beginFrameLayout()

  # Clear all draw layers
  g_drawLayers.init()

  when not defined(koiWebGpu):
    # Render to FBO before starting the main frame
    if g_checkeredImage == NoImage:
      createCheckeredImage(vg)

    # Update and render
    let (fbWidth, fbHeight) = win.framebufferSize
    glViewport(0, 0, fbWidth.GLsizei, fbHeight.GLsizei)

    glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT or GL_STENCIL_BUFFER_BIT)

  vg.beginFrame(ui.winWidth, ui.winHeight, pxRatio())

proc endFrame*() =
  alias(ui, g_uiState)
  alias(vg, g_nvgContext)

  # Post-frame processing
  tooltipPost()

  applyCursorShape(ui.cursorShape)

  finishFrameLayout()

  g_drawLayers.draw(g_nvgContext)

  # Widget specific postprocessing
  scrollBarPost()
  sliderPost()

  # Active state reset
  if ui.mbLeftDown or ui.mbRightDown or ui.mbMiddleDown:
    if ui.activeItem == 0 and ui.hotItem == 0:
      ui.activeItem = -1
  else:
    if ui.activeItem != 0:
      ui.activeItem = 0

  # Decrement remaining frames counter
  if ui.framesLeft > 0:
    dec(ui.framesLeft)

  vg.endFrame()
