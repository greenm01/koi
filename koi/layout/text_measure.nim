import std/math
import std/options
import std/strformat
import std/strutils
import std/tables
import std/unicode

import nanovg
import koi/core
import koi/drawing
import koi/input
import koi/internal/layout_solver
import koi/rect
import koi/types
import koi/utils

export layout_solver

# Layout engine: standard auto-layout and hierarchical blocks

const LayoutTextBreakChars = [
  " ", "\u2000", "\u2001", "\u2002", "\u2003", "\u2004", "\u2005", "\u2006", "\u2008",
  "\u2009", "\u200a", "\u205f", "\u3000", "-", "\u00ad", "\u2010", "\u2012", "\u2013",
  "|", "\n",
]

func isLayoutTextBreak(r: Rune): bool =
  let s = $r
  for ch in LayoutTextBreakChars:
    if s == ch:
      return true

func textMeasureSegments(text: string): seq[string] =
  var segment = ""
  for rune in text.runes:
    if rune.isLayoutTextBreak:
      if segment.len > 0:
        result.add(segment)
        segment.setLen(0)
    else:
      segment.add($rune)

  if segment.len > 0:
    result.add(segment)

  if result.len == 0:
    result.add("")

func explicitLineCount(text: string): int =
  max(1, text.count("\n") + 1)

proc fallbackMeasureText(text: string, fontSize, maxWidth: float): TextMeasure =
  let
    fontSize = if fontSize > 0: fontSize else: 14.0
    advance = max(1.0, fontSize * 0.5)
    prefWidth = text.runeLen.float * advance
    lineHeight = fontSize * 1.4

  var longest = 0
  for segment in text.textMeasureSegments:
    longest = max(longest, segment.runeLen)

  let lineCount =
    if maxWidth <= 0 or maxWidth >= LayoutInfinity * 0.5:
      text.explicitLineCount
    else:
      max(text.explicitLineCount, ceil(prefWidth / maxWidth).int)

  TextMeasure(
    minWidth: longest.float * advance,
    prefWidth: prefWidth,
    lineHeight: lineHeight,
    lineCount: lineCount,
  )

proc measureLayoutText*(
    text: string, fontSize: float, fontFace: string, maxWidth: float
): TextMeasure =
  let
    fontSize = if fontSize > 0: fontSize else: 14.0
    fontFace = if fontFace.len > 0: fontFace else: "sans-bold"
    lineHeight = fontSize * 1.4

  if g_nvgContext == nil:
    return fallbackMeasureText(text, fontSize, maxWidth)

  g_nvgContext.useFont(fontSize, name = fontFace)

  var minWidth = 0.0
  for segment in text.textMeasureSegments:
    minWidth = max(minWidth, g_nvgContext.textWidth(segment))

  let lineCount =
    if maxWidth <= 0 or maxWidth >= LayoutInfinity * 0.5:
      text.explicitLineCount
    else:
      max(1, textBreakLines(text, maxWidth).len)

  TextMeasure(
    minWidth: minWidth,
    prefWidth: g_nvgContext.textWidth(text),
    lineHeight: lineHeight,
    lineCount: lineCount,
  )
