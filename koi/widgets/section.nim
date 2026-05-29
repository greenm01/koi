import std/math

import nanovg

import koi/types
import koi/core
import koi/drawing
import koi/layout
import koi/input
import koi/defaults
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

  if ss.openSubHeaders:
    if subHeader:
      expanded_out = true
    else:
      ss.openSubHeaders = false
  else:
    if isHit(x, y, w - s.hitRightPad, h):
      markHot(id)
      if ui.mbLeftDown and hasNoActiveItem():
        markActive(id)

        if not subHeader and ctrlDown():
          expanded_out = true
          ss.openSubHeaders = true
        else:
          expanded_out = not expanded_out

  let expanded = expanded_out

  addDrawLayer(ui.currentLayer, vg):
    var (rx, ry, rw, rh) = snapToGrid(x, y, w, h)

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
    style: SectionHeaderStyle = defaultSectionHeaderStyle(),
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
    style: SectionHeaderStyle = defaultSubSectionHeaderStyle(),
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
