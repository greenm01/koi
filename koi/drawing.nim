import std/algorithm
import std/math
import std/sequtils
import std/strutils
import std/unicode

import nanovg
import glfw
when not defined(koiWebGpu):
  import koi/glad/gl

import koi/utils
import koi/types
import koi/core
import koi/input

# Drawing layers and utilities

type
  DrawProc* = proc(vg: NVGContext)

  DrawEntry* = object
    zIndex*: int
    order*: int
    draw*: DrawProc

  DrawLayers* = object
    layers*: array[0 .. ord(DrawLayer.high), seq[DrawEntry]]
    lastUsedLayer*: Natural
    nextOrder*: int

proc pxRatio*(): float =
  let win = activeWindow()
  let (winWidth, _) = win.size
  let (fbWidth, _) = win.framebufferSize
  result = fbWidth.float / (winWidth.float / g_uiState.scale)
  when defined(koiWebGpu):
    let (xscale, _) = win.contentScale
    result = max(result, xscale)

proc getPxRatio*(): float =
  pxRatio()

var
  g_drawLayers*: DrawLayers
  g_checkeredImage*: Image
  g_checkeredImageSize*: float

template renderToImage*(
    vg: NVGContext,
    width, height: int,
    pxRatio: float,
    imageFlags: set[ImageFlags],
    body: untyped,
): Image =
  when defined(koiWebGpu):
    NoImage
  else:
    var fb = vg.nvgluCreateFramebuffer(width, height, imageFlags)

    let (fboWidth, fboHeight) = vg.imageSize(fb.image)

    nvgluBindFramebuffer(fb)

    glViewport(0, 0, fboWidth.GLsizei, fboHeight.GLsizei)
    glClear(GL_COLOR_BUFFER_BIT or GL_STENCIL_BUFFER_BIT)

    vg.beginFrame(width.float, height.float, pxRatio)
    body
    vg.endFrame()

    nvgluBindFramebuffer(nil)

    let image = fb.image
    fb.image = NoImage
    nvgluDeleteFramebuffer(fb)
    image

proc createCheckeredImage*(vg: NVGContext) =
  const a = 14
  g_checkeredImageSize = a.float
  let pr = pxRatio()
  g_checkeredImage = vg.renderToImage(
    width = (a.float * pr).int, height = (a.float * pr).int, pr, {ifRepeatX, ifRepeatY}
  ):
    vg.scale(pr, pr)
    vg.strokeWidth(0)
    vg.fillColor(gray(0.7))
    vg.beginPath()
    vg.rect(0, 0, a.float, a.float)
    vg.fill()
    vg.fillColor(gray(0.4))
    vg.beginPath()
    vg.rect(0, 0, a.float * 0.5, a.float * 0.5)
    vg.fill()

func init*(dl: var DrawLayers) =
  for i in 0 .. dl.layers.high:
    dl.layers[i] = @[]
  dl.nextOrder = 0

func add*(dl: var DrawLayers, layer: Natural, p: DrawProc, zIndex: int = 0) =
  dl.layers[layer].add(DrawEntry(zIndex: zIndex, order: dl.nextOrder, draw: p))
  inc dl.nextOrder
  dl.lastUsedLayer = layer

template addDrawLayer*(layer: DrawLayer, vg, body: untyped) =
  g_drawLayers.add(
    ord(layer),
    proc(vg: NVGContext) =
      body,
  )

template addDrawLayerZ*(layer: DrawLayer, zIndex: int, vg, body: untyped) =
  g_drawLayers.add(
    ord(layer),
    proc(vg: NVGContext) =
      body,
    zIndex,
  )

template addDrawStateLayer*(layer: DrawLayer, vg, body: untyped) =
  addDrawLayer(layer, vg):
    body

proc draw*(dl: DrawLayers, vg: NVGContext) =
  for layer in dl.layers:
    var sortedLayer = layer
    sortedLayer.sort(
      proc(a, b: DrawEntry): int =
        result = cmp(a.zIndex, b.zIndex)
        if result == 0:
          result = cmp(a.order, b.order)
    )
    for entry in sortedLayer:
      entry.draw(vg)

proc currentLayer*(): DrawLayer =
  g_uiState.currentLayer

proc currentLayer*(l: DrawLayer) =
  g_uiState.currentLayer = l

proc setCurrentLayer*(l: DrawLayer) =
  currentLayer(l)

proc pushDrawOffset*(ds: DrawOffset) =
  g_uiState.drawOffsetStack.add(ds)

