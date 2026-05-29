import std/strformat

import nanovg

import koi
import examples/example_common

var inspectorKeyWasDown = false

proc aspectTile(vg: NVGContext, id: ItemId, r: Rect, ratio: float, labelText: string) =
  let slot = layoutAspectSlot(id, r, ratio, minHeight = 36)
  vg.drawSlotBox(slot, rgb(0.20, 0.29, 0.36), rgb(0.42, 0.66, 0.82), labelText)
  vg.drawMeasuredLabel(slot, fmt"{ratio:.2f}")

proc render(vg: NVGContext) =
  beginDemoFrame(vg, "Layout Aspect Demo", inspectorKeyWasDown, rgb(0.12, 0.14, 0.15))

  label(24, 70, 500, 22, "Fixed rectangles")
  aspectTile(vg, 3000, rect(24, 106, 180, 80), 16.0 / 9.0, "16:9 fixed width")
  aspectTile(vg, 3001, rect(232, 106, 100, 150), 1.0, "1:1 fixed")
  aspectTile(vg, 3002, rect(372, 106, 160, 110), 4.0 / 3.0, "4:3")

  let root = beginLayoutContainerSlotAt(
    3100,
    rect(24, 306, max(360.0, winWidth() - 410), 190),
    rect(36, 318, max(336.0, winWidth() - 434), 166),
  )
  g_uiState.layoutArena.nodes[root.nodeId.int].direction = ldLeftToRight
  g_uiState.layoutArena.nodes[root.nodeId.int].padding = paddingAll(12)
  g_uiState.layoutArena.nodes[root.nodeId.int].childGap = 12
  vg.drawSlotBox(root, rgb(0.17, 0.20, 0.23), rgb(0.34, 0.41, 0.48), "grow container")

  for i, ratio in [1.0, 4.0 / 3.0, 16.0 / 9.0]:
    let child = layoutChildSlot(
      root.nodeId, 3110 + i, rect(0, 0, 120, 80), grow(min = 88), fixed(120)
    )
    vg.drawSlotBox(
      child, rgb(0.18 + i.float * 0.04, 0.30, 0.31), rgb(0.42, 0.66, 0.64), "grow cell"
    )
    let inner = layoutAttachSlot(
      3120 + i, rect(0, 0, 88, 64), child.nodeId, lapCenter, lapCenter, zIndex = 2
    )
    vg.drawSlotBox(
      inner, rgb(0.45, 0.32, 0.18), rgb(0.84, 0.62, 0.34), fmt"{ratio:.2f}"
    )
  endLayoutContainerSlot()

  scrollView(600.0, 86.0, 260.0, 332.0, 760.0, disabled = false):
    for i in 0 ..< 12:
      let ratio =
        case i mod 4
        of 0:
          1.0
        of 1:
          4.0 / 3.0
        of 2:
          16.0 / 9.0
        else:
          3.0 / 4.0
      aspectTile(
        vg, 3200 + i, rect(14, i.float * 62 + 12, 170, 52), ratio, "scroll aspect " & $i
      )

  endDemoFrame()

when isMainModule:
  runWgpuDemo("Koi Layout Aspect Demo", 980, 620, render)
