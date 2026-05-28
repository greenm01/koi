import std/hashes
import std/math
import std/options
import std/strutils
import std/unicode
import std/tables

import glfw
import nanovg

import koi/utils
import koi/types
import koi/core
import koi/rect
import koi/ringbuffer

# Input handling: keyboard, mouse, shortcuts, and clipboard

func hashId*(id: string): ItemId =
  let hash32 = hash(id).uint32
  # Make sure the IDs are always positive integers
  let h = int64(hash32) - int32.low + 1
  assert h > 0
  h

func mkIdString*(filename: string, line: int, id: string): string =
  result = filename & ":" & $line & ":" & id

var g_nextIdString: string
var g_lastIdString: string

proc generateId*(filename: string, line: int, id: string = ""): ItemId =
  let idString = mkIdString(filename, line, id)
  g_lastIdString = idString
  hashId(idString)

proc getNextId*(filename: string, line: int, id: string = ""): ItemId =
  if g_nextIdString == "":
    result = generateId(filename, line, id)
  else:
    result = hashId(g_nextIdString)
    g_nextIdString = ""

proc lastIdString*(): string =
  g_lastIdString

proc setNextId*(id: string) =
  g_nextIdString = id

proc mouseInside*(x, y, w, h: float): bool =
  alias(ui, g_uiState)
  ui.mx >= x and ui.mx <= x + w and ui.my >= y and ui.my <= y + h

proc isHot*(id: ItemId): bool =
  g_uiState.hotItem == id

proc setHot*(id: ItemId) =
  alias(ui, g_uiState)
  ui.hotItem = id

proc isActive*(id: ItemId): bool =
  g_uiState.activeItem == id

proc setActive*(id: ItemId) =
  g_uiState.activeItem = id

proc hasHotItem*(): bool =
  g_uiState.hotItem > 0

proc hasNoActiveItem*(): bool =
  g_uiState.activeItem == 0

proc hasActiveItem*(): bool =
  g_uiState.activeItem > 0

proc setHitClip*(x, y, w, h: float) =
  alias(ui, g_uiState)
  ui.hitClipRect = rect(x, y, w, h)

proc resetHitClip*() =
  alias(ui, g_uiState)
  ui.hitClipRect = rect(0, 0, ui.winWidth, ui.winHeight)

proc isHit*(x, y, w, h: float): bool =
  alias(ui, g_uiState)
  let r = rect(x, y, w, h).intersect(ui.hitClipRect)
  if r.isSome:
    let r = r.get
    result = not ui.focusCaptured and mouseInside(r.x, r.y, r.w, r.h)
  else:
    result = false

proc mx*(): float =
  g_uiState.mx

proc my*(): float =
  g_uiState.my

proc lastMx*(): float =
  g_uiState.lastmx

proc lastMy*(): float =
  g_uiState.lastmy

proc hasEvent*(): bool =
  alias(ui, g_uiState)
  not ui.focusCaptured and ui.hasEvent and (not ui.eventHandled)

proc currEvent*(): Event =
  g_uiState.currEvent

proc eventHandled*(): bool =
  g_uiState.eventHandled

proc setEventHandled*() =
  g_uiState.eventHandled = true

proc mbLeftDown*(): bool =
  g_uiState.mbLeftDown

proc mbRightDown*(): bool =
  g_uiState.mbRightDown

proc mbMiddleDown*(): bool =
  g_uiState.mbMiddleDown

proc setWindow*(win: Window) =
  g_window = win

proc activeWindow*(): Window =
  if not g_window.isNil:
    g_window
  else:
    glfw.currentContext()

proc isKeyDown*(key: Key): bool =
  if key == keyUnknown:
    false
  else:
    g_uiState.keyStates[ord(key)]

proc shiftDown*(): bool =
  isKeyDown(keyLeftShift) or isKeyDown(keyRightShift)

