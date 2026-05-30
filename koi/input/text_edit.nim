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
  let runes = text.toRunes
  var p = min(cursorPos, runes.len.Natural)
  while p < runes.len.Natural and runes[p].isAlphanumeric:
    inc(p)
  while p < runes.len.Natural and not runes[p].isAlphanumeric:
    inc(p)
  result = p

func findPrevWordStart*(text: string, cursorPos: Natural): Natural =
  let runes = text.toRunes
  var p = min(cursorPos, runes.len.Natural)
  while p > 0 and not runes[p - 1].isAlphanumeric:
    dec(p)
  while p > 0 and runes[p - 1].isAlphanumeric:
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
    let selectedLen =
      if hasSelection(selection):
        let ns = normaliseSelection(selection)
        ns.endPos - ns.startPos.Natural
      else:
        0.Natural
    let baseLen = textLen - selectedLen
    let insertLimit =
      if maxLen.isSome:
        if baseLen < maxLen.get:
          maxLen.get - baseLen
        else:
          0.Natural
      else:
        insertLen
    let toInsert =
      if insertLen > insertLimit:
        toInsert.runeSubStr(0, insertLimit)
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
    filter: TextFieldFilterKind = tffAny,
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
    elif cursorPos < text.runeLen:
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
      let toInsert =
        filterTextInputForInsert(text, cursorPos, selection, fromClipboard(), filter)
      res = insertString(text, cursorPos, selection, toInsert, maxLen)
    except CatchableError:
      # attempting to retrieve non-text data raises an exception
      discard
  else:
    eventHandled = false

  result = if eventHandled: res.some else: TextEditResult.none

# Shortcut definitions

# Shortcut definitions - Windows/Linux
