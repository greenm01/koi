const CharBufSize = 256
var
  g_charBuf*: array[CharBufSize, Rune]
  g_charBufIdx*: Natural

proc queueChar*(codePoint: Rune) =
  if g_charBufIdx <= g_charBuf.high:
    g_charBuf[g_charBufIdx] = codePoint
    inc(g_charBufIdx)

proc charCb*(win: Window, codePoint: Rune) =
  queueChar(codePoint)

proc clearCharBuf*() =
  g_charBufIdx = 0

proc charBufEmpty*(): bool =
  g_charBufIdx == 0

proc consumeCharBuf*(): string =
  for i in 0 ..< g_charBufIdx:
    result &= g_charBuf[i]
  clearCharBuf()

proc clearEventBuf*() =
  g_eventBuf.clear()

const ExcludedKeyEvents = {
  keyLeftShift, keyLeftControl, keyLeftAlt, keyLeftSuper, keyRightShift,
  keyRightControl, keyRightAlt, keyRightSuper, keyCapsLock, keyNumLock,
}

proc queueKeyEvent*(key: Key, action: KeyAction, mods: set[ModifierKey]) =
  alias(ui, g_uiState)
  let keyIdx = ord(key)
  if keyIdx >= 0 and keyIdx <= ui.keyStates.high:
    case action
    of kaDown, kaRepeat:
      ui.keyStates[keyIdx] = true
    of kaUp:
      ui.keyStates[keyIdx] = false

  if key notin ExcludedKeyEvents:
    let event = Event(kind: ekKey, key: key, action: action, mods: mods)
    discard g_eventBuf.write(event)

proc keyCb*(
    win: Window, key: Key, scanCode: int32, action: KeyAction, mods: set[ModifierKey]
) =
  queueKeyEvent(key, action, mods)

proc queueMouseMove*(x, y: float) =
  g_uiState.mx = x / g_uiState.scale
  g_uiState.my = y / g_uiState.scale

proc queueMouseButtonEvent*(
    button: MouseButton, pressed: bool, x, y: float, modKeys: set[ModifierKey]
) =
  queueMouseMove(x, y)
  discard g_eventBuf.write(
    Event(
      kind: ekMouseButton,
      button: button,
      pressed: pressed,
      x: x / g_uiState.scale,
      y: y / g_uiState.scale,
      mods: modKeys,
    )
  )

proc mouseButtonCb*(
    win: Window, button: MouseButton, pressed: bool, modKeys: set[ModifierKey]
) =
  let (x, y) = platformCursorPos()
  queueMouseButtonEvent(button, pressed, x.float, y.float, modKeys)

proc queueScrollEvent*(offsetX, offsetY: float64) =
  discard g_eventBuf.write(Event(kind: ekScroll, ox: offsetX, oy: offsetY))

proc scrollCb*(win: Window, offset: tuple[x, y: float64]) =
  queueScrollEvent(offset.x, offset.y)
