import std/strformat

import nanovg

import koi
import examples/example_common

var
  inspectorKeyWasDown = false
  nodeCount = 600.0
  wrapText = true
  overlap = false
  depth = 3.0

proc render(vg: NVGContext) =
  beginDemoFrame(vg, "Layout Stress Demo", inspectorKeyWasDown, rgb(0.11, 0.13, 0.15))

  label(24, 72, 240, 22, "Stress controls")
  horizSlider(
    24, 104, 260, 24, 100, 2000, nodeCount, label = fmt"nodes {nodeCount:.0f}"
  )
  horizSlider(24, 144, 260, 24, 1, 8, depth, label = fmt"depth {depth:.0f}")
  toggleButton(24, 184, 116, 24, wrapText, "no wrap", "wrap", "")
  toggleButton(152, 184, 116, 24, overlap, "flow", "overlap", "")

  let count = nodeCount.int
  let nesting = max(1, depth.int)
  let contentHeight = max(600.0, (count div 4).float * 34 + 180)

  scrollView(
    318.0,
    72.0,
    max(360.0, winWidth() - 660),
    max(320.0, winHeight() - 120),
    contentHeight,
    disabled = false,
  ):
    var y = 10.0
    var item = 0
    while item < count:
      let parent = beginLayoutContainerSlotAt(
        5000 + item,
        rect(10, y, max(260.0, winWidth() - 710), 30 + nesting.float * 10),
        rect(10, y, max(260.0, winWidth() - 710), 30 + nesting.float * 10),
      )
      g_uiState.layoutArena.nodes[parent.nodeId.int].direction = ldLeftToRight
      g_uiState.layoutArena.nodes[parent.nodeId.int].padding = paddingAll(5)
      g_uiState.layoutArena.nodes[parent.nodeId.int].childGap = 5
      vg.drawSlotBox(
        parent,
        if item mod 2 == 0:
          rgb(0.16, 0.20, 0.23)
        else:
          rgb(0.18, 0.22, 0.25),
        rgb(0.31, 0.40, 0.47),
        "group " & $item,
      )

      for j in 0 ..< min(nesting, count - item):
        let child = layoutChildSlot(
          parent.nodeId, 7000 + item + j, rect(0, 0, 72, 24), grow(min = 52), fixed(24)
        )
        vg.drawSlotBox(
          child,
          rgb(0.19 + (j mod 3).float * 0.04, 0.29, 0.31),
          rgb(0.40, 0.62, 0.65),
          if wrapText:
            "node " & $(item + j) & " wrapped label"
          else:
            $(item + j),
        )
        if overlap and j == 0:
          let attached = layoutAttachSlot(
            9000 + item,
            rect(0, 0, 86, 24),
            child.nodeId,
            lapBottomRight,
            lapTopLeft,
            offset = size(8, -4),
            zIndex = 5,
          )
          vg.drawSlotBox(attached, rgb(0.45, 0.24, 0.17), rgb(0.82, 0.48, 0.35), "over")

      endLayoutContainerSlot()
      inc item, nesting
      y += 36 + nesting.float * 10

  label(
    24, 236, 260, 80,
    "Inspector starts off here so large trees stay responsive until F12 is pressed.",
  )

  endDemoFrame()

when isMainModule:
  runWgpuDemo("Koi Layout Stress Demo", 1100, 700, render)
