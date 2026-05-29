import std/options
import std/tables
import std/unicode
import std/strutils

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
import koi/utils

const
  TextFieldScrollDelay = 0.1
  TextVertAlignFactor = 0.55
  ScrollRightOffset = 10

# textFieldEnterEditMode()
proc textFieldEnterEditMode(id: ItemId, text: string, startX: float) =
  alias(ui, g_uiState)
  alias(tf, ui.textFieldState)

  markActive(id)
  clearCharBuf()
  clearEventBuf()

  tf.state = tfsEdit
  tf.activeItem = id
  tf.cursorPos = text.runeLen
  tf.displayStartPos = 0
  tf.displayStartX = startX
  tf.originalText = text
  tf.selection.startPos = 0
  tf.selection.endPos = tf.cursorPos.Natural

  ui.focusCaptured = true

# textFieldExitEditMode*()
proc textFieldExitEditMode*(id: ItemId = 0, startX: float = 0) =
  alias(ui, g_uiState)
  alias(tf, ui.textFieldState)

  clearEventBuf()
  clearCharBuf()

  tf.state = tfsDefault
  tf.activeItem = 0
  tf.cursorPos = 0
  tf.selection = NoSelection
  tf.displayStartPos = 0
  tf.displayStartX = startX
  tf.originalText = ""

  ui.focusCaptured = false
  cursorShape(csArrow)

# textField()
proc textField*(
    id: ItemId,
    x, y, w, h: float,
    text_out: var string,
    tooltip: string = "",
    disabled: bool = false,
    activate: bool = false,
    drawWidget: bool = true,
    constraint: Option[TextFieldConstraint] = TextFieldConstraint.none,
    style: TextFieldStyle = defaultTextFieldStyle(),
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
  alias(s, style)
  alias(tab, ui.tabActivationState)

  let (x, y) = addDrawOffset(x, y)

  let (textBoxX, textBoxY, textBoxW, textBoxH) =
    snapToGrid(x = x + s.textPadHoriz, y = y, w = w - s.textPadHoriz * 2, h = h)

  var glyphs: array[MaxTextRuneLen, GlyphPosition]
  var tabActivate = false

  if not ui.focusCaptured and tf.state == tfsDefault:
    tabActivate = handleTabActivation(id)

    if isHit(x, y, w, h) or activate or tabActivate:
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
        if mouseInside(x, y, w, h):
          tf.selection = NoSelection
          tf.cursorPos = cursorPosAt(ui.mx)
          if isDoubleClick():
            tf.selection.startPos = findPrevWordStart(text, tf.cursorPos).int
            tf.selection.endPos = findNextWordEnd(text, tf.cursorPos).Natural
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
        sc, text, tf.cursorPos, tf.selection, maxLenOpt
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
      var newChars = consumeCharBuf()
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

  addDrawLayer(ui.currentLayer, vg):
    vg.save()
    let (x, y, w, h) = snapToGrid(x, y, w, h, s.bgStrokeWidth)
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
    var textX = textBoxX
    var textY = y + h * TextVertAlignFactor
    if drawWidget:
      vg.beginPath()
      vg.roundedRect(x, y, w, h, s.bgCornerRadius)
      vg.fillColor(fillColor)
      vg.fill()
    elif editing:
      vg.beginPath()
      vg.rect(
        textBoxX, textBoxY + s.textPadVert, textBoxW, textBoxH - s.textPadVert * 2
      )
      vg.fillColor(fillColor)
      vg.fill()
    let xPad = 3.0
    vg.intersectScissor(textBoxX - xPad, textBoxY, textBoxW + xPad, textBoxH)
    if editing:
      textX = tf.displayStartX
      if hasSelection(tf.selection):
        var ns = normaliseSelection(tf.selection)
        ns.endPos = max(ns.endPos - 1, 0).Natural
        let
          x1 =
            if ns.startPos == 0:
              tf.displayStartX
            else:
              tf.displayStartX + glyphs[ns.startPos].x - glyphs[tf.displayStartPos].x
          x2 = tf.displayStartX + glyphs[ns.endPos].maxX - glyphs[tf.displayStartPos].x
        vg.beginPath()
        vg.rect(x1, textBoxY + s.textPadVert, x2 - x1, textBoxH - s.textPadVert * 2)
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
    discard vg.text(textX, textY, text.runeSubStr(tf.displayStartPos))
    if editing:
      let cursorX = cursorXPos()
      vg.drawCursor(
        cursorX,
        textBoxY + s.textPadVert,
        textBoxY + textBoxH - s.textPadVert,
        s.cursorColor,
        s.cursorWidth,
      )
    vg.restore()

  if isHot(id):
    handleTooltip(id, tooltip)
  tab.prevItem = id

template rawTextField*(
    x, y, w, h: float,
    text: var string,
    tooltip: string = "",
    disabled: bool = false,
    activate: bool = false,
    constraint: Option[TextFieldConstraint] = TextFieldConstraint.none,
    style: TextFieldStyle = defaultTextFieldStyle(),
) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)
  textField(
    id,
    x,
    y,
    w,
    h,
    text,
    tooltip,
    disabled,
    activate,
    drawWidget = false,
    constraint,
    style,
  )

template textField*(
    x, y, w, h: float,
    text: var string,
    tooltip: string = "",
    disabled: bool = false,
    activate: bool = false,
    drawWidget: bool = true,
    constraint: Option[TextFieldConstraint] = TextFieldConstraint.none,
    style: TextFieldStyle = defaultTextFieldStyle(),
) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)
  textField(
    id, x, y, w, h, text, tooltip, disabled, activate, drawWidget, constraint, style
  )

template textField*(
    text: var string,
    tooltip: string = "",
    disabled: bool = false,
    activate: bool = false,
    drawWidget: bool = true,
    constraint: Option[TextFieldConstraint] = TextFieldConstraint.none,
    style: TextFieldStyle = defaultTextFieldStyle(),
) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)
  autoLayoutPre()
  textField(
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
