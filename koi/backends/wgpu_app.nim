import std/os

import glfw
import nanovg

import koi
import koi/backends/wgpu_renderer

{.push warning[HoleEnumConv]: off.}

when defined(waylandBackend):
  import std/unicode

  import koi/backends/wayland
  import koi/backends/wayland_wgpu
else:
  import std/options

  import koi/backends/glfw_wgpu

type
  KoiWgpuAppConfig* = object
    title*: string
    width*: int
    height*: int
    resizable*: bool

  KoiWgpuRenderProc* = proc(vg: NVGContext) {.closure.}

proc defaultKoiWgpuAppConfig*(
    title: string, width = 900, height = 600
): KoiWgpuAppConfig =
  KoiWgpuAppConfig(title: title, width: width, height: height, resizable: true)

proc loadDefaultKoiFonts*(vg: NVGContext) =
  let dataDir = currentSourcePath().parentDir().parentDir().parentDir() / "data"

  let regular = vg.createFont("sans", dataDir / "Roboto-Regular.ttf")
  if regular == NoFont:
    quit "Could not load regular font."

  let bold = vg.createFont("sans-bold", dataDir / "Roboto-Bold.ttf")
  if bold == NoFont:
    quit "Could not load bold font."

when defined(waylandBackend):
  type WaylandAppState = object
    closed: bool
    width: float
    height: float
    surfaceWidth: uint32
    surfaceHeight: uint32
    scale: float
    mouseX: float
    mouseY: float
    clipboard: string
    window: ptr KoiWaylandWindow

  var gWaylandApp: ptr WaylandAppState

  proc waylandMods(mods: uint32): set[ModifierKey] =
    if (mods and koiWaylandModShift) != 0:
      result.incl(mkShift)
    if (mods and koiWaylandModCtrl) != 0:
      result.incl(mkCtrl)
    if (mods and koiWaylandModAlt) != 0:
      result.incl(mkAlt)
    if (mods and koiWaylandModSuper) != 0:
      result.incl(mkSuper)

  proc waylandMouseButton(button: uint32): MouseButton =
    case button
    of 0x110, 0: mbLeft
    of 0x111, 1: mbRight
    of 0x112, 2: mbMiddle
    of 0x113, 3: mb4
    of 0x114, 4: mb5
    else: mbLeft

  proc waylandKey(sym: uint32): Key =
    if sym >= uint32(ord('a')) and sym <= uint32(ord('z')):
      return Key(sym - 32)
    if sym >= uint32(ord('A')) and sym <= uint32(ord('Z')):
      return Key(sym)
    if sym >= uint32(ord('0')) and sym <= uint32(ord('9')):
      return Key(sym)
    case sym
    of 0x20:
      keySpace
    of 0x27:
      keyApostrophe
    of 0x2c:
      keyComma
    of 0x2d:
      keyMinus
    of 0x2e:
      keyPeriod
    of 0x2f:
      keySlash
    of 0x3b:
      keySemicolon
    of 0x3d:
      keyEqual
    of 0x5b:
      keyLeftBracket
    of 0x5c:
      keyBackslash
    of 0x5d:
      keyRightBracket
    of 0x60:
      keyGraveAccent
    of 0xff1b:
      keyEscape
    of 0xff0d:
      keyEnter
    of 0xff09:
      keyTab
    of 0xff08:
      keyBackspace
    of 0xff63:
      keyInsert
    of 0xffff:
      keyDelete
    of 0xff53:
      keyRight
    of 0xff51:
      keyLeft
    of 0xff54:
      keyDown
    of 0xff52:
      keyUp
    of 0xff55:
      keyPageUp
    of 0xff56:
      keyPageDown
    of 0xff50:
      keyHome
    of 0xff57:
      keyEnd
    of 0xffe5:
      keyCapsLock
    of 0xff7f:
      keyNumLock
    of 0xff61:
      keyPrintScreen
    of 0xff13:
      keyPause
    of 0xffbe .. 0xffd6:
      Key(uint32(keyF1) + (sym - 0xffbe))
    of 0xffb0 .. 0xffb9:
      Key(uint32(keyKp0) + (sym - 0xffb0))
    of 0xffae:
      keyKpDecimal
    of 0xffaf:
      keyKpDivide
    of 0xffaa:
      keyKpMultiply
    of 0xffad:
      keyKpSubtract
    of 0xffab:
      keyKpAdd
    of 0xff8d:
      keyKpEnter
    of 0xffbd:
      keyKpEqual
    of 0xffe1:
      keyLeftShift
    of 0xffe2:
      keyRightShift
    of 0xffe3:
      keyLeftControl
    of 0xffe4:
      keyRightControl
    of 0xffe9:
      keyLeftAlt
    of 0xffea:
      keyRightAlt
    of 0xffeb:
      keyLeftSuper
    of 0xffec:
      keyRightSuper
    else:
      keyUnknown

  proc waylandCursorShape(shape: CursorShape): KoiWaylandCursorShape =
    case shape
    of csIBeam: kwcText
    of csCrosshair: kwcCrosshair
    of csHand: kwcPointer
    of csResizeEW: kwcResizeEW
    of csResizeNS: kwcResizeNS
    of csResizeNWSE: kwcResizeNWSE
    of csResizeNESW: kwcResizeNESW
    of csResizeAll: kwcResizeAll
    else: kwcDefault

  proc onClose(userdata: pointer) {.cdecl.} =
    let state = cast[ptr WaylandAppState](userdata)
    if state != nil:
      state.closed = true

  proc onResize(w, h: uint32, userdata: pointer) {.cdecl.} =
    let state = cast[ptr WaylandAppState](userdata)
    if state != nil:
      state.width = w.float
      state.height = h.float
      state.surfaceWidth = w
      state.surfaceHeight = h

  proc onKeyDown(sym, mods: uint32, userdata: pointer) {.cdecl.} =
    queueKeyEvent(waylandKey(sym), kaDown, waylandMods(mods))

  proc onKeyRepeat(sym, mods: uint32, userdata: pointer) {.cdecl.} =
    queueKeyEvent(waylandKey(sym), kaRepeat, waylandMods(mods))

  proc onKeyUp(sym, mods: uint32, userdata: pointer) {.cdecl.} =
    queueKeyEvent(waylandKey(sym), kaUp, waylandMods(mods))

  proc onChar(codepoint: uint32, userdata: pointer) {.cdecl.} =
    if codepoint >= 32 and codepoint != 127:
      queueChar(Rune(codepoint))

  proc onMouseMove(x, y: cdouble, userdata: pointer) {.cdecl.} =
    let state = cast[ptr WaylandAppState](userdata)
    if state != nil:
      state.mouseX = x.float
      state.mouseY = y.float
    queueMouseMove(x.float, y.float)

  proc onMouseButton(btn: uint32, pressed: bool, userdata: pointer) {.cdecl.} =
    let state = cast[ptr WaylandAppState](userdata)
    if state != nil:
      queueMouseButtonEvent(
        waylandMouseButton(btn), pressed, state.mouseX, state.mouseY, {}
      )

  proc onScroll(dx, dy: cdouble, userdata: pointer) {.cdecl.} =
    queueScrollEvent(-dx / 10.0, -dy / 10.0)

  proc onScale(scale: cdouble, userdata: pointer) {.cdecl.} =
    let state = cast[ptr WaylandAppState](userdata)
    if state != nil:
      state.scale = max(1.0, scale.float)

  proc installWaylandPlatformHooks(state: ptr WaylandAppState) =
    gWaylandApp = state
    setPlatformHooks(
      PlatformHooks(
        windowSize: proc(): tuple[w, h: float] =
          (gWaylandApp.width, gWaylandApp.height),
        surfaceSize: proc(): tuple[w, h: float] =
          (gWaylandApp.surfaceWidth.float, gWaylandApp.surfaceHeight.float),
        contentScale: proc(): tuple[x, y: float] =
          (gWaylandApp.scale, gWaylandApp.scale),
        cursorPos: proc(): tuple[x, y: float] =
          (gWaylandApp.mouseX, gWaylandApp.mouseY),
        setCursorPos: proc(x, y: float) =
          discard,
        setCursorShape: proc(shape: CursorShape) =
          if gWaylandApp.window != nil:
            koiWaylandSetCursorShape(gWaylandApp.window, waylandCursorShape(shape))
        ,
        setCursorMode: proc(mode: PlatformCursorMode) =
          discard,
        clipboardGet: proc(): string =
          gWaylandApp.clipboard,
        clipboardSet: proc(text: string) =
          gWaylandApp.clipboard = text,
      )
    )

  proc noGlfwProcAddress() =
    discard

  proc runKoiWgpuApp*(config: KoiWgpuAppConfig, render: KoiWgpuRenderProc) =
    var state = WaylandAppState(
      closed: false,
      width: config.width.float,
      height: config.height.float,
      surfaceWidth: config.width.uint32,
      surfaceHeight: config.height.uint32,
      scale: 1.0,
    )
    var callbacks = KoiWaylandCallbacks(
      onClose: onClose,
      onResize: onResize,
      onKeyDown: onKeyDown,
      onKeyRepeat: onKeyRepeat,
      onKeyUp: onKeyUp,
      onChar: onChar,
      onMouseMove: onMouseMove,
      onMouseButton: onMouseButton,
      onScroll: onScroll,
      onScale: onScale,
      userdata: addr state,
    )

    let display = koiWaylandInit()
    if display == nil:
      quit "No Wayland display available for native Wayland backend."

    let title = config.title.cstring
    let window =
      koiWaylandCreateWindow(display, state.surfaceWidth, state.surfaceHeight, title)
    if window == nil:
      koiWaylandDestroy(display)
      quit "Could not create native Wayland window."

    state.window = window
    koiWaylandSetCallbacks(window, addr callbacks)
    koiWaylandSetCursorShape(window, kwcDefault)
    installWaylandPlatformHooks(addr state)

    var backend: KoiWgpuBackend
    let (surfaceW, surfaceH) = surfaceSize(window)
    state.surfaceWidth = surfaceW
    state.surfaceHeight = surfaceH
    state.width = surfaceW.float
    state.height = surfaceH.float

    backend.initKoiWgpuBackendWithSurface(
      wgpuSurfaceHandle(display, window), surfaceW, surfaceH
    )
    let vg = backend.createNanoVgContext({nifAntialias})
    init(vg, noGlfwProcAddress)
    loadDefaultKoiFonts(vg)

    while not state.closed and not koiWaylandWindowShouldClose(window):
      koiWaylandPollEvents(display)
      let (width, height) = surfaceSize(window)
      state.surfaceWidth = width
      state.surfaceHeight = height
      state.width = width.float
      state.height = height.float
      backend.resizeKoiWgpuBackend(width, height)
      render(vg)

    deinit()
    deleteNanoVgContext(vg)
    koiWaylandDestroyWindow(window)
    koiWaylandDestroy(display)

