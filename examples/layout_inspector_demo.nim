import std/strformat

import nanovg

import koi
import examples/example_common

var
  inspectorKeyWasDown = false
  showError = false
  showFloating = true
  longText =
    "Wrapped text participates in intrinsic measurement and should expand this fit-height panel."
  sliderValue = 42.0
  enabled = true

proc drawNestedScene(vg: NVGContext, originX, originY: float) =
  let root = beginLayoutContainerSlotAt(
    1000, rect(originX, originY, 430, 280), rect(originX + 12, originY + 12, 406, 256)
  )
  g_uiState.layoutArena.nodes[root.nodeId.int].padding = paddingAll(12)
  g_uiState.layoutArena.nodes[root.nodeId.int].childGap = 10
  vg.drawSlotBox(root, rgb(0.18, 0.21, 0.24), rgb(0.38, 0.45, 0.52), "root")

  let row = layoutChildSlot(root.nodeId, 1001, rect(0, 0, 400, 88), grow(), fixed(88))
  vg.drawSlotBox(row, rgb(0.21, 0.25, 0.30), rgb(0.48, 0.56, 0.64), "flow row")

  let a = layoutChildSlot(row.nodeId, 1002, rect(0, 0, 96, 64), fixed(96), grow())
  vg.drawSlotBox(a, rgb(0.74, 0.42, 0.18), rgb(0.92, 0.66, 0.35), "fixed")

  let b = layoutChildSlot(row.nodeId, 1003, rect(0, 0, 140, 64), grow(), grow())
  vg.drawSlotBox(b, rgb(0.22, 0.43, 0.58), rgb(0.42, 0.68, 0.86), "grow")

  let c = layoutAspectSlot(1004, rect(originX + 294, originY + 24, 116, 64), 16.0 / 9.0)
  vg.drawSlotBox(c, rgb(0.28, 0.50, 0.31), rgb(0.50, 0.76, 0.52), "aspect")

  let textSlot = textLayoutChildSlot(
    root.nodeId,
    1005,
    rect(0, 0, 380, 54),
    longText,
    borrowDefaultLabelStyle(),
    grow(),
    fit(),
  )
  vg.drawSlotBox(textSlot, rgb(0.25, 0.22, 0.33), rgb(0.58, 0.48, 0.76), "text fit")

  let overlap1 = layoutAttachSlot(
    1006,
    rect(originX + 80, originY + 170, 150, 56),
    b.nodeId,
    lapBottomCenter,
    lapCenter,
    offset = size(-8, 24),
    zIndex = 3,
  )
  vg.drawSlotBox(overlap1, rgb(0.52, 0.18, 0.18), rgb(0.88, 0.38, 0.34), "z 3 attach")

  let overlap2 = layoutAttachSlot(
    1007,
    rect(originX + 122, originY + 182, 170, 58),
    b.nodeId,
    lapBottomCenter,
    lapCenter,
    offset = size(28, 40),
    zIndex = 6,
  )
  vg.drawSlotBox(overlap2, rgb(0.52, 0.45, 0.16), rgb(0.90, 0.78, 0.30), "z 6 attach")

  if showFloating:
    let floating = layoutAttachRootSlot(
      1008,
      rect(originX + 315, originY + 178, 160, 76),
      lapBottomRight,
      lapBottomRight,
      offset = size(-24, -24),
      zIndex = 10,
    )
    vg.drawSlotBox(
      floating, rgb(0.16, 0.32, 0.36), rgb(0.34, 0.74, 0.82), "root attach"
    )

  endLayoutContainerSlot()

proc render(vg: NVGContext) =
  beginDemoFrame(vg, "Layout Inspector Demo", inspectorKeyWasDown)
  setLayoutInspectorEnabled(true)

  label(24, 70, 360, 22, "Controls")
  toggleButton(24, 100, 118, 24, showFloating, "Floating", "Floating", "")
  toggleButton(154, 100, 118, 24, showError, "Error off", "Error on", "")
  toggleButton(284, 100, 118, 24, enabled, "Disabled", "Enabled", "")
  horizSlider(24, 142, 240, 24, 0, 100, sliderValue, label = fmt"{sliderValue:.0f}")
  textField(24, 184, 330, 24, longText, disabled = not enabled)

  drawNestedScene(vg, 24, 236)

  scrollView(482.0, 70.0, 250.0, 220.0, 620.0, disabled = false):
    for i in 0 ..< 18:
      let slot = layoutSlot(1100 + i, rect(8, i.float * 34 + 8, 210, 26))
      vg.drawSlotBox(
        slot,
        if i mod 2 == 0:
          rgb(0.19, 0.24, 0.28)
        else:
          rgb(0.22, 0.27, 0.31),
        rgb(0.42, 0.50, 0.56),
        "scroll row " & $i,
      )

  if showError:
    discard g_uiState.layoutArena.addLayoutNode(
      layoutNode(itemId = 1300, width = percent(1.4), height = fixed(20)),
      g_uiState.layoutRoot,
    )

  endDemoFrame()

when isMainModule:
  runWgpuDemo("Koi Layout Inspector Demo", 980, 680, render)
