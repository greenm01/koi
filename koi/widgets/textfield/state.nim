import std/options
import std/tables
import std/unicode
import std/strutils

import nanovg

import koi/types
import koi/core
import koi/drawing
import koi/layout
import koi/rect
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

  if ui.activeItem == id:
    ui.activeItem = 0
  ui.focusCaptured = false
  cursorShape(csArrow)

proc textFieldPre*() =
  alias(ui, g_uiState)
  alias(tf, ui.textFieldState)

  if tf.activeItem == 0 or not ui.mbLeftDown:
    return

  let bounds = previousLayoutRect(tf.activeItem, rect(0, 0, 0, 0))
  if not mouseInside(bounds.x, bounds.y, bounds.w, bounds.h):
    textFieldExitEditMode(tf.activeItem)
