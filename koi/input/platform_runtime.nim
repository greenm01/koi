proc showCursor*() =
  platformSetCursorMode(pcmNormal)

proc hideCursor*() =
  platformSetCursorMode(pcmHidden)

proc disableCursor*() =
  platformSetCursorMode(pcmDisabled)

proc cursorShape*(cs: CursorShape) =
  g_uiState.cursorShape = cs

proc setCursorShape*(cs: CursorShape) =
  cursorShape(cs)

proc applyCursorShape*(cs: CursorShape) =
  platformSetCursorShape(cs)

proc setCursorMode*(cs: CursorShape) =
  applyCursorShape(cs)

proc cursorPosX*(x: float) =
  let (_, currY) = platformCursorPos()
  platformSetCursorPos(x * g_uiState.scale, currY)

proc setCursorPosX*(x: float) =
  cursorPosX(x)

proc cursorPosY*(y: float) =
  let (currX, _) = platformCursorPos()
  platformSetCursorPos(currX, y * g_uiState.scale)

proc setCursorPosY*(y: float) =
  cursorPosY(y)

const
  DoubleClickMaxDelay = 0.4
  DoubleClickMaxXOffs = 3.0
  DoubleClickMaxYOffs = 3.0

proc isDoubleClick*(): bool =
  alias(ui, g_uiState)

  ui.mbLeftDown and core.currentTime() - ui.lastMbLeftDownT <= DoubleClickMaxDelay and
    abs(ui.lastMbLeftDownX - ui.mx) <= DoubleClickMaxXOffs and
    abs(ui.lastMbLeftDownY - ui.my) <= DoubleClickMaxYOffs

proc useShortcuts*(sm: ShortcutMode) =
  alias(shortcuts, g_textFieldEditShortcuts)
  shortcuts = initTable[TextEditShortcuts, seq[KeyShortcut]]()
  for e in TextEditShortcuts:
    shortcuts[e] = @[]
  case sm
  of smWindows, smLinux:
    for k, v in g_textFieldEditShortcuts_WinLinux:
      shortcuts[k] = v
  of smMac:
    for k, v in g_textFieldEditShortcuts_Mac:
      shortcuts[k] = v

proc setShortcuts*(sm: ShortcutMode) =
  useShortcuts(sm)

proc toClipboard*(s: string) =
  platformClipboardSet(s)

proc fromClipboard*(): string =
  platformClipboardGet()

proc init*(vg: NVGContext, glfwGetProcAddress: proc) =
  initCore(vg, glfwGetProcAddress)

  when not defined(waylandBackend):
    installGlfwPlatformHooks()
    let win = activeWindow()
    win.keyCb = proc(
        win: Window,
        key: glfwLib.Key,
        scanCode: int32,
        action: glfwLib.KeyAction,
        mods: set[glfwLib.ModifierKey],
    ) =
      {.push warning[HoleEnumConv]: off.}
      keyCb(win, Key(ord(key)), scanCode, KeyAction(ord(action)), koiModifierKeys(mods))
      {.pop.}
    win.charCb = charCb
    win.mouseButtonCb = proc(
        win: Window,
        button: glfwLib.MouseButton,
        pressed: bool,
        mods: set[glfwLib.ModifierKey],
    ) =
      mouseButtonCb(win, MouseButton(ord(button)), pressed, koiModifierKeys(mods))
    win.scrollCb = scrollCb

  useShortcuts(smLinux)

  when not defined(koiWebGpu):
    when not defined(waylandBackend):
      glfwLib.swapInterval(1)

proc deinit*() =
  deinitCore()

proc handleTabActivation*(id: ItemId): bool =
  alias(tab, g_uiState.tabActivationState)
  if tab.activateNext:
    tab.activateNext = false
    result = true
  elif tab.activatePrev and id == tab.itemToActivate:
    tab.activatePrev = false
    result = true
