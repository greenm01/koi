import std/options
import std/tables
import std/unicode
import std/math

import nanovg
import glfw

import koi/types
import koi/core
import koi/drawing
import koi/layout
import koi/input
import koi/defaults
import koi/internal/algorithms
import koi/widgets/common
import koi/widgets/scrollbar
import koi/utils

const TextVertAlignFactor = 0.55

# textArea()
proc textArea*(
    id: ItemId,
    x, y, w, h: float,
    text_out: var string,
    tooltip: string = "",
    disabled: bool = false,
    activate: bool = false,
    drawWidget: bool = true,
    constraint: Option[TextAreaConstraint] = TextAreaConstraint.none,
    style: TextAreaStyle = defaultTextAreaStyle(),
) =
  alias(ui, g_uiState)
  alias(s, style)
  alias(tab, ui.tabActivationState)

  discard ui.itemState.hasKeyOrPut(id, TextAreaStateVars())
  var ta = cast[TextAreaStateVars](ui.itemState[id])

  let (x, y) = addDrawOffset(x, y)

  # The text is displayed within this rectangle (used for drawing later)
  let (textBoxX, textBoxY, textBoxW, textBoxH) = snapToGrid(
    x = x + s.textPadHoriz,
    y = y + s.textPadVert,
    w = w - s.textPadHoriz * 2 - s.scrollBarWidth,
    h = h - s.textPadVert * 2,
  )

  var tabActivate = false

  if not ui.focusCaptured and ta.state == tasDefault:
    tabActivate = handleTabActivation(id)

    if isHit(x, y, w, h) or activate or tabActivate:
      markHot(id)
      if not disabled and
          ((ui.mbLeftDown and hasNoActiveItem()) or activate or tabActivate):
        markActive(id)
        clearCharBuf()
        clearEventBuf()
        ta.state = tasEditLMBPressed
        ta.activeItem = id
        ta.cursorPos = text_out.runeLen
        ta.displayStartRow = 0
        ta.originalText = text_out
        ta.selection.startPos = 0
        ta.selection.endPos = ta.cursorPos.Natural
        ui.focusCaptured = true

  proc exitEditMode() =
    ta.state = tasDefault
    ta.activeItem = 0
    ta.cursorPos = 0
    ta.selection = NoSelection
    ta.displayStartRow = 0
    ta.originalText = ""
    ui.focusCaptured = false
    cursorShape(csArrow)

  proc useTextFont() =
    g_nvgContext.useFont(s.textFontSize, name = s.textFontFace)

  var text = text_out
  var rows = text.textBreakLines(textBoxW)
  let rowHeight = s.textFontSize * s.textLineHeight
  let maxLen = if constraint.isSome: constraint.get.maxLen else: Natural.none

  proc fillRowGlyphs(row: types.TextRow, glyphs: var openArray[GlyphPosition]): int =
    let rowEnd = textAreaRowEndCursor(row)
    if rowEnd <= row.startPos:
      return 0

    useTextFont()
    g_nvgContext.textGlyphPositions(
      0, 0, text, startPos = row.startBytePos, endPos = row.endBytePos, glyphs
    )

  proc cursorPosAtMouse(mx, my: float): Natural =
    let rowIndex =
      textAreaRowAtY(rows.len.Natural, ta.displayStartRow, textBoxY, rowHeight, my)
    let row = rows[rowIndex]
    var glyphs: array[1024, GlyphPosition]
    let glyphCount = fillRowGlyphs(row, glyphs)
    if glyphCount <= 0:
      return row.startPos

    textAreaCursorPosAt(
      toOpenArray(glyphs, 0, glyphCount - 1),
      row.startPos,
      textAreaRowEndCursor(row),
      mx,
      textBoxX,
    )

  proc keepCursorVisible() =
    let rowIndex = textAreaRowForCursor(rows, ta.cursorPos)
    ta.displayStartRow = textAreaDisplayStartRowForCursor(
      rows.len.Natural, rowIndex, textBoxH, rowHeight, ta.displayStartRow
    )

  # Hit testing
  if ta.activeItem == id:
    markHot(id)
    markActive(id)
    cursorShape(csIBeam)

    if ta.state == tasEditLMBPressed:
      if not ui.mbLeftDown:
        ta.state = tasEdit

    # LMB pressed outside the text area exits edit mode
    if ui.mbLeftDown and not mouseInside(x, y, w, h):
      exitEditMode()
    elif ui.mbLeftDown and mouseInside(textBoxX, textBoxY, textBoxW, textBoxH):
      ta.cursorPos = cursorPosAtMouse(ui.mx, ui.my)
      ta.selection = NoSelection

    # Event handling
    if ui.hasEvent and (not ui.eventHandled) and ui.currEvent.kind == ekKey and
        ui.currEvent.action in {kaDown, kaRepeat}:
      alias(shortcuts, g_textFieldEditShortcuts)
      let sc = mkKeyShortcut(ui.currEvent.key, ui.currEvent.mods)
      markEventHandled()

      let res =
        handleCommonTextEditingShortcuts(sc, text, ta.cursorPos, ta.selection, maxLen)
      if res.isSome:
        text = res.get.text
        ta.cursorPos = res.get.cursorPos
        ta.selection = res.get.selection
        rows = text.textBreakLines(textBoxW)
      else:
        # TextArea specific shortcuts
        if sc in shortcuts[tesAccept]:
          exitEditMode()
        elif sc in shortcuts[tesCancel]:
          text = ta.originalText
          exitEditMode()
        elif sc in shortcuts[tesInsertNewline]:
          let res = insertString(text, ta.cursorPos, ta.selection, "\n", maxLen)
          text = res.text
          ta.cursorPos = res.cursorPos
          ta.selection = res.selection
          rows = text.textBreakLines(textBoxW)

    if not charBufEmpty():
      var newChars = consumeCharBuf()
      let res = insertString(text, ta.cursorPos, ta.selection, newChars, maxLen)
      text = res.text
      ta.cursorPos = res.cursorPos
      ta.selection = res.selection
      rows = text.textBreakLines(textBoxW)
      markEventHandled()

    if ta.activeItem == id:
      ta.cursorPos = min(ta.cursorPos, text.runeLen.Natural)
      keepCursorVisible()

  text_out = text

  # Draw
  addDrawLayer(ui.currentLayer, vg):
    let (rx, ry, rw, rh) = snapToGrid(x, y, w, h, s.bgStrokeWidth)
    let editing = ta.activeItem == id

    if drawWidget:
      vg.beginPath()
      vg.roundedRect(rx, ry, rw, rh, s.bgCornerRadius)
      vg.fillColor(if editing: s.bgFillColorActive else: s.bgFillColor)
      vg.fill()

    vg.save()
    vg.intersectScissor(textBoxX, textBoxY, textBoxW, textBoxH)

    var ty = textBoxY + rowHeight * TextVertAlignFactor - ta.displayStartRow * rowHeight

    useTextFont()
    vg.fillColor(if editing: s.textColorActive else: s.textColor)

    for row in rows:
      if ty + rowHeight > textBoxY and ty < textBoxY + textBoxH:
        discard vg.text(
          textBoxX, ty, text, startPos = row.startBytePos, endPos = row.endBytePos
        )
      ty += rowHeight

    if editing:
      let rowIndex = textAreaRowForCursor(rows, ta.cursorPos)
      let row = rows[rowIndex]
      let cursorY1 = textBoxY + (rowIndex.float - ta.displayStartRow) * rowHeight
      let cursorY2 = cursorY1 + rowHeight

      if cursorY2 > textBoxY and cursorY1 < textBoxY + textBoxH:
        var glyphs: array[1024, GlyphPosition]
        let glyphCount = fillRowGlyphs(row, glyphs)
        let cursorX =
          if glyphCount <= 0:
            textBoxX
          else:
            textAreaCursorX(
              toOpenArray(glyphs, 0, glyphCount - 1),
              row.startPos,
              ta.cursorPos,
              textBoxX,
            )
        vg.drawCursor(cursorX, cursorY1, cursorY2, s.cursorColor, s.cursorWidth)

    vg.restore()

  if isHot(id):
    handleTooltip(id, tooltip)
  tab.prevItem = id

template textArea*(
    x, y, w, h: float,
    text: var string,
    tooltip: string = "",
    disabled: bool = false,
    activate: bool = false,
    drawWidget: bool = true,
    constraint: Option[TextAreaConstraint] = TextAreaConstraint.none,
    style: TextAreaStyle = defaultTextAreaStyle(),
) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)
  textArea(
    id, x, y, w, h, text, tooltip, disabled, activate, drawWidget, constraint, style
  )

template textArea*(
    text: var string,
    tooltip: string = "",
    disabled: bool = false,
    activate: bool = false,
    drawWidget: bool = true,
    constraint: Option[TextAreaConstraint] = TextAreaConstraint.none,
    style: TextAreaStyle = defaultTextAreaStyle(),
) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)
  autoLayoutPre()
  textArea(
    id,
    g_uiState.autoLayoutState.x,
    autoLayoutNextY(),
    autoLayoutNextItemWidth(),
    autoLayoutNextItemHeight(),
    text,
    tooltip,
    disabled,
    activate,
    drawWidget,
    constraint,
    style,
  )
  autoLayoutPost()