proc altDown*(): bool =
  isKeyDown(keyLeftAlt) or isKeyDown(keyRightAlt)

proc ctrlDown*(): bool =
  isKeyDown(keyLeftControl) or isKeyDown(keyRightControl)

proc superDown*(): bool =
  isKeyDown(keyLeftSuper) or isKeyDown(keyRightSuper)

# Text editing

const NoSelection* = TextSelection(startPos: -1, endPos: 0)

func mkKeyShortcut*(k: Key, m: set[ModifierKey] = {}): KeyShortcut {.inline.} =
  var m = m - {mkCapsLock}

  if not (k >= keyKp0 and k <= keyKpDecimal):
    m = m - {mkNumLock}

  KeyShortcut(key: k, mods: m)

var g_textFieldEditShortcuts*: Table[TextEditShortcuts, seq[KeyShortcut]]

proc toClipboard*(s: string)
proc fromClipboard*(): string

func hasSelection*(sel: TextSelection): bool =
  sel.startPos > -1 and sel.startPos != sel.endPos

func normaliseSelection*(sel: TextSelection): TextSelection =
  if (sel.startPos < sel.endPos.int):
    TextSelection(startPos: sel.startPos, endPos: sel.endPos.Natural)
  else:
    TextSelection(startPos: sel.endPos.int, endPos: sel.startPos.Natural)

func updateSelection*(
    sel: TextSelection, cursorPos, newCursorPos: Natural
): TextSelection =
  var sel = sel
  if sel.startPos == -1:
    sel.startPos = cursorPos
    sel.endPos = cursorPos
  sel.endPos = newCursorPos
  result = sel

func isAlphanumeric*(r: Rune): bool =
  if r.isAlpha:
    return true
  let s = $r
  if s[0] == '_' or s[0].isDigit:
    return true

func findNextWordEnd*(text: string, cursorPos: Natural): Natural =
  var p = cursorPos
  while p < text.runeLen and text.runeAtPos(p).isAlphanumeric:
    inc(p)
  while p < text.runeLen and not text.runeAtPos(p).isAlphanumeric:
    inc(p)
  result = p

func findPrevWordStart*(text: string, cursorPos: Natural): Natural =
  var p = cursorPos
  while p > 0 and not text.runeAtPos(p - 1).isAlphanumeric:
    dec(p)
  while p > 0 and text.runeAtPos(p - 1).isAlphanumeric:
    dec(p)
  result = p

type TextEditResult* = object
  text*: string
  cursorPos*: Natural
  selection*: TextSelection

func insertString*(
    text: string,
    cursorPos: Natural,
    selection: TextSelection,
    toInsert: string,
    maxLen: Option[Natural],
): TextEditResult =
  let insertLen = toInsert.runeLen

  if insertLen > 0:
    let textLen = text.runeLen
    let toInsert =
      if maxLen.isSome and textLen + insertLen > maxLen.get:
        toInsert.runeSubStr(0, maxLen.get - textLen)
      else:
        toInsert

    if selection.startPos > -1 and selection.startPos != selection.endPos:
      let ns = normaliseSelection(selection)
      result.text =
        text.runeSubStr(0, ns.startPos) & toInsert & text.runeSubStr(ns.endPos)
      result.cursorPos = ns.startPos + toInsert.runeLen
    else:
      result.text = text

      let insertPos = cursorPos
      if insertPos == text.runeLen:
        result.text.add(toInsert)
      else:
        result.text.insert(toInsert, text.runeOffset(insertPos))
      result.cursorPos = cursorPos + toInsert.runeLen

    result.selection = NoSelection

func deleteSelection*(
    text: string, selection: TextSelection, cursorPos: Natural
): TextEditResult =
  let ns = normaliseSelection(selection)
  result.text = text.runeSubStr(0, ns.startPos) & text.runeSubStr(ns.endPos)
  result.cursorPos = ns.startPos
  result.selection = NoSelection

