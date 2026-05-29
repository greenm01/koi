import nanovg

import koi
import examples/example_common

type ErrorCase = enum
  ecInvalidPercent = (0, "invalid percent")
  ecDuplicateId = (1, "duplicate id")
  ecMissingAttachTarget = (2, "missing target")
  ecUnbalancedStack = (3, "unbalanced stack")
  ecMaxNodes = (4, "max nodes")

var
  inspectorKeyWasDown = false
  selectedCase = ecInvalidPercent

const ErrorLabels =
  ["invalid percent", "duplicate id", "missing target", "unbalanced stack", "max nodes"]

proc render(vg: NVGContext) =
  beginDemoFrame(vg, "Layout Errors Demo", inspectorKeyWasDown, rgb(0.14, 0.13, 0.14))
  setLayoutInspectorEnabled(true)

  label(24, 74, 280, 22, "Diagnostic case")
  dropDown(24, 104, 230, 24, @ErrorLabels, selectedCase, "")

  if selectedCase == ecMaxNodes:
    setLayoutMaxNodes(8)
  else:
    setLayoutMaxNodes(0)

  let good = layoutSlot(4000, rect(320, 104, 190, 70))
  vg.drawSlotBox(good, rgb(0.18, 0.25, 0.24), rgb(0.40, 0.70, 0.62), "valid slot")

  case selectedCase
  of ecInvalidPercent:
    discard g_uiState.layoutArena.addLayoutNode(
      layoutNode(itemId = 4010, width = percent(1.35), height = fixed(36)),
      g_uiState.layoutRoot,
    )
  of ecDuplicateId:
    let first = layoutSlot(4020, rect(320, 206, 150, 44))
    let second = layoutSlot(4020, rect(492, 206, 150, 44))
    vg.drawSlotBox(first, rgb(0.32, 0.22, 0.18), rgb(0.74, 0.48, 0.36), "id 4020")
    vg.drawSlotBox(second, rgb(0.32, 0.22, 0.18), rgb(0.74, 0.48, 0.36), "id 4020")
  of ecMissingAttachTarget:
    let missing = layoutAttachSlot(
      4030, rect(320, 206, 210, 54), LayoutNodeId(99_999), lapBottomLeft, lapTopLeft
    )
    vg.drawSlotBox(missing, rgb(0.32, 0.24, 0.18), rgb(0.78, 0.58, 0.36), "missing")
  of ecUnbalancedStack:
    let open =
      beginLayoutContainerSlotAt(4040, rect(320, 206, 220, 80), rect(328, 214, 204, 64))
    g_uiState.layoutArena.nodes[open.nodeId.int].padding = paddingAll(8)
    g_uiState.layoutArena.nodes[open.nodeId.int].childGap = 6
    vg.drawSlotBox(open, rgb(0.25, 0.20, 0.30), rgb(0.65, 0.50, 0.82), "left open")
    discard layoutChildSlot(open.nodeId, 4041, rect(0, 0, 120, 24), grow(), fixed(24))
  of ecMaxNodes:
    for i in 0 ..< 20:
      let slot = layoutSlot(
        4050 + i, rect(320 + (i mod 4).float * 80, 206 + (i div 4).float * 38, 70, 28)
      )
      vg.drawSlotBox(slot, rgb(0.24, 0.20, 0.20), rgb(0.72, 0.46, 0.42), $i)

  label(
    24, 154, 250, 70,
    "Pick a case, then inspect the tree and error list. Only one diagnostic family is active per frame.",
  )

  endDemoFrame()

when isMainModule:
  runWgpuDemo("Koi Layout Errors Demo", 940, 600, render)
