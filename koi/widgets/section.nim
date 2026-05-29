import std/math

import nanovg

import koi/types
import koi/core
import koi/drawing
import koi/layout
import koi/rect
import koi/input
import koi/defaults
import koi/internal/widget_behavior
import koi/widgets/common
import koi/utils

proc sectionHeader(
    id: ItemId,
    x, y, w: float,
    label: string,
    expanded_out: var bool,
    subHeader: bool,
    tooltip: string,
    style: SectionHeaderStyle,
): bool =
  alias(ui, g_uiState)
  alias(ss, ui.sectionHeaderState)
  alias(s, style)

  let (x, y) = addDrawOffset(x, y)
  let h = s.height
  let slot = layoutSlot(id, rect(x, y, w, h))

  if ss.openSubHeaders:
    if subHeader:
      expanded_out = true
    else:
      ss.openSubHeaders = false
  else:
    if isHit(
      slot.previousBounds.x, slot.previousBounds.y,
      max(0.0, slot.previousBounds.w - s.hitRightPad), slot.previousBounds.h,
    ):
      captureSimpleWidget(id, disabled = false)

      let behavior = simpleWidgetBehavior(id, disabled = false)
      if behavior.clicked:

        if not subHeader and ctrlDown():
          expanded_out = true
          ss.openSubHeaders = true
        else:
          expanded_out = not expanded_out

  let expanded = expanded_out

  addLayoutDrawLayer(ui.currentLayer, slot.nodeId, vg, bounds):
    var (rx, ry, rw, rh) = snapToGrid(bounds.x, bounds.y, bounds.w, bounds.h)

    vg.fillColor(s.backgroundColor)
    vg.beginPath()
    vg.rect(rx, ry, rw, rh)
    vg.fill()

    vg.strokeColor(s.separatorColor)
    vg.beginPath()
    vg.horizLine(rx, ry + rh, rw)
    vg.stroke()

    vg.save()
    let ts = s.triangleSize
    vg.translate(rx + s.triangleLeftPad, ry + rh * 0.5)
    vg.scale(ts, ts)
    vg.translate(1, 0)
    if expanded:
      vg.rotate(PI * 0.5)

    vg.beginPath()
    vg.moveTo(-1, 1)
    vg.lineTo(-1, -1)
    vg.lineTo(1.2, 0)
    vg.closePath()
    vg.fillColor(s.triangleColor)
    vg.fill()
    vg.restore()

    vg.drawLabel(
      rx + s.labelLeftPad, ry, rw - s.labelLeftPad, rh, label, style = s.label
    )

  if isHot(id):
    handleTooltip(id, tooltip)

  result = expanded_out

template sectionHeader*(
    label: string,
    expanded: var bool,
    tooltip: string = "",
    style: SectionHeaderStyle = borrowDefaultSectionHeaderStyle(),
): bool =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line, label)

  nextRowHeight(style.height)
  autoLayoutPre(section = true)
  let result = sectionHeader(
    id,
    0,
    g_uiState.autoLayoutState.y,
    g_uiState.autoLayoutState.rowWidth,
    label,
    expanded,
    subHeader = false,
    tooltip,
    style,
  )
  autoLayoutPost(section = true)
  result

template subSectionHeader*(
    label: string,
    expanded: var bool,
    tooltip: string = "",
    style: SectionHeaderStyle = borrowDefaultSubSectionHeaderStyle(),
): bool =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line, label)

  nextRowHeight(style.height)
  autoLayoutPre(section = true)
  let result = sectionHeader(
    id,
    0,
    g_uiState.autoLayoutState.y,
    g_uiState.autoLayoutState.rowWidth,
    label,
    expanded,
    subHeader = true,
    tooltip,
    style,
  )
  autoLayoutPost(section = true)
  result
