import std/math
import std/strutils

import nanovg

import koi/rect
import koi/types
import koi/utils

func filterTextInput*(text: string, filter: TextFieldFilterKind): string =
  for ch in text:
    let keep =
      case filter
      of tffAny:
        true
      of tffInteger:
        ch.isDigit or (ch in {'-', '+'})
      of tffFloat:
        ch.isDigit or (ch in {'-', '+', '.', 'e', 'E'})
      of tffHex:
        ch in {'0' .. '9', 'a' .. 'f', 'A' .. 'F'}
      of tffBinary:
        ch in {'0', '1'}
    if keep:
      result.add(ch)

func chartValueY*(value, minValue, maxValue, y, h: float): float =
  if maxValue <= minValue or h <= 0:
    y + h
  else:
    y + h - ((value - minValue) / (maxValue - minValue)).clamp(0.0, 1.0) * h

func chartPointX*(index, count: Natural, x, w: float): float =
  if count <= 1 or w <= 0:
    x
  else:
    x + (index.float / (count - 1).float).clamp(0.0, 1.0) * w

func chartColumnRect*(
    index, count: Natural, value, minValue, maxValue, x, y, w, h, gap: float
): Rect =
  if count == 0 or w <= 0 or h <= 0:
    return rect(x, y + h, 0, 0)

  let
    columnW = max(0.0, w / count.float - gap)
    columnX = x + index.float * (w / count.float) + gap * 0.5
    zeroY = chartValueY(0, minValue, maxValue, y, h)
    valueY = chartValueY(value, minValue, maxValue, y, h)
    topY = min(zeroY, valueY)

  rect(columnX, topY, columnW, max(abs(zeroY - valueY), 1.0))

func tableColumnWidths*(
    columns: openArray[TableColumn], availableWidth: float
): seq[float] =
  result = newSeq[float](columns.len)
  if columns.len == 0:
    return

  var fixedWidth = 0.0
  var autoCount = 0
  for column in columns:
    if column.width > 0:
      fixedWidth += column.width
    else:
      inc(autoCount)

  let autoWidth =
    if autoCount > 0:
      max(0.0, availableWidth - fixedWidth) / autoCount.float
    else:
      0.0

  for i, column in columns:
    result[i] = if column.width > 0: column.width else: autoWidth

type TextFieldView* = object
  displayStartPos*: Natural
  displayStartX*: float

type TextAreaRowSelection* = object
  active*: bool
  startPos*: Natural
  endPos*: Natural

func textFieldGlyphCount(glyphs: openArray[GlyphPosition], textLen: Natural): Natural =
  min(textLen, glyphs.len.Natural)

func textFieldCaretOffset(
    glyphs: openArray[GlyphPosition], textLen, cursorPos: Natural
): float =
  let glyphCount = textFieldGlyphCount(glyphs, textLen)
  if glyphCount == 0 or cursorPos == 0:
    return 0.0

  if cursorPos >= glyphCount:
    glyphs[glyphCount - 1].maxX.float
  else:
    glyphs[cursorPos].x.float

func textFieldCursorX*(
    glyphs: openArray[GlyphPosition], textLen, cursorPos: Natural, view: TextFieldView
): float =
  let glyphCount = textFieldGlyphCount(glyphs, textLen)
  if glyphCount == 0:
    return view.displayStartX

  let startPos = min(view.displayStartPos, glyphCount - 1)
  view.displayStartX + textFieldCaretOffset(glyphs, glyphCount, cursorPos) -
    glyphs[startPos].x.float

func textFieldCursorPosAt*(
    glyphs: openArray[GlyphPosition],
    textLen, displayStartPos: Natural,
    displayStartX, mouseX: float,
): Natural =
  let glyphCount = textFieldGlyphCount(glyphs, textLen)
  if glyphCount == 0:
    return 0.Natural

  let startPos = min(displayStartPos, glyphCount - 1)
  for p in startPos ..< glyphCount:
    let midX =
      glyphs[p].minX.float + (glyphs[p].maxX.float - glyphs[p].minX.float) * 0.5
    if mouseX < displayStartX + midX - glyphs[startPos].x.float:
      return p.Natural
  glyphCount