proc handleCommonTextEditingShortcuts*(
    sc: KeyShortcut,
    text: string,
    cursorPos: Natural,
    selection: TextSelection,
    maxLen: Option[Natural],
): Option[TextEditResult] =
  alias(shortcuts, g_textFieldEditShortcuts)

  var eventHandled = true

  var res: TextEditResult
  res.text = text
  res.cursorPos = cursorPos
  res.selection = selection

  # Cursor movement

  if sc in shortcuts[tesCursorOneCharLeft]:
    if hasSelection(selection):
      res.cursorPos = normaliseSelection(selection).startPos
      res.selection = NoSelection
    else:
      res.cursorPos = max(cursorPos - 1, 0)
  elif sc in shortcuts[tesCursorOneCharRight]:
    if hasSelection(selection):
      res.cursorPos = normaliseSelection(selection).endPos
      res.selection = NoSelection
    else:
      res.cursorPos = min(cursorPos + 1, text.runeLen)
  elif sc in shortcuts[tesCursorToPreviousWord]:
    res.cursorPos = findPrevWordStart(text, cursorPos)
    res.selection = NoSelection
  elif sc in shortcuts[tesCursorToNextWord]:
    res.cursorPos = findNextWordEnd(text, cursorPos)
    res.selection = NoSelection
  elif sc in shortcuts[tesCursorToDocumentStart]:
    res.cursorPos = 0
    res.selection = NoSelection
  elif sc in shortcuts[tesCursorToDocumentEnd]:
    res.cursorPos = text.runeLen
    res.selection = NoSelection

  # Selection
  elif sc in shortcuts[tesSelectionAll]:
    res.selection.startPos = 0
    res.selection.endPos = text.runeLen
    res.cursorPos = text.runeLen
  elif sc in shortcuts[tesSelectionOneCharLeft]:
    let newCursorPos = max(cursorPos - 1, 0)
    res.selection = updateSelection(selection, cursorPos, newCursorPos)
    res.cursorPos = newCursorPos
  elif sc in shortcuts[tesSelectionOneCharRight]:
    let newCursorPos = min(cursorPos + 1, text.runeLen)
    res.selection = updateSelection(selection, cursorPos, newCursorPos)
    res.cursorPos = newCursorPos
  elif sc in shortcuts[tesSelectionToPreviousWord]:
    let newCursorPos = findPrevWordStart(text, cursorPos)
    res.selection = updateSelection(selection, cursorPos, newCursorPos)
    res.cursorPos = newCursorPos
  elif sc in shortcuts[tesSelectionToNextWord]:
    let newCursorPos = findNextWordEnd(text, cursorPos)
    res.selection = updateSelection(selection, cursorPos, newCursorPos)
    res.cursorPos = newCursorPos
  elif sc in shortcuts[tesSelectionToDocumentStart]:
    let newCursorPos = 0
    res.selection = updateSelection(selection, cursorPos, newCursorPos)
    res.cursorPos = newCursorPos
  elif sc in shortcuts[tesSelectionToDocumentEnd]:
    let newCursorPos = text.runeLen
    res.selection = updateSelection(selection, cursorPos, newCursorPos)
    res.cursorPos = newCursorPos

  # Delete
  elif sc in shortcuts[tesDeleteOneCharLeft]:
    if hasSelection(selection):
      res = deleteSelection(text, selection, cursorPos)
    elif cursorPos > 0:
      res.text = text.runeSubStr(0, cursorPos - 1) & text.runeSubStr(cursorPos)
      res.cursorPos = cursorPos - 1
      res.selection = NoSelection
  elif sc in shortcuts[tesDeleteOneCharRight]:
    if hasSelection(selection):
      res = deleteSelection(text, selection, cursorPos)
    elif text.len > 0:
      res.text = text.runeSubStr(0, cursorPos) & text.runeSubStr(cursorPos + 1)
  elif sc in shortcuts[tesDeleteWordToRight]:
    if hasSelection(selection):
      res = deleteSelection(text, selection, cursorPos)
    else:
      let p = findNextWordEnd(text, cursorPos)
      res.text = text.runeSubStr(0, cursorPos) & text.runeSubStr(p)
  elif sc in shortcuts[tesDeleteWordToLeft]:
    if hasSelection(selection):
      res = deleteSelection(text, selection, cursorPos)
    else:
      let p = findPrevWordStart(text, cursorPos)
      res.text = text.runeSubStr(0, p) & text.runeSubStr(cursorPos)
      res.cursorPos = p

  # Clipboard
  elif sc in shortcuts[tesCutText]:
    if hasSelection(selection):
      let ns = normaliseSelection(selection)
      toClipboard(text.runeSubStr(ns.startPos, ns.endPos - ns.startPos))
      res = deleteSelection(text, selection, cursorPos)
  elif sc in shortcuts[tesCopyText]:
    if hasSelection(selection):
      let ns = normaliseSelection(selection)
      toClipboard(text.runeSubStr(ns.startPos, ns.endPos - ns.startPos))
  elif sc in shortcuts[tesPasteText]:
    try:
      let toInsert = fromClipboard()
      res = insertString(text, cursorPos, selection, toInsert, maxLen)
    except GLFWError:
      # attempting to retrieve non-text data raises an exception
      discard
  else:
    eventHandled = false

  result = if eventHandled: res.some else: TextEditResult.none

