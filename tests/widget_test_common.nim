## Shared harness for headless koi widget behaviour tests.
##
## Tests drive widgets the same way the real frame loop does: by setting input
## state on the global `g_uiState`, calling the widget proc, and inspecting the
## resulting state. No window or NVG context exists, so widgets that measure
## glyphs inside their proc body (textfield/textarea in edit mode) cannot be
## driven into those paths here -- their pure editing logic is covered by
## tests/test_algorithms.nim instead.
##
## Import this module from a per-widget test file; it re-exports unittest, koi,
## glfw and nanovg so the test file only needs this one import.

import std/options
import std/tables
import std/unicode
import std/unittest

import glfw
import nanovg

import koi/core
import koi/defaults
import koi/drawing
import koi/input
import koi/internal/algorithms
import koi/internal/widget_behavior
import koi/layout
import koi/rect
import koi/types

import koi/widgets/button
import koi/widgets/chart
import koi/widgets/checkbox
import koi/widgets/colorpicker
import koi/widgets/common
import koi/widgets/dialog
import koi/widgets/dropdown
import koi/widgets/groupbox
import koi/widgets/image
import koi/widgets/label
import koi/widgets/listview
import koi/widgets/menu
import koi/widgets/popup
import koi/widgets/progress
import koi/widgets/property
import koi/widgets/radiobuttons
import koi/widgets/scrollbar
import koi/widgets/scrollview
import koi/widgets/section
import koi/widgets/selectable
import koi/widgets/slider
import koi/widgets/table
import koi/widgets/textarea
import koi/widgets/textfield
import koi/widgets/togglebutton
import koi/widgets/tree

export options, tables, unicode, unittest
export glfw, nanovg
export core, defaults, drawing, input, algorithms, widget_behavior, layout, rect, types
export button, chart, checkbox, colorpicker, common, dialog, dropdown, groupbox
export image, label, listview, menu, popup, progress, property, radiobuttons
export scrollbar, scrollview, section, selectable, slider, table, textarea
export textfield, togglebutton, tree

const
  TestWinW* = 200.0
  TestWinH* = 200.0

proc resetUi*() =
  ## Reset all global UI state to a clean single-frame baseline.
  g_uiState = UIState.default
  g_uiState.winWidth = TestWinW
  g_uiState.winHeight = TestWinH
  g_uiState.hitClipRect = rect(0, 0, TestWinW, TestWinH)
  g_uiState.drawOffsetStack = @[DrawOffset(ox: 0, oy: 0)]
  g_drawLayers.init()
  clearCharBuf()
  clearEventBuf()
  useShortcuts(smLinux)

template checkRect*(actual, expected: Rect) =
  check actual.x == expected.x
  check actual.y == expected.y
  check actual.w == expected.w
  check actual.h == expected.h

# Input injection helpers ----------------------------------------------------

proc placeRect*(id: ItemId, r: Rect) =
  ## Register a previously-solved layout rect so the next frame's hit testing
  ## uses it (mirrors how layout feeds `previousBounds` back into a widget).
  g_uiState.layoutRects[id] = r

proc mouseTo*(x, y: float) =
  g_uiState.mx = x
  g_uiState.my = y

proc pressLeftAt*(x, y: float) =
  g_uiState.mx = x
  g_uiState.my = y
  g_uiState.mbLeftDown = true

proc releaseLeft*() =
  g_uiState.mbLeftDown = false

proc pressRightAt*(x, y: float) =
  g_uiState.mx = x
  g_uiState.my = y
  g_uiState.mbRightDown = true

proc releaseRight*() =
  g_uiState.mbRightDown = false

proc sendKey*(key: Key, mods: set[ModifierKey] = {}, action: KeyAction = kaDown) =
  ## Queue a single key event for the next widget call.
  g_uiState.hasEvent = true
  g_uiState.eventHandled = false
  g_uiState.currEvent = Event(kind: ekKey, key: key, action: action, mods: mods)

proc sendScroll*(ox, oy: float) =
  g_uiState.hasEvent = true
  g_uiState.eventHandled = false
  g_uiState.currEvent = Event(kind: ekScroll, ox: ox, oy: oy)

proc clearEvent*() =
  g_uiState.hasEvent = false
  g_uiState.eventHandled = false

proc typeText*(s: string) =
  ## Fill the character buffer as if the user typed `s` (consumed by text
  ## widgets via `consumeCharBuf`).
  clearCharBuf()
  var i = 0
  for r in s.runes:
    g_charBuf[i] = r
    inc i
  g_charBufIdx = i

proc dropDownStateOf*(id: ItemId): DropDownStateVars =
  ## Read the dropdown's per-item state struct for assertions.
  cast[DropDownStateVars](g_uiState.itemState[id])

proc nextFrame*() =
  ## Emulate the active/hot-item bookkeeping that lifecycle.endFrame and
  ## beginFrame perform at a frame boundary, so multi-frame and multi-widget
  ## interaction tests can chain widget calls without a real frame loop.
  ## Mirrors the "Active state reset" in koi/lifecycle.nim:124-129.
  if g_uiState.mbLeftDown or g_uiState.mbRightDown or g_uiState.mbMiddleDown:
    if g_uiState.activeItem == 0 and g_uiState.hotItem == 0:
      g_uiState.activeItem = -1
  else:
    if g_uiState.activeItem != 0:
      g_uiState.activeItem = 0
  g_uiState.hotItem = 0
