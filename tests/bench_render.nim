import std/[times, monotimes, strutils]
import wgpu_test_common

# close the harness's open frame so we can do our own begin/end cycles
gVg.endFrame()

proc frame(n: int) =
  gVg.beginFrame(400, 300, 1.0)
  resetUi()
  g_uiState.winWidth = 400
  g_uiState.winHeight = 300
  g_uiState.hitClipRect = rect(0, 0, 400, 300)
  g_uiState.drawOffsetStack = @[DrawOffset(ox: 0, oy: 0)]
  g_drawLayers.init()
  var params = DefaultAutoLayoutParams
  params.itemsPerRow = 1
  params.rowWidth = 180
  initAutoLayout(params)
  beginFrameLayout()
  for i in 0 ..< n:
    discard button(
      ItemId(1000 + i),
      0,
      autoLayoutNextY(),
      180,
      autoLayoutNextItemHeight(),
      "Button " & $i,
      "",
      disabled = false,
    )
  finishFrameLayout()
  g_drawLayers.draw(gVg)
  gVg.endFrame()

for n in [50, 200, 500]:
  for _ in 0 ..< 20:
    frame(n) # warm
  let iters = 300
  let t0 = getMonoTime()
  for _ in 0 ..< iters:
    frame(n)
  let dt = (getMonoTime() - t0).inMicroseconds.float / iters.float
  echo n,
    " buttons FULL render: ",
    dt.formatFloat(ffDecimal, 1),
    " us/frame   draw calls=",
    g_drawLayers.layers[0].len,
    " closures"