# Shortcut definitions

# Shortcut definitions - Windows/Linux

let g_textFieldEditShortcuts_WinLinux = {
  tesCursorOneCharLeft: @[mkKeyShortcut(keyLeft), mkKeyShortcut(keyKp4, {})],
  tesCursorOneCharRight: @[mkKeyShortcut(keyRight, {}), mkKeyShortcut(keyKp6, {})],
  tesCursorToPreviousWord:
    @[
      mkKeyShortcut(keyLeft, {mkCtrl}),
      mkKeyShortcut(keyKp4, {mkCtrl}),
      mkKeyShortcut(keySlash, {mkCtrl}),
    ],
  tesCursorToNextWord:
    @[mkKeyShortcut(keyRight, {mkCtrl}), mkKeyShortcut(keyKp6, {mkCtrl})],
  tesCursorToLineStart: @[mkKeyShortcut(keyHome, {}), mkKeyShortcut(keyKp7, {})],
  tesCursorToLineEnd: @[mkKeyShortcut(keyEnd, {}), mkKeyShortcut(keyKp1, {})],
  tesCursorToDocumentStart:
    @[mkKeyShortcut(keyHome, {mkCtrl}), mkKeyShortcut(keyKp7, {mkCtrl})],
  tesCursorToDocumentEnd:
    @[mkKeyShortcut(keyEnd, {mkCtrl}), mkKeyShortcut(keyKp1, {mkCtrl})],
  tesCursorToPreviousLine: @[mkKeyShortcut(keyUp, {}), mkKeyShortcut(keyKp8, {})],
  tesCursorToNextLine: @[mkKeyShortcut(keyDown, {}), mkKeyShortcut(keyKp2, {})],
  tesCursorPageUp: @[mkKeyShortcut(keyPageUp, {}), mkKeyShortcut(keyKp9, {})],
  tesCursorPageDown: @[mkKeyShortcut(keyPageDown, {}), mkKeyShortcut(keyKp3, {})],
  tesSelectionAll: @[mkKeyShortcut(keyA, {mkCtrl})],
  tesSelectionOneCharLeft:
    @[mkKeyShortcut(keyLeft, {mkShift}), mkKeyShortcut(keyKp4, {mkShift})],
  tesSelectionOneCharRight:
    @[mkKeyShortcut(keyRight, {mkShift}), mkKeyShortcut(keyKp6, {mkShift})],
  tesSelectionToPreviousWord:
    @[
      mkKeyShortcut(keyLeft, {mkCtrl, mkShift}),
      mkKeyShortcut(keyKp4, {mkCtrl, mkShift}),
    ],
  tesSelectionToNextWord:
    @[
      mkKeyShortcut(keyRight, {mkCtrl, mkShift}),
      mkKeyShortcut(keyKp6, {mkCtrl, mkShift}),
    ],
  tesSelectionToLineStart:
    @[mkKeyShortcut(keyHome, {mkShift}), mkKeyShortcut(keyKp7, {mkShift})],
  tesSelectionToLineEnd:
    @[mkKeyShortcut(keyEnd, {mkShift}), mkKeyShortcut(keyKp1, {mkShift})],
  tesSelectionToDocumentStart:
    @[
      mkKeyShortcut(keyHome, {mkCtrl, mkShift}),
      mkKeyShortcut(keyKp7, {mkCtrl, mkShift}),
    ],
  tesSelectionToDocumentEnd:
    @[
      mkKeyShortcut(keyEnd, {mkCtrl, mkShift}), mkKeyShortcut(keyKp1, {mkCtrl, mkShift})
    ],
  tesSelectionToPreviousLine:
    @[mkKeyShortcut(keyUp, {mkShift}), mkKeyShortcut(keyKp8, {mkShift})],
  tesSelectionToNextLine:
    @[mkKeyShortcut(keyDown, {mkShift}), mkKeyShortcut(keyKp2, {mkShift})],
  tesSelectionPageUp:
    @[mkKeyShortcut(keyPageUp, {mkShift}), mkKeyShortcut(keyKp9, {mkShift})],
  tesSelectionPageDown:
    @[mkKeyShortcut(keyPageDown, {mkShift}), mkKeyShortcut(keyKp3, {mkShift})],
  tesDeleteOneCharLeft: @[mkKeyShortcut(keyBackspace, {})],
  tesDeleteOneCharRight:
    @[mkKeyShortcut(keyDelete, {}), mkKeyShortcut(keyKpDecimal, {})],
  tesDeleteWordToLeft: @[mkKeyShortcut(keyBackspace, {mkCtrl})],
  tesDeleteWordToRight:
    @[mkKeyShortcut(keyDelete, {mkCtrl}), mkKeyShortcut(keykpDecimal, {mkCtrl})],
  tesDeleteToLineStart: @[mkKeyShortcut(keyBackspace, {mkCtrl, mkShift})],
  tesDeleteToLineEnd:
    @[
      mkKeyShortcut(keyDelete, {mkCtrl, mkShift}),
      mkKeyShortcut(keykpDecimal, {mkCtrl, mkShift}),
    ],
  tesCutText: @[mkKeyShortcut(keyX, {mkCtrl})],
  tesCopyText: @[mkKeyShortcut(keyC, {mkCtrl})],
  tesPasteText: @[mkKeyShortcut(keyV, {mkCtrl})],
  tesInsertNewline:
    @[mkKeyShortcut(keyEnter, {mkShift}), mkKeyShortcut(keyKpEnter, {mkShift})],
  tesPrevTextField: @[mkKeyShortcut(keyTab, {mkShift})],
  tesNextTextField: @[mkKeyShortcut(keyTab, {})],
  tesAccept: @[mkKeyShortcut(keyEnter, {}), mkKeyShortcut(keyKpEnter, {})],
  tesCancel: @[mkKeyShortcut(keyEscape, {}), mkKeyShortcut(keyLeftBracket, {mkCtrl})],
}.toTable