func textFieldViewForCursor*(
    glyphs: openArray[GlyphPosition],
    textLen, cursorPos: Natural,
    textBoxX, textBoxW: float,
    currentView: TextFieldView,
): TextFieldView =
  let glyphCount = textFieldGlyphCount(glyphs, textLen)
  if glyphCount == 0:
    return TextFieldView(displayStartPos: 0, displayStartX: textBoxX)

  if glyphs[glyphCount - 1].maxX.float <= textBoxW:
    return TextFieldView(displayStartPos: 0, displayStartX: textBoxX)

  result = currentView
  result.displayStartPos = min(result.displayStartPos, glyphCount - 1)

  let cursorPos = min(cursorPos, glyphCount)
  let caretOffset = textFieldCaretOffset(glyphs, glyphCount, cursorPos)
  let startOffset = glyphs[result.displayStartPos].x.float
  let cursorX = result.displayStartX + caretOffset - startOffset

  if cursorX > textBoxX + textBoxW:
    var startPos =
      if cursorPos >= glyphCount:
        glyphCount - 1
      else:
        cursorPos
    while startPos > 0 and caretOffset - glyphs[startPos].x.float < textBoxW:
      dec(startPos)
    result.displayStartPos = startPos
    result.displayStartX =
      textBoxX + textBoxW - (caretOffset - glyphs[result.displayStartPos].x.float)
  elif cursorX < textBoxX:
    result.displayStartPos =
      if cursorPos >= glyphCount:
        glyphCount - 1
      else:
        cursorPos
    result.displayStartX = textBoxX
  elif result.displayStartX > textBoxX:
    result.displayStartX = textBoxX

func textAreaRowEndCursor*(row: types.TextRow): Natural =
  if row.nextRowPos >= 0:
    row.nextRowPos.Natural
  elif row.startPos == row.endPos and row.width == 0:
    row.startPos
  else:
    row.endPos + 1

func textAreaRowForCursor*(
    rows: openArray[types.TextRow], cursorPos: Natural
): Natural =
  if rows.len == 0:
    return 0.Natural

  for i, row in rows:
    let rowEnd = textAreaRowEndCursor(row)
    if rowEnd == row.startPos:
      if cursorPos == row.startPos:
        return i.Natural
    elif cursorPos >= row.startPos and cursorPos < rowEnd:
      return i.Natural

  rows.high.Natural

func textAreaRowAtY*(
    rowsLen: Natural, displayStartRow: float, textBoxY, rowHeight, mouseY: float
): Natural =
  if rowsLen == 0:
    return 0.Natural

  let startRow = max(floor(displayStartRow).int, 0)
  if rowHeight <= 0:
    return min(startRow, rowsLen.int - 1).Natural

  let localRow = floor((mouseY - textBoxY) / rowHeight).int
  clamp(startRow + localRow, 0, rowsLen.int - 1).Natural

func textAreaDisplayStartRowForCursor*(
    rowsLen, rowIndex: Natural, textBoxH, rowHeight, currentStart: float
): float =
  if rowsLen == 0 or rowHeight <= 0:
    return 0.0

  let visibleRows = max(floor(textBoxH / rowHeight).int, 1)
  let maxStart = max(rowsLen.int - visibleRows, 0)
  var start = clamp(floor(currentStart).int, 0, maxStart)
  let rowIndex = min(rowIndex.int, rowsLen.int - 1)

  if rowIndex < start:
    start = rowIndex
  elif rowIndex >= start + visibleRows:
    start = rowIndex - visibleRows + 1

  clamp(start, 0, maxStart).float

func textAreaVisibleRows*(textBoxH, rowHeight: float): Natural =
  if rowHeight <= 0:
    1.Natural
  else:
    max(floor(textBoxH / rowHeight).int, 1).Natural

func textAreaMaxDisplayStart*(rowsLen: Natural, textBoxH, rowHeight: float): float =
  let visibleRows = textAreaVisibleRows(textBoxH, rowHeight)
  max(rowsLen.int - visibleRows.int, 0).float