proc popDrawOffset*() =
  alias(ui, g_uiState)
  if ui.drawOffsetStack.len > 1:
    discard ui.drawOffsetStack.pop()

proc drawOffset*(): DrawOffset =
  g_uiState.drawOffsetStack[^1]

proc addDrawOffset*(x, y: float): (float, float) =
  let offs = drawOffset()
  result = (offs.ox + x, offs.oy + y)

proc toHex*(c: Color): string =
  const RgbMax = 255
  strutils.toHex((c.r * RgbMax).int, 2) & strutils.toHex((c.g * RgbMax).int, 2) &
    strutils.toHex((c.b * RgbMax).int, 2)

func colorFromHexStr*(s: string): Color =
  const RgbMax = 255
  try:
    let r = parseHexInt(s.substr(0, 1)).float / RgbMax
    let g = parseHexInt(s.substr(2, 3)).float / RgbMax
    let b = parseHexInt(s.substr(4, 5)).float / RgbMax
    result = rgb(r, g, b)
  except CatchableError:
    discard

func clampToRange*(value, startVal, endVal: float): float =
  if startVal <= endVal:
    value.clamp(startVal, endVal)
  else:
    value.clamp(endVal, startVal)

func snapToGrid*(
    x, y, w, h: float, strokeWidth: float = 0.0
): (float, float, float, float) =
  let s = (strokeWidth mod 2) * 0.5
  let
    x = round(x) - s
    y = round(y) - s
    w = round(w) + s * 2
    h = round(h) + s * 2
  result = (x, y, w, h)

proc fitRectWithinWindow*(
    w, h: float, ax, ay, aw, ah: float, align: HorizontalAlign
): (float, float) =
  alias(ui, g_uiState)
  var x =
    case align
    of haLeft:
      ax
    of haCenter:
      ax + aw * 0.5 - w * 0.5
    of haRight:
      ax + aw
  var y = ay + ah
  let pad = 10.0
  if x + w > ui.winWidth - pad:
    x = ax + aw - w
  if y + h > ui.winHeight - pad:
    y = ay - h
  if x < pad:
    x = pad
  elif x + w > ui.winWidth - pad:
    x = ui.winWidth - pad - w
  if y < pad:
    y = pad
  elif y + h > ui.winHeight - pad:
    y = ui.winHeight - pad - h
  result = (x, y)

proc useFont*(
    vg: NVGContext,
    size: float,
    name: string = "sans-bold",
    horizAlign: HorizontalAlign = haLeft,
    vertAlign: VerticalAlign = vaMiddle,
) =
  vg.fontFace(name)
  vg.fontSize(size)
  vg.textAlign(horizAlign, vertAlign)

proc setFont*(
    vg: NVGContext,
    size: float,
    name: string = "sans-bold",
    horizAlign: HorizontalAlign = haLeft,
    vertAlign: VerticalAlign = vaMiddle,
) =
  vg.useFont(size, name, horizAlign, vertAlign)

const TextBreakRunes = @[
  "\u0020", "\u2000", "\u2001", "\u2002", "\u2003", "\u2004", "\u2005", "\u2006",
  "\u2008", "\u2009", "\u200a", "\u205f", "\u3000", "\u002d", "\u00ad", "\u2010",
  "\u2012", "\u2013", "\u007c",
].mapIt(it.runeAt(0))

proc fallbackTextBreakLines(text: string, maxWidth: float): seq[types.TextRow] =
  const Advance = 7.0
  if text == "":
    return
      @[
        types.TextRow(
          startPos: 0,
          startBytePos: 0,
          endPos: 0,
          endBytePos: 0,
          nextRowPos: -1,
          nextRowBytePos: -1,
          width: 0,
        )
      ]

  var
    byteStarts: seq[int]
    byteEnds: seq[int]
  var bytePos = 0
  for rune in text.runes:
    byteStarts.add(bytePos)
    inc(bytePos, rune.size)
    byteEnds.add(bytePos - 1)

  let maxRunes =
    if maxWidth <= 0:
      1
    else:
      max(floor(maxWidth / Advance).int, 1)

  var start = 0
  while start < byteStarts.len:
    let stop = min(start + maxRunes, byteStarts.len)
    result.add(
      types.TextRow(
        startPos: start.Natural,
        startBytePos: byteStarts[start],
        endPos: (stop - 1).Natural,
        endBytePos: byteEnds[stop - 1],
        nextRowPos: if stop < byteStarts.len: stop else: -1,
        nextRowBytePos:
          if stop < byteStarts.len:
            byteStarts[stop]
          else:
            -1,
        width: (stop - start).float * Advance,
      )
    )
    start = stop

