import std/[monotimes, options, strutils, times, unicode]

import wgpu_test_common
import koi/input
import koi/internal/algorithms

proc sampleText(repeats: int): string =
  const chunk =
    "alpha beta gamma delta epsilon zeta eta theta iota. " &
    "Unicode Ωmega café naïve 漢字 keeps rune paths honest.\n"
  for _ in 0 ..< repeats:
    result.add(chunk)

template bench(name: string, iters: int, body: untyped) =
  block:
    var checksum {.inject.} = 0
    for _ in 0 ..< 20:
      body
    let t0 = getMonoTime()
    for _ in 0 ..< iters:
      body
    let micros = inMicroseconds(getMonoTime() - t0).float / iters.float
    echo name, ": ", micros.formatFloat(ffDecimal, 2), " us/op   checksum=", checksum

let
  longText = sampleText(120)
  longTextLen = longText.runeLen.Natural
  wrapText = sampleText(25)
  wrapWidth = 136.0

bench "word navigation over mixed unicode prose", 3000:
  var p = (checksum.Natural * 17) mod longTextLen
  p = findNextWordEnd(longText, p)
  p = findPrevWordStart(longText, p)
  checksum = (checksum + p.int + 1) mod 1_000_003

bench "shortcut insert and backspace near document middle", 1000:
  var
    text = longText
    cursor = longTextLen div 2
  let inserted = insertString(text, cursor, NoSelection, "Ω漢 edit", none(Natural))
  text = inserted.text
  cursor = inserted.cursorPos
  let deleted = handleCommonTextEditingShortcuts(
    mkKeyShortcut(keyBackspace), text, cursor, NoSelection, none(Natural)
  ).get
  checksum = (checksum + deleted.text.runeLen.int + deleted.cursorPos.int) mod 1_000_003

bench "soft-wrap row measurement", 350:
  let rows = measureTextRows(wrapText, wrapWidth)
  checksum = (checksum + rows.len + rows[^1].endPos.int) mod 1_000_003

bench "wrapped cursor hit and caret geometry", 1200:
  let rows = measureTextRows(wrapText, wrapWidth)
  let rowIndex = (checksum mod rows.len)
  let row = rows[rowIndex]
  let glyphs = measureRowGlyphs(wrapText, row)
  let cursor = textAreaCursorPosAt(
    glyphs,
    row.startPos,
    textAreaRowTextEndCursor(row, wrapText),
    48.0 + (checksum mod 37).float,
    40.0,
  )
  let x = textAreaCursorX(glyphs, row.startPos, cursor, 40.0)
  checksum = (checksum + cursor.int + x.int) mod 1_000_003
