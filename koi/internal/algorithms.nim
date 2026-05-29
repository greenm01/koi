import std/math

import nanovg

import koi/utils

type TextFieldView* = object
  displayStartPos*: Natural
  displayStartX*: float

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
