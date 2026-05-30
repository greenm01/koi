import std/os

import nanovg

import koi
import koi/backends/wgpu_renderer

when defined(waylandBackend):
  import koi/backends/wayland_app
else:
  import std/options

  from glfw as glfwLib import nil
  import koi/backends/glfw_wgpu

type
  KoiWgpuAppConfig* = object
    title*: string
    width*: int
    height*: int
    resizable*: bool
    quitOnEscapeOrCtrlC*: bool

  KoiWgpuRenderProc* = proc(vg: NVGContext) {.closure.}

proc defaultKoiWgpuAppConfig*(
    title: string, width = 900, height = 600
): KoiWgpuAppConfig =
  KoiWgpuAppConfig(
    title: title,
    width: width,
    height: height,
    resizable: true,
    quitOnEscapeOrCtrlC: true,
  )

proc quitShortcutDown(config: KoiWgpuAppConfig): bool =
  config.quitOnEscapeOrCtrlC and
    (isKeyDown(keyEscape) or (isKeyDown(keyC) and ctrlDown()))

proc loadDefaultKoiFonts*(vg: NVGContext) =
  let dataDir = currentSourcePath().parentDir().parentDir().parentDir() / "data"

  let regular = vg.createFont("sans", dataDir / "Roboto-Regular.ttf")
  if regular == NoFont:
    quit "Could not load regular font."

  let bold = vg.createFont("sans-bold", dataDir / "Roboto-Bold.ttf")
  if bold == NoFont:
    quit "Could not load bold font."

when defined(waylandBackend):
  proc runKoiWgpuApp*(config: KoiWgpuAppConfig, render: KoiWgpuRenderProc) =
    let app = newKoiWaylandApp(config.title, config.width, config.height)
    app.updateSurfaceSize()

    var backend: KoiWgpuBackend
    backend.initKoiWgpuBackendWithSurface(
      app.surfaceHandle(), app.surfaceWidth, app.surfaceHeight
    )
    let vg = backend.createNanoVgContext({nifAntialias})
    init(vg, noGlfwProcAddress)
    loadDefaultKoiFonts(vg)

    while not app.shouldClose():
      app.pollEvents()
      if config.quitShortcutDown():
        app.shouldClose = true
        continue
      app.updateSurfaceSize()
      backend.resizeKoiWgpuBackend(app.surfaceWidth, app.surfaceHeight)
      render(vg)

    deinit()
    deleteNanoVgContext(vg)
    app.destroy()

else:
  proc createWgpuWindow(config: KoiWgpuAppConfig): Window =
    var cfg = defaultWgpuWindowConfig(config.title, config.width, config.height)
    cfg.size = (w: config.width, h: config.height)
    cfg.title = config.title
    cfg.resizable = config.resizable
    cfg.visible = true
    cfg.bits = (
      r: 8'i32.some,
      g: 8'i32.some,
      b: 8'i32.some,
      a: 8'i32.some,
      stencil: 8'i32.some,
      depth: 16'i32.some,
    )
    newWgpuWindow(cfg)

  proc runKoiWgpuApp*(config: KoiWgpuAppConfig, render: KoiWgpuRenderProc) =
    glfwLib.initialize()
    let win = createWgpuWindow(config)
    useWindow(win)

    let (initialWidth, initialHeight) = win.surfaceSize()

    var backend: KoiWgpuBackend
    backend.initKoiWgpuBackendWithSurface(
      win.wgpuSurfaceHandle(), initialWidth.uint32, initialHeight.uint32
    )
    let vg = backend.createNanoVgContext({nifAntialias})
    init(vg, glfwLib.getProcAddress)
    loadDefaultKoiFonts(vg)

    while not glfwLib.shouldClose(win):
      glfwLib.pollEvents()
      if config.quitShortcutDown():
        win.shouldClose = true
        continue
      let (surfaceWidth, surfaceHeight) = win.surfaceSize()
      backend.resizeKoiWgpuBackend(surfaceWidth, surfaceHeight)
      render(vg)

    deinit()
    deleteNanoVgContext(vg)
    glfwLib.destroy(win)
    glfwLib.terminate()
