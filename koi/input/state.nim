import std/hashes
import std/math
import std/options
import std/strutils
import std/unicode
import std/tables

when not defined(waylandBackend):
  from glfw as glfwLib import nil
import nanovg

import koi/utils
import koi/types
import koi/core
import koi/rect
import koi/ringbuffer
import koi/internal/algorithms

# Input handling: keyboard, mouse, shortcuts, and clipboard

func hashId*(id: string): ItemId =
  let hash32 = hash(id).uint32
  # Make sure the IDs are always positive integers
  let h = int64(hash32) - int32.low + 1
  assert h > 0
  h

func mkIdString*(filename: string, line: int, id: string): string =
  result = filename & ":" & $line & ":" & id

var g_nextIdString: string
var g_lastIdString: string

proc generateId*(filename: string, line: int, id: string = ""): ItemId =
  let idString = mkIdString(filename, line, id)
  g_lastIdString = idString
  hashId(idString)

proc nextId*(filename: string, line: int, id: string = ""): ItemId =
  if g_nextIdString == "":
    result = generateId(filename, line, id)
  else:
    result = hashId(g_nextIdString)
    g_nextIdString = ""

proc getNextId*(filename: string, line: int, id: string = ""): ItemId =
  nextId(filename, line, id)

proc lastIdString*(): string =
  g_lastIdString

proc useNextId*(id: string) =
  g_nextIdString = id

proc setNextId*(id: string) =
  useNextId(id)

proc mouseInside*(x, y, w, h: float): bool =
  alias(ui, g_uiState)
  ui.mx >= x and ui.mx <= x + w and ui.my >= y and ui.my <= y + h

proc isHot*(id: ItemId): bool =
  g_uiState.hotItem == id

proc markHot*(id: ItemId) =
  alias(ui, g_uiState)
  ui.hotItem = id

proc setHot*(id: ItemId) =
  markHot(id)

proc isActive*(id: ItemId): bool =
  g_uiState.activeItem == id

proc markActive*(id: ItemId) =
  g_uiState.activeItem = id

proc setActive*(id: ItemId) =
  markActive(id)

proc hasHotItem*(): bool =
  g_uiState.hotItem > 0

proc hasNoActiveItem*(): bool =
  g_uiState.activeItem == 0

proc hasActiveItem*(): bool =
  g_uiState.activeItem > 0

proc hitClip*(x, y, w, h: float) =
  alias(ui, g_uiState)
  ui.hitClipRect = rect(x, y, w, h)

proc setHitClip*(x, y, w, h: float) =
  hitClip(x, y, w, h)

proc resetHitClip*() =
  alias(ui, g_uiState)
  ui.hitClipRect = rect(0, 0, ui.winWidth, ui.winHeight)

proc isHit*(x, y, w, h: float): bool =
  alias(ui, g_uiState)
  let r = rect(x, y, w, h).intersect(ui.hitClipRect)
  if r.isSome:
    let r = r.get
    result = not ui.focusCaptured and mouseInside(r.x, r.y, r.w, r.h)
  else:
    result = false

proc mx*(): float =
  g_uiState.mx

proc my*(): float =
  g_uiState.my

proc lastMx*(): float =
  g_uiState.lastmx

proc lastMy*(): float =
  g_uiState.lastmy

proc hasEvent*(): bool =
  alias(ui, g_uiState)
  not ui.focusCaptured and ui.hasEvent and (not ui.eventHandled)

proc currEvent*(): Event =
  g_uiState.currEvent

proc eventHandled*(): bool =
  g_uiState.eventHandled

proc markEventHandled*() =
  g_uiState.eventHandled = true

proc setEventHandled*() =
  markEventHandled()

proc mbLeftDown*(): bool =
  g_uiState.mbLeftDown

proc mbRightDown*(): bool =
  g_uiState.mbRightDown

proc mbMiddleDown*(): bool =
  g_uiState.mbMiddleDown

proc useWindow*(win: Window) =
  g_window = win

proc setWindow*(win: Window) =
  useWindow(win)

proc activeWindow*(): Window =
  if not g_window.isNil:
    g_window
  else:
    when defined(waylandBackend):
      nil
    else:
      glfwLib.currentContext()