# Shortcut definitions - Mac
let g_textFieldEditShortcuts_Mac = {
  tesCursorOneCharLeft:
    @[
      mkKeyShortcut(keyLeft, {}),
      mkKeyShortcut(keyKp4, {}),
      mkKeyShortcut(keyB, {mkCtrl}),
    ],
  tesCursorOneCharRight:
    @[
      mkKeyShortcut(keyRight, {}),
      mkKeyShortcut(keyKp6, {}),
      mkKeyShortcut(keyF, {mkCtrl}),
    ],
  tesCursorToPreviousWord: @[mkKeyShortcut(keyLeft, {mkAlt})],
  tesCursorToNextWord: @[mkKeyShortcut(keyRight, {mkAlt})],
  tesCursorToLineStart:
    @[mkKeyShortcut(keyLeft, {mkSuper}), mkKeyShortcut(keyKp4, {mkSuper})],
  tesCursorToLineEnd:
    @[mkKeyShortcut(keyRight, {mkSuper}), mkKeyShortcut(keyKp6, {mkSuper})],
  tesCursorToDocumentStart:
    @[mkKeyShortcut(keyUp, {mkSuper}), mkKeyShortcut(keyKp8, {mkSuper})],
  tesCursorToDocumentEnd:
    @[mkKeyShortcut(keyDown, {mkSuper}), mkKeyShortcut(keyKp2, {mkSuper})],
  tesCursorToPreviousLine:
    @[
      mkKeyShortcut(keyUp, {}), mkKeyShortcut(keyKp8, {}), mkKeyShortcut(keyP, {mkCtrl})
    ],
  tesCursorToNextLine:
    @[
      mkKeyShortcut(keyDown, {}),
      mkKeyShortcut(keyKp2, {}),
      mkKeyShortcut(keyN, {mkCtrl}),
    ],
  tesCursorPageUp: @[mkKeyShortcut(keyPageUp, {}), mkKeyShortcut(keyKp9, {})],
  tesCursorPageDown: @[mkKeyShortcut(keyPageDown, {}), mkKeyShortcut(keyKp3, {})],
  tesSelectionAll: @[mkKeyShortcut(keyA, {mkSuper})],
  tesSelectionOneCharLeft:
    @[mkKeyShortcut(keyLeft, {mkShift}), mkKeyShortcut(keyKp4, {mkShift})],
  tesSelectionOneCharRight:
    @[mkKeyShortcut(keyRight, {mkShift}), mkKeyShortcut(keyKp6, {mkShift})],
  tesSelectionToPreviousWord:
    @[
      mkKeyShortcut(keyLeft, {mkSuper, mkShift}),
      mkKeyShortcut(keyKp4, {mkSuper, mkShift}),
    ],
  tesSelectionToNextWord:
    @[
      mkKeyShortcut(keyRight, {mkSuper, mkShift}),
      mkKeyShortcut(keyKp6, {mkSuper, mkShift}),
    ],
  tesDeleteOneCharLeft:
    @[mkKeyShortcut(keyBackspace, {}), mkKeyShortcut(keyH, {mkCtrl})],
  tesDeleteOneCharRight: @[mkKeyShortcut(keyDelete, {}), mkKeyShortcut(keyD, {mkCtrl})],
  tesDeleteWordToLeft: @[mkKeyShortcut(keyBackspace, {mkAlt})],
  tesDeleteWordToRight: @[mkKeyShortcut(keyDelete, {mkAlt})],
  tesDeleteToLineStart: @[mkKeyShortcut(keyBackspace, {mkSuper})],
  tesDeleteToLineEnd:
    @[mkKeyShortcut(keyDelete, {mkAlt}), mkKeyShortcut(keyK, {mkCtrl})],
  tesCutText: @[mkKeyShortcut(keyX, {mkSuper})],
  tesCopyText: @[mkKeyShortcut(keyC, {mkSuper})],
  tesPasteText: @[mkKeyShortcut(keyV, {mkSuper})],
  tesInsertNewline:
    @[
      mkKeyShortcut(keyEnter, {mkShift}),
      mkKeyShortcut(keyKpEnter, {mkShift}),
      mkKeyShortcut(keyO, {mkCtrl}),
    ],
  tesPrevTextField: @[mkKeyShortcut(keyTab, {mkShift})],
  tesNextTextField: @[mkKeyShortcut(keyTab, {})],
  tesAccept: @[mkKeyShortcut(keyEnter, {}), mkKeyShortcut(keyKpEnter, {})],
  tesCancel: @[mkKeyShortcut(keyEscape, {}), mkKeyShortcut(keyLeftBracket, {mkCtrl})],
}.toTable