proc textBreakLines*(
    text: string, maxWidth: float, maxRows: int = -1
): seq[types.TextRow] =
  if g_nvgContext == nil:
    return fallbackTextBreakLines(text, maxWidth)

  var glyphs: array[1024, GlyphPosition]
  result = newSeq[types.TextRow]()
  if text == "":
    return
      @[
        types.TextRow(
          startPos: 0,
          startBytePos: 0,
          endPos: 0,
          endBytePos: 0,
          nextRowPos: -1,
          nextRowBytePos: -1,
          width: 0,
        )
      ]
  let textLen = text.runeLen
  proc fillGlyphsBuffer(textPos, textBytePos: Natural) =
    glyphs[0] = glyphs[^2]
    glyphs[1] = glyphs[^1]
    discard g_nvgContext.textGlyphPositions(
      glyphs[1].maxX,
      0,
      text,
      startPos = textBytePos,
      toOpenArray(glyphs, 2, glyphs.high),
    )

  const NewLine = "\n".runeAt(0)
  var prevRune: Rune
  var textPos, textBytePos, prevTextPos, prevTextBytePos: int = 0
  var glyphPos = 3
  var rowStartPos, rowStartBytePos: Natural
  var rowStartX = glyphs[0].x
  var lastBreakPos, lastBreakBytePos: int = -1
  var lastBreakPosStartX: float
  var lastBreakPosPrev, lastBreakBytePosPrev: Natural
  fillGlyphsBuffer(textPos, textBytePos)
  for rune in text.runes:
    if glyphPos >= glyphs.len:
      fillGlyphsBuffer(textPos, textBytePos)
      glyphPos = 2
    if rune == NewLine and prevRune != NewLine:
      discard
    else:
      if prevRune == NewLine:
        let newLineEndX = glyphs[glyphPos - 1].x
        let runeBeforeNewLineEndX = glyphs[glyphPos - 2].x
        let row = types.TextRow(
          startPos: rowStartPos,
          startBytePos: rowStartBytePos,
          endPos: prevTextPos,
          endBytePos: prevTextBytePos,
          nextRowPos: textPos,
          nextRowBytePos: textBytePos,
          width: runeBeforeNewLineEndX - rowStartX,
        )
        result.add(row)
        rowStartPos = row.nextRowPos
        rowStartBytePos = row.nextRowBytePos
        rowStartX = newLineEndX
        lastBreakPos = -1
        lastBreakBytePos = -1
      else:
        if prevRune in TextBreakRunes and rune notin TextBreakRunes:
          lastBreakPos = textPos
          lastBreakBytePos = textBytePos
          lastBreakPosPrev = prevTextPos
          lastBreakBytePosPrev = prevTextBytePos
          lastBreakPosStartX = glyphs[glyphPos - 1].x
        let currRuneEndX = glyphs[glyphPos].x
        if currRuneEndX - rowStartX > maxWidth:
          if lastBreakPos > 0:
            let row = types.TextRow(
              startPos: rowStartPos,
              startBytePos: rowStartBytePos,
              endPos: lastBreakPosPrev,
              endBytePos: lastBreakBytePosPrev,
              nextRowPos: lastBreakPos,
              nextRowBytePos: lastBreakBytePos,
              width: lastBreakPosStartX - rowStartX,
            )
            result.add(row)
            rowStartPos = row.nextRowPos
            rowStartBytePos = row.nextRowBytePos
            rowStartX = lastBreakPosStartX
            lastBreakPos = -1
            lastBreakBytePos = -1
          else:
            let prevRuneEndX = glyphs[glyphPos - 1].x
            let row = types.TextRow(
              startPos: rowStartPos,
              startBytePos: rowStartBytePos,
              endPos: prevTextPos,
              endBytePos: prevTextBytePos,
              nextRowPos: textPos,
              nextRowBytePos: textBytePos,
              width: prevRuneEndX - rowStartX,
            )
            result.add(row)
            rowStartPos = row.nextRowPos
            rowStartBytePos = row.nextRowBytePos
            rowStartX = prevRuneEndX
            lastBreakPos = -1
            lastBreakBytePos = -1
    if textPos == textLen - 1:
      if rune == NewLine:
        let runeBeforeNewLineEndX = glyphs[glyphPos - 1].x
        let lastEmptyRowStartPos = textLen
        let lastEmptyRowStartBytePos = textBytePos + 1
        result.add(
          types.TextRow(
            startPos: rowStartPos,
            startBytePos: rowStartBytePos,
            endPos: textPos,
            endBytePos: textBytePos,
            nextRowPos: lastEmptyRowStartPos,
            nextRowBytePos: lastEmptyRowStartBytePos,
            width: runeBeforeNewLineEndX - rowStartX,
          )
        )
        result.add(
          types.TextRow(
            startPos: lastEmptyRowStartPos,
            startBytePos: lastEmptyRowStartBytePos,
            endPos: lastEmptyRowStartPos,
            endBytePos: lastEmptyRowStartBytePos,
            nextRowPos: -1,
            nextRowBytePos: -1,
            width: 0,
          )
        )
      else:
        let currRuneEndX = glyphs[glyphPos].x
        result.add(
          types.TextRow(
            startPos: rowStartPos,
            startBytePos: rowStartBytePos,
            endPos: textPos,
            endBytePos: textBytePos,
            nextRowPos: -1,
            nextRowBytePos: -1,
            width: currRuneEndX - rowStartX,
          )
        )
    prevRune = rune
    prevTextPos = textPos
    prevTextBytePos = textBytePos
    inc(textPos)
    inc(textBytePos, rune.size)
    inc(glyphPos)

