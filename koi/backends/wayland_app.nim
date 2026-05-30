import std/unicode

import koi
import koi/backends/wayland
import koi/backends/wayland_wgpu

export wayland
export wayland_wgpu

{.push warning[HoleEnumConv]: off.}

type KoiWaylandApp* = ref object
  closed*: bool
  visible*: bool
  focused*: bool
  iconified*: bool
  title*: string
  pos*: tuple[x, y: int]
  width*: float
  height*: float
  surfaceWidth*: uint32
  surfaceHeight*: uint32
  scale*: float
  mouseX*: float
  mouseY*: float
  clipboard*: string
  display*: ptr KoiWaylandDisplay
  window*: ptr KoiWaylandWindow
  callbacks: KoiWaylandCallbacks

var gWaylandApp: KoiWaylandApp

proc waylandMods*(mods: uint32): set[ModifierKey] =
  if (mods and koiWaylandModShift) != 0:
    result.incl(mkShift)
  if (mods and koiWaylandModCtrl) != 0:
    result.incl(mkCtrl)
  if (mods and koiWaylandModAlt) != 0:
    result.incl(mkAlt)
  if (mods and koiWaylandModSuper) != 0:
    result.incl(mkSuper)

proc waylandMouseButton*(button: uint32): MouseButton =
  case button
  of 0x110, 0: mbLeft
  of 0x111, 1: mbRight
  of 0x112, 2: mbMiddle
  of 0x113, 3: mb4
  of 0x114, 4: mb5
  else: mbLeft

proc waylandKey*(sym: uint32): Key =
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

proc waylandCursorShape*(shape: CursorShape): KoiWaylandCursorShape =
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
  let app = cast[KoiWaylandApp](userdata)
  if app != nil:
    app.closed = true

proc onResize(w, h: uint32, userdata: pointer) {.cdecl.} =
  let app = cast[KoiWaylandApp](userdata)
  if app != nil:
    app.width = w.float
    app.height = h.float
    app.surfaceWidth = w
    app.surfaceHeight = h

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
  let app = cast[KoiWaylandApp](userdata)
  if app != nil:
    app.mouseX = x.float
    app.mouseY = y.float
  queueMouseMove(x.float, y.float)

proc onMouseButton(btn: uint32, pressed: bool, userdata: pointer) {.cdecl.} =
  let app = cast[KoiWaylandApp](userdata)
  if app != nil:
    queueMouseButtonEvent(waylandMouseButton(btn), pressed, app.mouseX, app.mouseY, {})

proc onScroll(dx, dy: cdouble, userdata: pointer) {.cdecl.} =
  queueScrollEvent(-dx / 10.0, -dy / 10.0)

proc onScale(scale: cdouble, userdata: pointer) {.cdecl.} =
  let app = cast[KoiWaylandApp](userdata)
  if app != nil:
    app.scale = max(1.0, scale.float)

proc installWaylandPlatformHooks*(app: KoiWaylandApp) =
  gWaylandApp = app
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

proc noGlfwProcAddress*() =
  discard

proc newKoiWaylandApp*(title: string, width, height: int): KoiWaylandApp =
  result = KoiWaylandApp(
    closed: false,
    visible: true,
    focused: true,
    iconified: false,
    title: title,
    pos: (x: 0, y: 0),
    width: width.float,
    height: height.float,
    surfaceWidth: width.uint32,
    surfaceHeight: height.uint32,
    scale: 1.0,
  )
  result.callbacks = KoiWaylandCallbacks(
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
    userdata: cast[pointer](result),
  )

  result.display = koiWaylandInit()
  if result.display == nil:
    quit "No Wayland display available for native Wayland backend."

  result.window = koiWaylandCreateWindow(
    result.display, result.surfaceWidth, result.surfaceHeight, title
  )
  if result.window == nil:
    koiWaylandDestroy(result.display)
    quit "Could not create native Wayland window."

  koiWaylandSetCallbacks(result.window, addr result.callbacks)
  koiWaylandSetCursorShape(result.window, kwcDefault)
  installWaylandPlatformHooks(result)

proc updateSurfaceSize*(app: KoiWaylandApp) =
  let (width, height) = surfaceSize(app.window)
  app.surfaceWidth = width
  app.surfaceHeight = height
  app.width = width.float
  app.height = height.float

proc shouldClose*(app: KoiWaylandApp): bool =
  app.closed or koiWaylandWindowShouldClose(app.window)

proc `shouldClose=`*(app: KoiWaylandApp, closed: bool) =
  app.closed = closed

proc pollEvents*(app: KoiWaylandApp) =
  koiWaylandPollEvents(app.display)

proc waitEvents*(app: KoiWaylandApp) =
  app.pollEvents()

proc surfaceHandle*(app: KoiWaylandApp): KoiWgpuSurfaceHandle =
  wgpuSurfaceHandle(app.display, app.window)

proc wgpuSurfaceHandle*(app: KoiWaylandApp): KoiWgpuSurfaceHandle =
  app.surfaceHandle()

proc surfaceSize*(app: KoiWaylandApp): tuple[width, height: uint32] =
  (app.surfaceWidth, app.surfaceHeight)

proc framebufferSize*(app: KoiWaylandApp): tuple[w, h: int] =
  (app.surfaceWidth.int, app.surfaceHeight.int)

proc size*(app: KoiWaylandApp): tuple[w, h: int] =
  (app.width.int, app.height.int)

proc `size=`*(app: KoiWaylandApp, size: tuple[w, h: int]) =
  app.width = size.w.float
  app.height = size.h.float
  app.surfaceWidth = size.w.uint32
  app.surfaceHeight = size.h.uint32
  if app.window != nil:
    koiWaylandSetSize(app.window, app.surfaceWidth, app.surfaceHeight)

proc contentScale*(app: KoiWaylandApp): tuple[xScale, yScale: float] =
  (app.scale, app.scale)

proc cursorPos*(app: KoiWaylandApp): tuple[x, y: float64] =
  (app.mouseX.float64, app.mouseY.float64)

proc `title=`*(app: KoiWaylandApp, title: string) =
  app.title = title
  if app.window != nil:
    koiWaylandSetTitle(app.window, title)

proc show*(app: KoiWaylandApp) =
  app.visible = true

proc hide*(app: KoiWaylandApp) =
  app.visible = false

proc focus*(app: KoiWaylandApp) =
  app.focused = true

proc requestAttention*(app: KoiWaylandApp) =
  discard

proc restore*(app: KoiWaylandApp) =
  discard

proc iconify*(app: KoiWaylandApp) =
  discard

proc isKeyDown*(app: KoiWaylandApp, key: Key): bool =
  discard app
  koi.isKeyDown(key)

proc mouseButtonDown*(app: KoiWaylandApp, button: MouseButton): bool =
  discard app
  case button
  of mbLeft:
    koi.mbLeftDown()
  of mbRight:
    koi.mbRightDown()
  of mbMiddle:
    koi.mbMiddleDown()
  else:
    false

proc destroy*(app: KoiWaylandApp) =
  if app.window != nil:
    koiWaylandDestroyWindow(app.window)
    app.window = nil
  if app.display != nil:
    koiWaylandDestroy(app.display)
    app.display = nil
  if gWaylandApp == app:
    gWaylandApp = nil

{.pop.}
