import std/math

import nanovg

import koi/types
import koi/core
import koi/drawing
import koi/layout
import koi/rect
import koi/input
import koi/defaults
import koi/internal/algorithms
import koi/internal/widget_behavior
import koi/widgets/common
import koi/utils

const
  ScrollBarFineDragDivisor = 10.0
  ScrollBarUltraFineDragDivisor = 100.0
  ScrollBarTrackClickRepeatDelay = 0.3
  ScrollBarTrackClickRepeatTimeout = 0.05

type ScrollBarAxis = enum
  sbaHorizontal
  sbaVertical

func axisMouse(ui: UIState, axis: ScrollBarAxis): float =
  case axis
  of sbaHorizontal: ui.mx
  of sbaVertical: ui.my

func axisDrag(ui: UIState, axis: ScrollBarAxis): float =
  case axis
  of sbaHorizontal: ui.dx
  of sbaVertical: ui.dy

func axisDragOrigin(ui: UIState, axis: ScrollBarAxis): float =
  case axis
  of sbaHorizontal: ui.x0
  of sbaVertical: ui.y0

proc setAxisDragOrigin(ui: var UIState, axis: ScrollBarAxis, value: float) =
  case axis
  of sbaHorizontal:
    ui.x0 = value
  of sbaVertical:
    ui.y0 = value

proc setAxisDragCursor(
    ui: var UIState, axis: ScrollBarAxis, thumbPos, thumbLength: float
) =
  case axis
  of sbaHorizontal:
    ui.dragX = thumbPos + thumbLength * 0.5
    ui.dragY = -1.0
  of sbaVertical:
    ui.dragX = -1.0
    ui.dragY = thumbPos + thumbLength * 0.5

proc restoreAxisCursor(ui: var UIState, axis: ScrollBarAxis) =
  case axis
  of sbaHorizontal:
    cursorPosX(ui.dragX)
    ui.dx = ui.dragX
    ui.x0 = ui.dragX
  of sbaVertical:
    cursorPosY(ui.dragY)
    ui.dy = ui.dragY
    ui.y0 = ui.dragY

proc updateScrollBarInteraction(
    axis: ScrollBarAxis,
    id: ItemId,
    startVal, endVal, value, clickStep: float,
    thumbPos, thumbLength, thumbMin, thumbMax: float,
    insideThumb: bool,
): tuple[value, thumbPos: float] =
  alias(ui, g_uiState)
  alias(sb, ui.scrollBarState)
  result = (value, thumbPos)

  if not isActive(id):
    return

  case sb.state
  of sbsDefault:
    if insideThumb:
      ui.setAxisDragOrigin(axis, ui.axisMouse(axis))
      if shiftDown():
        disableCursor()
        sb.state = sbsDragHidden
      else:
        sb.state = sbsDragNormal
      ui.widgetMouseDrag = true
    else:
      sb.clickDir =
        scrollBarTrackClickDir(startVal, endVal, ui.axisMouse(axis), thumbPos)
      sb.state = sbsTrackClickFirst
      ui.t0 = core.currentTime()
  of sbsDragNormal:
    if shiftDown():
      disableCursor()
      sb.state = sbsDragHidden
    else:
      let delta = ui.axisDrag(axis) - ui.axisDragOrigin(axis)
      result.thumbPos = clamp(thumbPos + delta, thumbMin, thumbMax)
      result.value =
        scrollBarValueFromThumb(result.thumbPos, thumbMin, thumbMax, startVal, endVal)
      ui.setAxisDragOrigin(
        axis, clamp(ui.axisDrag(axis), thumbMin, thumbMax + thumbLength)
      )
  of sbsDragHidden:
    if axis == sbaVertical:
      markHot(id)

    if shiftDown():
      let d = if altDown(): ScrollBarUltraFineDragDivisor else: ScrollBarFineDragDivisor
      let delta = (ui.axisDrag(axis) - ui.axisDragOrigin(axis)) / d
      result.thumbPos = clamp(thumbPos + delta, thumbMin, thumbMax)
      result.value =
        scrollBarValueFromThumb(result.thumbPos, thumbMin, thumbMax, startVal, endVal)
      ui.setAxisDragOrigin(axis, ui.axisDrag(axis))
      ui.setAxisDragCursor(axis, result.thumbPos, thumbLength)
    else:
      sb.state = sbsDragNormal
      showCursor()
      ui.restoreAxisCursor(axis)
  of sbsTrackClickFirst:
    result.value =
      scrollBarTrackClickValue(value, startVal, endVal, sb.clickDir, clickStep)
    result.thumbPos =
      scrollBarThumbFromValue(result.value, startVal, endVal, thumbMin, thumbMax)
    sb.state = sbsTrackClickDelay
    ui.t0 = core.currentTime()
    requestFrames()
  of sbsTrackClickDelay:
    if core.currentTime() - ui.t0 > ScrollBarTrackClickRepeatDelay:
      sb.state = sbsTrackClickRepeat
    requestFrames()
  of sbsTrackClickRepeat:
    if isHot(id):
      if core.currentTime() - ui.t0 > ScrollBarTrackClickRepeatTimeout:
        result = scrollBarRepeatTrackClick(
          value,
          startVal,
          endVal,
          sb.clickDir,
          clickStep,
          thumbPos,
          thumbLength,
          thumbMin,
          thumbMax,
          ui.axisMouse(axis),
        )
        ui.t0 = core.currentTime()
    else:
      ui.t0 = core.currentTime()
    requestFrames()
