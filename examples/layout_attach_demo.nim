import std/strformat

import nanovg

import koi
import examples/example_common

var
  inspectorKeyWasDown = false
  pointIndex = 4
  windowPad = 8.0
  offsetX = 0.0
  offsetY = 0.0
  capturePointer = false
  rootAttach = false

const AttachPoints = [
  lapTopLeft, lapTopCenter, lapTopRight, lapCenterLeft, lapCenter, lapCenterRight,
  lapBottomLeft, lapBottomCenter, lapBottomRight,
]

const AttachLabels = [
  "top-left", "top-center", "top-right", "center-left", "center", "center-right",
  "bottom-left", "bottom-center", "bottom-right",
]

proc render(vg: NVGContext) =
  beginDemoFrame(vg, "Layout Attach Demo", inspectorKeyWasDown, rgb(0.12, 0.14, 0.16))

  label(24, 72, 180, 22, "Attach point")
  dropDown(24, 100, 190, 24, @AttachLabels, pointIndex, "")
  horizSlider(24, 142, 220, 24, -90, 90, offsetX, label = fmt"x {offsetX:.0f}")
  horizSlider(24, 182, 220, 24, -90, 90, offsetY, label = fmt"y {offsetY:.0f}")
  horizSlider(24, 222, 220, 24, 0, 48, windowPad, label = fmt"pad {windowPad:.0f}")
  toggleButton(24, 264, 118, 24, rootAttach, "Node", "Root", "")
  toggleButton(154, 264, 118, 24, capturePointer, "Pass", "Capture", "")

  let anchor = layoutSlot(2100, rect(384, 214, 180, 108))
  vg.drawSlotBox(anchor, rgb(0.24, 0.29, 0.35), rgb(0.65, 0.72, 0.80), "anchor")

  for i, point in AttachPoints:
    let slot = layoutAttachSlot(
      2110 + i,
      rect(0, 0, 78, 28),
      anchor.nodeId,
      point,
      lapCenter,
      offset = size(0, 0),
      windowPad = 0,
      zIndex = i,
    )
    vg.drawSlotBox(
      slot, rgb(0.20 + i.float * 0.035, 0.28, 0.37), rgb(0.44, 0.61, 0.78), $i
    )

  let selectedPoint = AttachPoints[pointIndex]
  let selected =
    if rootAttach:
      layoutAttachRootSlot(
        2200,
        rect(0, 0, 210, 82),
        selectedPoint,
        lapCenter,
        offset = size(offsetX, offsetY),
        windowPad = windowPad,
        zIndex = 20,
        capturePointer = capturePointer,
      )
    else:
      layoutAttachSlot(
        2200,
        rect(0, 0, 210, 82),
        anchor.nodeId,
        selectedPoint,
        lapCenter,
        offset = size(offsetX, offsetY),
        windowPad = windowPad,
        zIndex = 20,
        capturePointer = capturePointer,
      )
  vg.drawSlotBox(
    selected,
    rgb(0.55, 0.24, 0.18),
    rgb(0.95, 0.53, 0.39),
    if rootAttach: "selected root attach" else: "selected node attach",
  )

  let parent =
    beginLayoutContainerSlotAt(2300, rect(642, 90, 240, 220), rect(654, 102, 216, 196))
  g_uiState.layoutArena.nodes[parent.nodeId.int].padding = paddingAll(12)
  g_uiState.layoutArena.nodes[parent.nodeId.int].childGap = 8
  vg.drawSlotBox(parent, rgb(0.17, 0.21, 0.22), rgb(0.42, 0.54, 0.56), "parent")
  let child =
    layoutChildSlot(parent.nodeId, 2301, rect(0, 0, 160, 42), grow(), fixed(42))
  vg.drawSlotBox(child, rgb(0.20, 0.34, 0.28), rgb(0.44, 0.72, 0.56), "flow child")
  let parentAttached = layoutAttachParentSlot(
    2302,
    rect(0, 0, 170, 44),
    lapBottomCenter,
    lapTopCenter,
    offset = size(0, -12),
    zIndex = 8,
  )
  vg.drawSlotBox(
    parentAttached, rgb(0.22, 0.27, 0.45), rgb(0.46, 0.56, 0.88), "parent attach"
  )
  endLayoutContainerSlot()

  endDemoFrame()

when isMainModule:
  runWgpuDemo("Koi Layout Attach Demo", 980, 620, render)