func textAreaScrollDisplayStart*(
    rowsLen: Natural, textBoxH, rowHeight, currentStart, deltaRows: float
): float =
  clamp(
    currentStart + deltaRows, 0.0, textAreaMaxDisplayStart(rowsLen, textBoxH, rowHeight)
  )

func textAreaRowByDelta*(rowsLen, rowIndex: Natural, deltaRows: int): Natural =
  if rowsLen == 0:
    return 0.Natural

  clamp(rowIndex.int + deltaRows, 0, rowsLen.int - 1).Natural

func textAreaLineStartCursor*(
    rows: openArray[types.TextRow], cursorPos: Natural
): Natural =
  if rows.len == 0:
    return 0.Natural

  rows[textAreaRowForCursor(rows, cursorPos)].startPos

func textAreaLineEndCursor*(
    rows: openArray[types.TextRow], cursorPos: Natural
): Natural =
  if rows.len == 0:
    return 0.Natural

  textAreaRowEndCursor(rows[textAreaRowForCursor(rows, cursorPos)])

func textAreaSelectionForRow*(
    row: types.TextRow, selection: types.TextSelection
): TextAreaRowSelection =
  if selection.startPos < 0 or selection.startPos == selection.endPos.int:
    return

  let
    selectionStart = min(selection.startPos, selection.endPos.int).Natural
    selectionEnd = max(selection.startPos, selection.endPos.int).Natural
    rowStart = row.startPos
    rowEnd = textAreaRowEndCursor(row)
    startPos = max(selectionStart, rowStart)
    endPos = min(selectionEnd, rowEnd)

  if startPos < endPos:
    result = TextAreaRowSelection(active: true, startPos: startPos, endPos: endPos)

func textAreaCursorX*(
    rowGlyphs: openArray[GlyphPosition],
    rowStartPos, cursorPos: Natural,
    textBoxX: float,
): float =
  if rowGlyphs.len == 0 or cursorPos <= rowStartPos:
    return textBoxX

  let offset = cursorPos - rowStartPos
  if offset >= rowGlyphs.len.Natural:
    textBoxX + rowGlyphs[^1].maxX.float
  else:
    textBoxX + rowGlyphs[offset].x.float

func textAreaCursorPosAt*(
    rowGlyphs: openArray[GlyphPosition],
    rowStartPos, rowEndPos: Natural,
    mouseX, textBoxX: float,
): Natural =
  if rowEndPos <= rowStartPos or rowGlyphs.len == 0:
    return rowStartPos

  let glyphCount = min(rowGlyphs.len.Natural, rowEndPos - rowStartPos)
  for i in 0 ..< glyphCount:
    let midX =
      rowGlyphs[i].minX.float + (rowGlyphs[i].maxX.float - rowGlyphs[i].minX.float) * 0.5
    if mouseX < textBoxX + midX:
      return rowStartPos + i

  rowStartPos + glyphCount

func dropDownHoverItem*(
    mouseY, itemListY, itemListPadVert, itemHeight: float,
    displayStartItem, maxDisplayItems, itemCount: Natural,
): int =
  if itemHeight <= 0 or itemCount == 0 or maxDisplayItems == 0:
    return -1

  let itemY = mouseY - itemListY - itemListPadVert
  if itemY < 0:
    return -1

  let visibleIndex = floor(itemY / itemHeight).int
  if visibleIndex < 0 or visibleIndex >= maxDisplayItems.int:
    return -1

  let itemIndex = displayStartItem.int + visibleIndex
  if itemIndex < itemCount.int: itemIndex else: -1

func progressFraction*(value, maxValue: float): float =
  if maxValue <= 0:
    0.0
  else:
    clamp(value / maxValue, 0.0, 1.0)

func propertyStepValue*(value, minValue, maxValue, step: float, dir: int): float =
  let
    lo = min(minValue, maxValue)
    hi = max(minValue, maxValue)
  let delta = step * dir.float
  clamp(value + delta, lo, hi)

func propertyStepValue*(value, minValue, maxValue, step: int, dir: int): int =
  let
    lo = min(minValue, maxValue)
    hi = max(minValue, maxValue)
  clamp(value + step * dir, lo, hi)

