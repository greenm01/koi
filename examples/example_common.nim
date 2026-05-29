import std/strformat

import glfw
import nanovg

import koi
import koi/rect
import koi/backends/wgpu_app

export rect

type DemoRenderProc* = proc(vg: NVGContext) {.closure.}

proc runWgpuDemo*(title: string, width, height: int, render: DemoRenderProc) =
  runKoiWgpuApp(defaultKoiWgpuAppConfig(title, width, height), render)

proc handleInspectorShortcut*(wasDown: var bool) =
  let down = isKeyDown(keyF12)
  if down and not wasDown:
    toggleLayoutInspector()
  wasDown = down

proc beginDemoFrame*(
    vg: NVGContext,
    title: string,
    inspectorKeyWasDown: var bool,
    background: Color = rgb(0.13, 0.15, 0.17),
) =
  handleInspectorShortcut(inspectorKeyWasDown)
  beginFrame()

  vg.beginPath()
  vg.rect(0, 0, winWidth(), winHeight())
  vg.fillColor(background)
  vg.fill()

  vg.fillColor(rgb(0.90, 0.93, 0.96))
  vg.useFont(19, "sans-bold")
  discard vg.text(24, 24, title)

  vg.fillColor(rgb(0.62, 0.68, 0.74))
  vg.useFont(12, "sans")
  discard vg.text(24, 46, fmt"F12 inspector | nodes {layoutInspectorTreeRows().len}")

proc endDemoFrame*() =
  endFrame()

proc fillRect*(vg: NVGContext, r: Rect, fill, stroke: Color, strokeWidth = 1.0) =
  vg.beginPath()
  vg.roundedRect(r.x, r.y, r.w, r.h, 3)
  vg.fillColor(fill)
  vg.fill()
  vg.strokeColor(stroke)
  vg.strokeWidth(strokeWidth)
  vg.stroke()

proc drawSlotBox*(
    vg: NVGContext,
    slot: LayoutSlot,
    fill, stroke: Color,
    caption: string = "",
    textColor: Color = rgb(0.92, 0.94, 0.96),
) =
  let capturedCaption = caption
  addLayoutDrawLayer(layerDefault, slot.nodeId, vg, bounds):
    vg.fillRect(bounds, fill, stroke)
    if capturedCaption.len > 0:
      vg.fillColor(textColor)
      vg.useFont(12, "sans")
      discard vg.text(bounds.x + 8, bounds.y + min(bounds.h * 0.5, 18), capturedCaption)

proc drawSlotOutline*(
    vg: NVGContext, slot: LayoutSlot, stroke: Color, caption: string = ""
) =
  let capturedCaption = caption
  addLayoutDrawLayer(layerDefault, slot.nodeId, vg, bounds):
    vg.beginPath()
    vg.roundedRect(bounds.x, bounds.y, bounds.w, bounds.h, 3)
    vg.strokeColor(stroke)
    vg.strokeWidth(2)
    vg.stroke()
    if capturedCaption.len > 0:
      vg.fillColor(stroke)
      vg.useFont(12, "sans-bold")
      discard vg.text(bounds.x + 8, bounds.y + 16, capturedCaption)

proc drawMeasuredLabel*(vg: NVGContext, slot: LayoutSlot, prefix: string) =
  let capturedPrefix = prefix
  addLayoutDrawLayer(layerDefault, slot.nodeId, vg, bounds):
    vg.fillColor(rgb(0.86, 0.88, 0.90))
    vg.useFont(11, "sans")
    discard vg.text(
      bounds.x + 8,
      bounds.y + bounds.h - 13,
      fmt"{capturedPrefix} {bounds.w:.0f} x {bounds.h:.0f}",
    )