const CharBufSize = 256
var
  g_charBuf*: array[CharBufSize, Rune]
  g_charBufIdx*: Natural

proc charCb*(win: Window, codePoint: Rune) =
  if g_charBufIdx <= g_charBuf.high:
    g_charBuf[g_charBufIdx] = codePoint
    inc(g_charBufIdx)

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

proc keyCb*(
    win: Window, key: Key, scanCode: int32, action: KeyAction, mods: set[ModifierKey]
) =
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

proc mouseButtonCb*(
    win: Window, button: MouseButton, pressed: bool, modKeys: set[ModifierKey]
) =
  let (x, y) = win.cursorPos()
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

proc scrollCb*(win: Window, offset: tuple[x, y: float64]) =
  discard g_eventBuf.write(Event(kind: ekScroll, ox: offset.x, oy: offset.y))

proc showCursor*() =
  activeWindow().cursorMode = cmNormal

proc hideCursor*() =
  activeWindow().cursorMode = cmHidden

proc disableCursor*() =
  activeWindow().cursorMode = cmDisabled

proc setCursorShape*(cs: CursorShape) =
  g_uiState.cursorShape = cs

proc setCursorMode*(cs: CursorShape) =
  let win = activeWindow()

  var c: Cursor
  if cs == csArrow:
    c = g_cursorArrow
  elif cs == csIBeam:
    c = g_cursorIBeam
  elif cs == csCrosshair:
    c = g_cursorCrosshair
  elif cs == csHand:
    c = g_cursorHand
  elif cs == csResizeEW:
    c = g_cursorResizeEW
  elif cs == csResizeNS:
    c = g_cursorResizeNS
  elif cs == csResizeNWSE:
    c = g_cursorResizeNWSE
  elif cs == csResizeNESW:
    c = g_cursorResizeNESW
  elif cs == csResizeAll:
    c = g_cursorResizeAll

  win.cursor = c