proc drawShadow*(vg: NVGContext, x, y, w, h: float, style: ShadowStyle) =
  alias(s, style)
  if s.enabled:
    let (x, y, w, h) = snapToGrid(x, y, w, h)
    let shadow = vg.boxGradient(
      x + s.xOffset,
      y + s.yOffset,
      w + s.widthOffset,
      h + s.heightOffset,
      s.cornerRadius,
      s.feather,
      s.color,
      black(0),
    )
    vg.beginPath()
    vg.rect(
      x + s.xOffset - s.feather * 2,
      y + s.yOffset - s.feather * 2,
      w + s.widthOffset + s.feather * 4,
      h + s.heightOffset + s.feather * 4,
    )
    vg.fillPaint(shadow)
    vg.fill()

proc drawLabel*(
    vg: NVGContext,
    x, y, w, h: float,
    label: string,
    state: WidgetState = wsNormal,
    style: LabelStyle,
) =
  alias(s, style)
  let (x, y, w, h) = snapToGrid(x, y, w, h)
  let textBoxX = x + s.padHoriz
  let textBoxW = w - s.padHoriz * 2
  let textBoxY = y
  let textBoxH = h
  let color =
    case state
    of wsNormal: s.color
    of wsHover: s.colorHover
    of wsDown, wsActiveDown: s.colorDown
    of wsActive: s.colorActive
    of wsActiveHover: s.colorActiveHover
    of wsDisabled: s.colorDisabled
  vg.useFont(s.fontSize, name = s.fontFace, horizAlign = s.align)
  vg.fillColor(color)
  if s.multiLine:
    nanovg.textBox(
      vg,
      textBoxX.float32,
      (textBoxY + textBoxH * s.vertAlignFactor).float32,
      textBoxW.float32,
      label,
    )
  else:
    var tx =
      case s.align
      of haLeft:
        textBoxX
      of haCenter:
        textBoxX + textBoxW * 0.5
      of haRight:
        textBoxX + textBoxW
    discard nanovg.text(
      vg, tx.float32, (textBoxY + textBoxH * s.vertAlignFactor).float32, label
    )

proc drawCursor*(vg: NVGContext, x, y1, y2: float, color: Color, width: float) =
  vg.beginPath()
  vg.strokeColor(color)
  vg.strokeWidth(width)
  vg.moveTo(x + 0.5, y1)
  vg.lineTo(x + 0.5, y2)
  vg.stroke()

proc rightClippedRoundedRect*(
    vg: NVGContext, x, y, w, h, r, clipW: float, grouping: WidgetGrouping = wgNone
) =
  vg.beginPath()
  if grouping == wgMiddle:
    vg.rect(x, y, clipW, h)
  else:
    vg.roundedRect(x, y, w, h, r)
    vg.intersectScissor(x, y, clipW, h)

proc horizLine*(vg: NVGContext, x, y, w: float) =
  vg.moveTo(x, y + 0.5)
  vg.lineTo(x + w, y + 0.5)

proc vertLine*(vg: NVGContext, x, y, h: float) =
  vg.moveTo(x + 0.5, y)
  vg.lineTo(x + 0.5, y + h)

proc drawImage*(vg: NVGContext, x, y, w, h: float, paint: Paint) =
  vg.save()
  let (x, y, w, h) = snapToGrid(x, y, w, h)
  vg.beginPath()
  vg.rect(x, y, w, h)
  vg.fillPaint(paint)
  vg.fill()
  vg.restore()