else:
  proc createWgpuWindow(config: KoiWgpuAppConfig): Window =
    var cfg = defaultWgpuWindowConfig(config.title, config.width, config.height)
    cfg.size = (w: config.width, h: config.height)
    cfg.title = config.title
    cfg.resizable = config.resizable
    cfg.visible = true
    cfg.bits = (
      r: 8'i32.some,
      g: 8'i32.some,
      b: 8'i32.some,
      a: 8'i32.some,
      stencil: 8'i32.some,
      depth: 16'i32.some,
    )
    newWgpuWindow(cfg)

  proc runKoiWgpuApp*(config: KoiWgpuAppConfig, render: KoiWgpuRenderProc) =
    glfw.initialize()
    let win = createWgpuWindow(config)
    useWindow(win)

    let (initialWidth, initialHeight) = win.surfaceSize()

    var backend: KoiWgpuBackend
    backend.initKoiWgpuBackendWithSurface(
      win.wgpuSurfaceHandle(), initialWidth.uint32, initialHeight.uint32
    )
    let vg = backend.createNanoVgContext({nifAntialias})
    init(vg, glfw.getProcAddress)
    loadDefaultKoiFonts(vg)

    while not win.shouldClose:
      glfw.pollEvents()
      let (surfaceWidth, surfaceHeight) = win.surfaceSize()
      backend.resizeKoiWgpuBackend(surfaceWidth, surfaceHeight)
      render(vg)

    deinit()
    deleteNanoVgContext(vg)
    win.destroy()
    glfw.terminate()

{.pop.}