func popupShouldAutoClose*(
    mouseX, mouseY, x, y, w, h, border: float, autoClose: bool
): bool =
  if not autoClose:
    return false

  not (
    mouseX >= x - border and mouseX <= x + w + border and mouseY >= y - border and
    mouseY <= y + h + border
  )

func dropDownKeyboardItem*(current, itemCount, dir: int, wrap: bool = false): int =
  if itemCount <= 0:
    return -1

  let next = current + dir
  if wrap:
    if next < 0:
      itemCount - 1
    elif next >= itemCount:
      0
    else:
      next
  else:
    clamp(next, 0, itemCount - 1)

func scrollStartForActiveItem*(
    activeItem: int, displayStartItem, maxDisplayItems, itemCount: Natural
): Natural =
  if itemCount == 0 or maxDisplayItems == 0 or activeItem < 0:
    return 0.Natural

  let
    active = min(activeItem, itemCount.int - 1)
    start = min(displayStartItem, itemCount - 1)
    visibleCount = min(maxDisplayItems, itemCount)

  if active < start.int:
    active.Natural
  elif active >= start.int + visibleCount.int:
    min((active - visibleCount.int + 1).Natural, itemCount - visibleCount)
  else:
    start

func listViewRange*(
    itemCount: Natural, rowHeight, viewHeight, scrollY: float
): ListViewRange =
  result.contentHeight = itemCount.float * max(rowHeight, 0.0)
  if itemCount == 0 or rowHeight <= 0 or viewHeight <= 0:
    return

  let
    maxScroll = max(result.contentHeight - viewHeight, 0.0)
    scrollY = clamp(scrollY, 0.0, maxScroll)
    first = clamp(floor(scrollY / rowHeight).int, 0, itemCount.int - 1)
    visibleRows = max(ceil(viewHeight / rowHeight).int + 1, 1)
    last = clamp(first + visibleRows - 1, first, itemCount.int - 1)

  result.first = first.Natural
  result.last = last.Natural
  result.startY = first.float * rowHeight - scrollY

func scrollBarRange*(startVal, endVal: float): float =
  abs(startVal - endVal)

func effectiveScrollBarThumbSize*(thumbSize, startVal, endVal: float): float =
  let valueRange = scrollBarRange(startVal, endVal)
  if valueRange <= 0:
    0.0
  elif thumbSize <= 0 or thumbSize > valueRange:
    0.000001
  else:
    thumbSize

func scrollBarThumbLength*(
    trackLength, thumbPad, thumbMinSize, thumbSize, startVal, endVal: float
): float =
  let usableLength = max(trackLength - thumbPad * 2, 0.0)
  if usableLength <= 0:
    return 0.0

  let valueRange = scrollBarRange(startVal, endVal)
  if valueRange <= 0:
    return usableLength

  let effectiveThumbSize = effectiveScrollBarThumbSize(thumbSize, startVal, endVal)
  let calculatedLength = usableLength / (valueRange / effectiveThumbSize)
  max(calculatedLength, min(thumbMinSize, usableLength))

func scrollBarThumbFromValue*(
    value, startVal, endVal, thumbMin, thumbMax: float
): float =
  if startVal == endVal or thumbMin == thumbMax:
    thumbMin
  else:
    lerp(thumbMin, thumbMax, invLerp(startVal, endVal, value))

func scrollBarValueFromThumb*(
    thumbPos, thumbMin, thumbMax, startVal, endVal: float
): float =
  if startVal == endVal or thumbMin == thumbMax:
    startVal
  else:
    lerp(startVal, endVal, invLerp(thumbMin, thumbMax, thumbPos))

func scrollBarTrackClickValue*(
    value, startVal, endVal, clickDir, clickStep: float
): float =
  let step =
    if clickStep < 0:
      scrollBarRange(startVal, endVal) * 0.1
    else:
      clickStep

  let (s, e) =
    if startVal < endVal:
      (startVal, endVal)
    else:
      (endVal, startVal)
  clamp(value + clickDir * step, s, e)
