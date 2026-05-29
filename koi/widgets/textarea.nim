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
import koi/rect
import koi/input
import koi/defaults
import koi/internal/algorithms
import koi/widgets/common
import koi/widgets/scrollbar
import koi/utils

const
  TextVertAlignFactor = 0.55
  TextAreaScrollRowsPerTick = 3.0

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
    style: TextAreaStyle = borrowDefaultTextAreaStyle(),
) =
  alias(ui, g_uiState)
  alias(s, style)
  alias(tab, ui.tabActivationState)

  discard ui.itemState.hasKeyOrPut(id, TextAreaStateVars())
  var ta = cast[TextAreaStateVars](ui.itemState[id])

  let (x, y) = addDrawOffset(x, y)
  let slot = layoutSlot(id, rect(x, y, w, h))
  let hitBounds = slot.previousBounds

  # The text is displayed within this rectangle (used for drawing later)
  let (textBoxX, textBoxY, textBoxW, textBoxH) = snapToGrid(
    x = hitBounds.x + s.textPadHoriz,
    y = hitBounds.y + s.textPadVert,
    w = hitBounds.w - s.textPadHoriz * 2 - s.scrollBarWidth,
    h = hitBounds.h - s.textPadVert * 2,
  )

  var tabActivate = false

  if not ui.focusCaptured and ta.state == tasDefault:
    tabActivate = handleTabActivation(id)

    if isHit(hitBounds.x, hitBounds.y, hitBounds.w, hitBounds.h) or activate or
        tabActivate:
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
        if ui.mbLeftDown and not activate and not tabActivate:
          ta.selection = NoSelection
        else:
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
  let scrollBarId = hashId($id & ":scrollBar")

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

  proc cursorXAt(pos: Natural): float =
    let rowIndex = textAreaRowForCursor(rows, pos)
    let row = rows[rowIndex]
    var glyphs: array[1024, GlyphPosition]
    let glyphCount = fillRowGlyphs(row, glyphs)
    if glyphCount <= 0:
      return textBoxX

    textAreaCursorX(toOpenArray(glyphs, 0, glyphCount - 1), row.startPos, pos, textBoxX)

  proc cursorPosAtRowX(rowIndex: Natural, cursorX: float): Natural =
    let row = rows[rowIndex]
    var glyphs: array[1024, GlyphPosition]
    let glyphCount = fillRowGlyphs(row, glyphs)
    if glyphCount <= 0:
      return row.startPos

    textAreaCursorPosAt(
      toOpenArray(glyphs, 0, glyphCount - 1),
      row.startPos,
      textAreaRowEndCursor(row),
      cursorX,
      textBoxX,
    )

  proc keepCursorVisible() =
    let rowIndex = textAreaRowForCursor(rows, ta.cursorPos)
    ta.displayStartRow = textAreaDisplayStartRowForCursor(
      rows.len.Natural, rowIndex, textBoxH, rowHeight, ta.displayStartRow
    )

  proc clampDisplayStart() =
    ta.displayStartRow = textAreaScrollDisplayStart(
      rows.len.Natural, textBoxH, rowHeight, ta.displayStartRow, 0
    )

  proc setCursor(newCursorPos: Natural, selecting: bool, preserveX: bool = false) =
    if selecting:
      ta.selection = updateSelection(ta.selection, ta.cursorPos, newCursorPos)
    else:
      ta.selection = NoSelection
    ta.cursorPos = min(newCursorPos, text.runeLen.Natural)
    if not preserveX:
      ta.lastCursorXPos = float.none

  proc moveCursorByRows(deltaRows: int, selecting: bool) =
    let
      sourceRow = textAreaRowForCursor(rows, ta.cursorPos)
      targetRow = textAreaRowByDelta(rows.len.Natural, sourceRow, deltaRows)
      cursorX =
        if ta.lastCursorXPos.isSome:
          ta.lastCursorXPos.get
        else:
          cursorXAt(ta.cursorPos)

    ta.lastCursorXPos = cursorX.some
    setCursor(cursorPosAtRowX(targetRow, cursorX), selecting, preserveX = true)

  # Hit testing
  if ta.activeItem == id:
    markHot(id)
    if not isActive(scrollBarId):
      markActive(id)
    cursorShape(csIBeam)
    var cursorChanged = false

    proc scrollRows(deltaRows: float) =
      ta.displayStartRow = textAreaScrollDisplayStart(
        rows.len.Natural, textBoxH, rowHeight, ta.displayStartRow, deltaRows
      )

    # LMB pressed outside the text area exits edit mode
    if ui.mbLeftDown and
        not mouseInside(hitBounds.x, hitBounds.y, hitBounds.w, hitBounds.h):
      exitEditMode()
    elif ta.state in {tasEditLMBPressed, tasEdit} and ui.mbLeftDown and
        mouseInside(textBoxX, textBoxY, textBoxW, textBoxH):
      let cursorPos = cursorPosAtMouse(ui.mx, ui.my)
      ta.cursorPos = cursorPos
      ta.selection = TextSelection(startPos: cursorPos.int, endPos: cursorPos)
      ta.lastCursorXPos = float.none
      ta.state = tasDragStart
      cursorChanged = true
      if ui.hasEvent and not ui.eventHandled and ui.currEvent.kind == ekMouseButton:
        markEventHandled()
    elif ta.state == tasDragStart:
      if ui.mbLeftDown:
        if ui.my < textBoxY:
          scrollRows(-1)
          requestFrames()
        elif ui.my > textBoxY + textBoxH:
          scrollRows(1)
          requestFrames()

        let cursorPos = cursorPosAtMouse(ui.mx, ui.my)
        ta.cursorPos = cursorPos
        ta.selection.endPos = cursorPos
        ta.lastCursorXPos = float.none
        cursorChanged = true
      else:
        if not hasSelection(ta.selection):
          ta.selection = NoSelection
        ta.state = tasEdit

    if ta.state == tasEditLMBPressed and not ui.mbLeftDown:
      ta.state = tasEdit

    if ui.hasEvent and not ui.eventHandled and ui.currEvent.kind == ekScroll and
        mouseInside(hitBounds.x, hitBounds.y, hitBounds.w, hitBounds.h):
      scrollRows(-ui.currEvent.oy * TextAreaScrollRowsPerTick)
      markEventHandled()

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
        ta.lastCursorXPos = float.none
        rows = text.textBreakLines(textBoxW)
        cursorChanged = true
      else:
        # TextArea specific shortcuts
        if sc in shortcuts[tesAccept]:
          exitEditMode()
        elif sc in shortcuts[tesCancel]:
          text = ta.originalText
          rows = text.textBreakLines(textBoxW)
          exitEditMode()
        elif sc in shortcuts[tesCursorToLineStart]:
          setCursor(textAreaLineStartCursor(rows, ta.cursorPos), selecting = false)
          cursorChanged = true
        elif sc in shortcuts[tesCursorToLineEnd]:
          setCursor(textAreaLineEndCursor(rows, ta.cursorPos), selecting = false)
          cursorChanged = true
        elif sc in shortcuts[tesSelectionToLineStart]:
          setCursor(textAreaLineStartCursor(rows, ta.cursorPos), selecting = true)
          cursorChanged = true
        elif sc in shortcuts[tesSelectionToLineEnd]:
          setCursor(textAreaLineEndCursor(rows, ta.cursorPos), selecting = true)
          cursorChanged = true
        elif sc in shortcuts[tesCursorToPreviousLine]:
          moveCursorByRows(-1, selecting = false)
          cursorChanged = true
        elif sc in shortcuts[tesCursorToNextLine]:
          moveCursorByRows(1, selecting = false)
          cursorChanged = true
        elif sc in shortcuts[tesSelectionToPreviousLine]:
          moveCursorByRows(-1, selecting = true)
          cursorChanged = true
        elif sc in shortcuts[tesSelectionToNextLine]:
          moveCursorByRows(1, selecting = true)
          cursorChanged = true
        elif sc in shortcuts[tesCursorPageUp]:
          let rowsPerPage = textAreaVisibleRows(textBoxH, rowHeight).int
          moveCursorByRows(-rowsPerPage, selecting = false)
          cursorChanged = true
        elif sc in shortcuts[tesCursorPageDown]:
          let rowsPerPage = textAreaVisibleRows(textBoxH, rowHeight).int
          moveCursorByRows(rowsPerPage, selecting = false)
          cursorChanged = true
        elif sc in shortcuts[tesSelectionPageUp]:
          let rowsPerPage = textAreaVisibleRows(textBoxH, rowHeight).int
          moveCursorByRows(-rowsPerPage, selecting = true)
          cursorChanged = true
        elif sc in shortcuts[tesSelectionPageDown]:
          let rowsPerPage = textAreaVisibleRows(textBoxH, rowHeight).int
          moveCursorByRows(rowsPerPage, selecting = true)
          cursorChanged = true
        elif sc in shortcuts[tesInsertNewline]:
          let res = insertString(text, ta.cursorPos, ta.selection, "\n", maxLen)
          text = res.text
          ta.cursorPos = res.cursorPos
          ta.selection = res.selection
          ta.lastCursorXPos = float.none
          rows = text.textBreakLines(textBoxW)
          cursorChanged = true

    if not charBufEmpty():
      var newChars = consumeCharBuf()
      let res = insertString(text, ta.cursorPos, ta.selection, newChars, maxLen)
      text = res.text
      ta.cursorPos = res.cursorPos
      ta.selection = res.selection
      ta.lastCursorXPos = float.none
      rows = text.textBreakLines(textBoxW)
      cursorChanged = true
      markEventHandled()

    if ta.activeItem == id:
      ta.cursorPos = min(ta.cursorPos, text.runeLen.Natural)
      clampDisplayStart()
      if cursorChanged:
        keepCursorVisible()

  clampDisplayStart()

  let visibleRows = textAreaVisibleRows(textBoxH, rowHeight)
  if rows.len.Natural > visibleRows:
    var scrollValue = ta.displayStartRow
    let
      maxStart = textAreaMaxDisplayStart(rows.len.Natural, textBoxH, rowHeight)
      thumbSize =
        if rows.len == 0:
          0.0
        else:
          visibleRows.float * (maxStart / rows.len.float)

    vertScrollBar(
      scrollBarId,
      x = x + w - s.scrollBarWidth,
      y = y + s.textPadVert,
      w = s.scrollBarWidth,
      h = h - s.textPadVert * 2,
      startVal = 0,
      endVal = maxStart,
      value_out = scrollValue,
      thumbSize = thumbSize,
      clickStep = visibleRows.float,
      style = if ta.activeItem == id: s.scrollBarStyleEdit else: s.scrollBarStyleNormal,
      allowFocusCaptured = ta.activeItem == id,
    )
    ta.displayStartRow =
      textAreaScrollDisplayStart(rows.len.Natural, textBoxH, rowHeight, scrollValue, 0)

  text_out = text

  # Draw
  addLayoutDrawLayer(ui.currentLayer, slot.nodeId, vg, bounds):
    let
      (rx, ry, rw, rh) =
        snapToGrid(bounds.x, bounds.y, bounds.w, bounds.h, s.bgStrokeWidth)
      (drawTextBoxX, drawTextBoxY, drawTextBoxW, drawTextBoxH) = snapToGrid(
        x = bounds.x + s.textPadHoriz,
        y = bounds.y + s.textPadVert,
        w = bounds.w - s.textPadHoriz * 2 - s.scrollBarWidth,
        h = bounds.h - s.textPadVert * 2,
      )
      drawRows = text.textBreakLines(drawTextBoxW)
    let editing = ta.activeItem == id

    proc fillDrawRowGlyphs(
        row: types.TextRow, glyphs: var openArray[GlyphPosition]
    ): int =
      let rowEnd = textAreaRowEndCursor(row)
      if rowEnd <= row.startPos:
        return 0

      useTextFont()
      g_nvgContext.textGlyphPositions(
        0, 0, text, startPos = row.startBytePos, endPos = row.endBytePos, glyphs
      )

    if drawWidget:
      vg.beginPath()
      vg.roundedRect(rx, ry, rw, rh, s.bgCornerRadius)
      vg.fillColor(if editing: s.bgFillColorActive else: s.bgFillColor)
      vg.fill()

    vg.save()
    vg.intersectScissor(drawTextBoxX, drawTextBoxY, drawTextBoxW, drawTextBoxH)

    var ty =
      drawTextBoxY + rowHeight * TextVertAlignFactor - ta.displayStartRow * rowHeight
    var rowY = drawTextBoxY - ta.displayStartRow * rowHeight

    useTextFont()

    if editing and hasSelection(ta.selection):
      for row in drawRows:
        if rowY + rowHeight > drawTextBoxY and rowY < drawTextBoxY + drawTextBoxH:
          let rowSelection = textAreaSelectionForRow(row, ta.selection)
          if rowSelection.active:
            var glyphs: array[1024, GlyphPosition]
            let glyphCount = fillDrawRowGlyphs(row, glyphs)
            let x1 =
              if glyphCount <= 0:
                drawTextBoxX
              else:
                textAreaCursorX(
                  toOpenArray(glyphs, 0, glyphCount - 1),
                  row.startPos,
                  rowSelection.startPos,
                  drawTextBoxX,
                )
            let x2 =
              if glyphCount <= 0:
                drawTextBoxX
              else:
                textAreaCursorX(
                  toOpenArray(glyphs, 0, glyphCount - 1),
                  row.startPos,
                  rowSelection.endPos,
                  drawTextBoxX,
                )

            vg.beginPath()
            vg.rect(x1, rowY, max(x2 - x1, s.cursorWidth), rowHeight)
            vg.fillColor(s.selectionColor)
            vg.fill()
        rowY += rowHeight

    vg.fillColor(if editing: s.textColorActive else: s.textColor)

    for row in drawRows:
      if ty + rowHeight > drawTextBoxY and ty < drawTextBoxY + drawTextBoxH:
        discard vg.text(
          drawTextBoxX, ty, text, startPos = row.startBytePos, endPos = row.endBytePos
        )
      ty += rowHeight

    if editing and drawRows.len > 0:
      let rowIndex = textAreaRowForCursor(drawRows, ta.cursorPos)
      let row = drawRows[rowIndex]
      let cursorY1 = drawTextBoxY + (rowIndex.float - ta.displayStartRow) * rowHeight
      let cursorY2 = cursorY1 + rowHeight

      if cursorY2 > drawTextBoxY and cursorY1 < drawTextBoxY + drawTextBoxH:
        var glyphs: array[1024, GlyphPosition]
        let glyphCount = fillDrawRowGlyphs(row, glyphs)
        let cursorX =
          if glyphCount <= 0:
            drawTextBoxX
          else:
            textAreaCursorX(
              toOpenArray(glyphs, 0, glyphCount - 1),
              row.startPos,
              ta.cursorPos,
              drawTextBoxX,
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
    style: TextAreaStyle = borrowDefaultTextAreaStyle(),
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
    style: TextAreaStyle = borrowDefaultTextAreaStyle(),
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