proc setCursorPosX*(x: float) =
  let win = activeWindow()
  let (_, currY) = win.cursorPos()
  win.cursorPos = (x * g_uiState.scale, currY)

proc setCursorPosY*(y: float) =
  let win = activeWindow()
  let (currX, _) = win.cursorPos()
  win.cursorPos = (currX, y * g_uiState.scale)

const
  DoubleClickMaxDelay = 0.4
  DoubleClickMaxXOffs = 3.0
  DoubleClickMaxYOffs = 3.0

proc isDoubleClick*(): bool =
  alias(ui, g_uiState)

  ui.mbLeftDown and core.getTime() - ui.lastMbLeftDownT <= DoubleClickMaxDelay and
    abs(ui.lastMbLeftDownX - ui.mx) <= DoubleClickMaxXOffs and
    abs(ui.lastMbLeftDownY - ui.my) <= DoubleClickMaxYOffs

proc setShortcuts*(sm: ShortcutMode) =
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

proc toClipboard*(s: string) =
  activeWindow().clipboardString = s

proc fromClipboard*(): string =
  $activeWindow().clipboardString

proc init*(vg: NVGContext, glfwGetProcAddress: proc) =
  initCore(vg, glfwGetProcAddress)

  let win = activeWindow()
  win.keyCb = keyCb
  win.charCb = charCb
  win.mouseButtonCb = mouseButtonCb
  win.scrollCb = scrollCb

  setShortcuts(smLinux)

  when not defined(koiWebGpu):
    glfw.swapInterval(1)

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
