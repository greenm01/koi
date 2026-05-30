proc textFieldWithSlot*(
    slot: LayoutSlot,
    id: ItemId,
    text_out: var string,
    tooltip: string = "",
    disabled: bool = false,
    activate: bool = false,
    drawWidget: bool = true,
    constraint: Option[TextFieldConstraint] = TextFieldConstraint.none,
    style: TextFieldStyle = borrowDefaultTextFieldStyle(),
    filter: TextFieldFilterKind = tffAny,
) =
  const MaxTextRuneLen = 1024

  assert text_out.runeLen <= MaxTextRuneLen
  var text =
    if text_out.runeLen > MaxTextRuneLen:
      text_out.runeSubStr(0, MaxTextRuneLen)
    else:
      text_out

  alias(ui, g_uiState)
  alias(tf, ui.textFieldState)
  let s =
    if style == nil:
      borrowDefaultTextFieldStyle()
    else:
      style
  alias(tab, ui.tabActivationState)

  let hitBounds = slot.previousBounds

  let (textBoxX, _, textBoxW, _) = snapToGrid(
    x = hitBounds.x + s.textPadHoriz,
    y = hitBounds.y,
    w = hitBounds.w - s.textPadHoriz * 2,
    h = hitBounds.h,
  )

  var glyphs: array[MaxTextRuneLen, GlyphPosition]
  var tabActivate = false

  if not ui.focusCaptured and tf.state == tfsDefault:
    tabActivate = handleTabActivation(id)

    if isHit(hitBounds.x, hitBounds.y, hitBounds.w, hitBounds.h) or activate or
        tabActivate:
      markHot(id)
      if not disabled and
          ((ui.mbLeftDown and hasNoActiveItem()) or activate or tabActivate):
        textFieldEnterEditMode(id, text, textBoxX)
        tf.state = tfsEditLMBPressed

  proc exitEditMode() =
    textFieldExitEditMode(id, textBoxX)

  proc useTextFont() =
    g_nvgContext.useFont(s.textFontSize, name = s.textFontFace)

  proc calcGlyphPos() =
    useTextFont()
    discard g_nvgContext.textGlyphPositions(0, 0, text, glyphs)

  func enforceConstraint(text, originalText: string): string =
    var text = unicode.strip(text)
    result = text
    if constraint.isSome:
      alias(c, constraint.get)
      case c.kind
      of tckString:
        if text.len < c.minLen:
          result = originalText
      of tckInteger:
        try:
          let i = parseInt(text)
          if i < c.minInt:
            result = $c.minInt
          elif i > c.maxInt:
            result = $c.maxInt
          else:
            result = $i
        except ValueError:
          result = originalText

  proc cursorPosAt(x: float): Natural =
    textFieldCursorPosAt(
      glyphs, text.runeLen.Natural, tf.displayStartPos, tf.displayStartX, x
    )

  proc cursorXPos(): float =
    textFieldCursorX(
      glyphs,
      text.runeLen.Natural,
      tf.cursorPos,
      TextFieldView(
        displayStartPos: tf.displayStartPos, displayStartX: tf.displayStartX
      ),
    )

  if tf.activeItem == id and tf.state >= tfsEditLMBPressed:
    calcGlyphPos()

    markHot(id)
    markActive(id)
    cursorShape(csIBeam)

    if tf.state == tfsEditLMBPressed:
      if not ui.mbLeftDown:
        tf.state = tfsEdit
    elif tf.state == tfsDragStart:
      let cursorX = cursorXPos()
      if ui.mbLeftDown:
        if (ui.mx < textBoxX and cursorX < textBoxX + 10) or (
          ui.mx > textBoxX + textBoxW - ScrollRightOffset and
          cursorX > textBoxX + textBoxW - ScrollRightOffset - 10
        ):
          ui.t0 = core.currentTime()
          tf.state = tfsDragDelay
        else:
          let mouseCursorPos = cursorPosAt(ui.mx)
          tf.selection =
            updateSelection(tf.selection, tf.cursorPos, newCursorPos = mouseCursorPos)
          tf.cursorPos = mouseCursorPos
      else:
        tf.state = tfsEdit
    elif tf.state == tfsDragDelay:
      if ui.mbLeftDown:
        var dx = ui.mx - textBoxX
        if dx > 0:
          dx = (textBoxX + textBoxW - ScrollRightOffset) - ui.mx
        if dx < 0:
          if core.currentTime() - ui.t0 > TextFieldScrollDelay / (-dx / 10):
            tf.state = tfsDragScroll
        else:
          tf.state = tfsDragStart
      else:
        tf.state = tfsEdit
    elif tf.state == tfsDragScroll:
      if ui.mbLeftDown:
        let newCursorPos =
          if ui.mx < textBoxX:
            max(tf.cursorPos - 1, 0)
          elif ui.mx > textBoxX + textBoxW - ScrollRightOffset:
            min(tf.cursorPos + 1, text.runeLen)
          else:
            tf.cursorPos
        tf.selection = updateSelection(tf.selection, tf.cursorPos, newCursorPos.Natural)
        tf.cursorPos = newCursorPos.Natural
        ui.t0 = core.currentTime()
        tf.state = tfsDragDelay
      else:
        tf.state = tfsEdit
    elif tf.state == tfsDoubleClicked:
      if not ui.mbLeftDown:
        tf.state = tfsEdit
    else:
      if ui.mbLeftDown:
        if mouseInside(hitBounds.x, hitBounds.y, hitBounds.w, hitBounds.h):
          tf.selection = NoSelection
          tf.cursorPos = cursorPosAt(ui.mx)
          if isDoubleClick():
            let startPos = findPrevWordStart(text, tf.cursorPos)
            var endPos = findNextWordEnd(text, tf.cursorPos)
            # findNextWordEnd skips trailing whitespace/punctuation (it is a
            # cursor-nav helper); for word selection trim that back so a
            # double-click selects just the word, not the following space.
            while endPos > startPos and not text.runeAtPos(endPos - 1).isAlphanumeric:
              dec endPos
            tf.selection.startPos = startPos.int
            tf.selection.endPos = endPos.Natural
            tf.cursorPos = tf.selection.endPos
            tf.state = tfsDoubleClicked
          else:
            ui.x0 = ui.mx
            tf.state = tfsDragStart
        else:
          text = enforceConstraint(text, tf.originalText)
          exitEditMode()

    var maxLenOpt = MaxTextRuneLen.Natural.some
    if constraint.isSome and constraint.get.kind == tckString:
      maxLenOpt = min(constraint.get.maxLen.get, MaxTextRuneLen).Natural.some

    if ui.hasEvent and (not ui.eventHandled) and ui.currEvent.kind == ekKey and
        ui.currEvent.action in {kaDown, kaRepeat}:
      alias(shortcuts, g_textFieldEditShortcuts)
      let sc = mkKeyShortcut(ui.currEvent.key, ui.currEvent.mods)
      markEventHandled()
      let res = handleCommonTextEditingShortcuts(
        sc, text, tf.cursorPos, tf.selection, maxLenOpt, filter
      )
      if res.isSome:
        text = res.get.text
        tf.cursorPos = res.get.cursorPos
        tf.selection = res.get.selection
      else:
        if sc in shortcuts[tesCursorToLineStart]:
          tf.cursorPos = 0
          tf.selection = NoSelection
        elif sc in shortcuts[tesCursorToLineEnd]:
          tf.cursorPos = text.runeLen.Natural
          tf.selection = NoSelection
        elif sc in shortcuts[tesSelectionToLineStart]:
          let newCursorPos = 0.Natural
          tf.selection = updateSelection(tf.selection, tf.cursorPos, newCursorPos)
          tf.cursorPos = newCursorPos
        elif sc in shortcuts[tesSelectionToLineEnd]:
          let newCursorPos = text.runeLen.Natural
          tf.selection = updateSelection(tf.selection, tf.cursorPos, newCursorPos)
          tf.cursorPos = newCursorPos
        elif sc in shortcuts[tesDeleteToLineStart] or sc in shortcuts[
            tesDeleteToLineEnd
        ]:
          if hasSelection(tf.selection):
            let res = deleteSelection(text, tf.selection, tf.cursorPos)
            text = res.text
            tf.cursorPos = res.cursorPos
            tf.selection = res.selection
          else:
            if sc in shortcuts[tesDeleteToLineStart]:
              text = text.runeSubStr(tf.cursorPos)
              tf.cursorPos = 0
            else:
              text = text.runeSubStr(0, tf.cursorPos)
        elif sc in shortcuts[tesPrevTextField]:
          text = enforceConstraint(text, tf.originalText)
          exitEditMode()
          tab.activatePrev = true
          tab.itemToActivate = tab.prevItem
        elif sc in shortcuts[tesNextTextField]:
          text = enforceConstraint(text, tf.originalText)
          exitEditMode()
          tab.activateNext = true
        elif sc in shortcuts[tesAccept]:
          text = enforceConstraint(text, tf.originalText)
          exitEditMode()
        elif sc in shortcuts[tesCancel]:
          text = tf.originalText
          exitEditMode()

    if not charBufEmpty():
      let newChars = filterTextInputForInsert(
        text, tf.cursorPos, tf.selection, consumeCharBuf(), filter
      )
      let res = insertString(text, tf.cursorPos, tf.selection, newChars, maxLenOpt)
      text = res.text
      tf.cursorPos = res.cursorPos
      tf.selection = res.selection
      markEventHandled()

    let textLen = text.runeLen
    if textLen == 0:
      tf.cursorPos = 0
      tf.selection = NoSelection
      tf.displayStartPos = 0
      tf.displayStartX = textBoxX
    else:
      calcGlyphPos()
      if glyphs[textLen - 1].maxX < textBoxW:
        tf.displayStartPos = 0
        tf.displayStartX = textBoxX
      else:
        let view = textFieldViewForCursor(
          glyphs,
          textLen.Natural,
          tf.cursorPos,
          textBoxX,
          textBoxW,
          TextFieldView(
            displayStartPos: tf.displayStartPos, displayStartX: tf.displayStartX
          ),
        )
        tf.displayStartPos = view.displayStartPos
        tf.displayStartX = view.displayStartX

  text_out = text
  let editing = tf.activeItem == id

  addLayoutDrawLayer(ui.currentLayer, slot.nodeId, vg, bounds):
    vg.save()
    let
      (x, y, w, h) = snapToGrid(bounds.x, bounds.y, bounds.w, bounds.h, s.bgStrokeWidth)
      (drawTextBoxX, drawTextBoxY, drawTextBoxW, drawTextBoxH) = snapToGrid(
        x = bounds.x + s.textPadHoriz,
        y = bounds.y,
        w = bounds.w - s.textPadHoriz * 2,
        h = bounds.h,
      )
      drawView = TextFieldView(
        displayStartPos: tf.displayStartPos,
        displayStartX: drawTextBoxX + (tf.displayStartX - textBoxX),
      )
    let state =
      if disabled:
        wsDisabled
      elif isHot(id) and hasNoActiveItem():
        wsHover
      elif editing:
        wsActive
      else:
        wsNormal
    let (fillColor, _) =
      case state
      of wsNormal:
        (s.bgFillColor, s.bgStrokeColor)
      of wsHover:
        (s.bgFillColorHover, s.bgStrokeColorHover)
      of wsActive, wsActiveHover, wsActiveDown, wsDown:
        (s.bgFillColorActive, s.bgStrokeColorActive)
      of wsDisabled:
        (s.bgFillColorDisabled, s.bgStrokeColorDisabled)
    var textX = drawTextBoxX
    var textY = y + h * TextVertAlignFactor
    if drawWidget:
      vg.beginPath()
      vg.roundedRect(x, y, w, h, s.bgCornerRadius)
      vg.fillColor(fillColor)
      vg.fill()
    elif editing:
      vg.beginPath()
      vg.rect(
        drawTextBoxX,
        drawTextBoxY + s.textPadVert,
        drawTextBoxW,
        drawTextBoxH - s.textPadVert * 2,
      )
      vg.fillColor(fillColor)
      vg.fill()
    let xPad = 3.0
    vg.intersectScissor(
      drawTextBoxX - xPad, drawTextBoxY, drawTextBoxW + xPad, drawTextBoxH
    )
    if editing:
      textX = drawView.displayStartX
      if hasSelection(tf.selection):
        var ns = normaliseSelection(tf.selection)
        ns.endPos = max(ns.endPos - 1, 0).Natural
        let
          x1 =
            if ns.startPos == 0:
              drawView.displayStartX
            else:
              drawView.displayStartX + glyphs[ns.startPos].x -
                glyphs[drawView.displayStartPos].x
          x2 =
            drawView.displayStartX + glyphs[ns.endPos].maxX -
            glyphs[drawView.displayStartPos].x
        vg.beginPath()
        vg.rect(
          x1, drawTextBoxY + s.textPadVert, x2 - x1, drawTextBoxH - s.textPadVert * 2
        )
        vg.fillColor(s.selectionColor)
        vg.fill()
    let textColor =
      case state
      of wsNormal: s.textColor
      of wsHover: s.textColorHover
      of wsActive, wsActiveHover, wsActiveDown, wsDown: s.textColorActive
      of wsDisabled: s.textColorDisabled
    vg.useFont(s.textFontSize, name = s.textFontFace)
    vg.fillColor(textColor)
    if text.len > 0:
      let displayStartPos = min(tf.displayStartPos, text.runeLen.Natural)
      discard vg.text(textX, textY, text.runeSubStr(displayStartPos))
    if editing:
      let cursorX =
        textFieldCursorX(glyphs, text.runeLen.Natural, tf.cursorPos, drawView)
      vg.drawCursor(
        cursorX,
        drawTextBoxY + s.textPadVert,
        drawTextBoxY + drawTextBoxH - s.textPadVert,
        s.cursorColor,
        s.cursorWidth,
      )
    vg.restore()

  if isHot(id):
    handleTooltip(id, tooltip)
  tab.prevItem = id

# textField()
