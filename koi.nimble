# Package

version = "0.4.2"
author = "John Novak <john@johnnovak.net>"
description = "imgui for Nim"
license = "WTFPL"

# Dependencies

requires "nim >= 2.2.4", "glfw >= 3.4.0.5", "nanovg >= 0.4.0", "webgpu >= 25.0.0.0"

# Tasks

import std/os
import std/strutils

const
  CommonFlags =
    "--mm:orc --deepcopy:on -d:nimPreviewFloatRoundtrip " &
    "-d:nvgGL3 -d:glfwStaticLib -d:glStaticProcs --path:. --hint:Name:off"
  WgpuBaseFlags =
    "--mm:orc --deepcopy:on -d:nimPreviewFloatRoundtrip " &
    "-d:wgpu -d:wgvkWGSL -d:NoGLFW -d:koiWebGpu " &
    "--path:. --passC:-Wno-incompatible-pointer-types --hint:Name:off"
  WaylandLinkFlags =
    "--passL:\"-Lkoi/wayland/zig-out/lib -lkoi_wayland\" " &
    "--passL:\"-lwayland-client -lxkbcommon\" --passC:-Ikoi/wayland"
  WaylandFlags =
    "--mm:orc --deepcopy:on -d:waylandBackend --path:. --hint:Name:off " &
    WaylandLinkFlags

proc sh(cmd: string) =
  exec cmd

proc webgpuPathFlag(): string =
  var webgpuPath = getEnv("KOI_WEBGPU_PATH").strip()
  if webgpuPath.len == 0:
    webgpuPath = gorge("nimble path webgpu").strip()

  let srcPath =
    if webgpuPath.lastPathPart == "src":
      webgpuPath
    else:
      webgpuPath / "src"
  " --path:" & quoteShell(srcPath)

proc glfwWgpuFlags(): string =
  var flags = WgpuBaseFlags
  when defined(linux):
    if existsEnv("WAYLAND_DISPLAY"):
      flags.add " -d:wayland"
  flags & webgpuPathFlag()

proc nativeWaylandWgpuFlags(): string =
  WgpuBaseFlags & " -d:wayland -d:waylandBackend -d:glfwJustCdecl " & WaylandLinkFlags &
    webgpuPathFlag()

proc wgpuBackend(): string =
  result = getEnv("KOI_BACKEND").toLowerAscii
  if result.len == 0:
    when defined(linux):
      result = if existsEnv("WAYLAND_DISPLAY"): "wayland" else: "glfw"
    else:
      result = "glfw"
  if result notin ["wayland", "glfw"]:
    quit "KOI_BACKEND must be 'wayland' or 'glfw'."
  when not defined(linux):
    if result == "wayland":
      quit "KOI_BACKEND=wayland is only supported on Linux."

proc wgpuFlags(): string =
  if wgpuBackend() == "wayland":
    nativeWaylandWgpuFlags()
  else:
    glfwWgpuFlags()

proc waylandWgpuFlags(): string =
  WgpuBaseFlags & " -d:waylandBackend " & WaylandLinkFlags & webgpuPathFlag()

proc buildWaylandBackend() =
  sh "zig build -Doptimize=Debug --build-file koi/wayland/build.zig"

proc buildWgpuBackendIfNeeded() =
  if wgpuBackend() == "wayland":
    buildWaylandBackend()

proc nimCompile(source: string, flags = "", outPath = "", nimcache = "") =
  var cmd = "nim c " & flags
  if nimcache.len > 0:
    cmd.add " --nimcache:" & quoteShell(nimcache)
  if outPath.len > 0:
    cmd.add " --out:" & quoteShell(outPath)
  cmd.add " " & quoteShell(source)
  sh cmd

proc nimRun(source: string, flags = "", outPath = "", nimcache = "") =
  var cmd = "nim r " & flags
  if nimcache.len > 0:
    cmd.add " --nimcache:" & quoteShell(nimcache)
  if outPath.len > 0:
    cmd.add " --out:" & quoteShell(outPath)
  cmd.add " " & quoteShell(source)
  sh cmd

proc compileWgpuApp(source, nimcache: string) =
  buildWgpuBackendIfNeeded()
  nimCompile(source, wgpuFlags() & " -d:debug", nimcache = nimcache)

task test, "build test example":
  nimCompile(
    "examples/test", CommonFlags & " -d:debug", nimcache = "/tmp/koi_example_test_d"
  )

task paneltest, "build panel test example":
  nimCompile(
    "examples/paneltest", CommonFlags & " -d:debug", nimcache = "/tmp/koi_paneltest_d"
  )

task minimal, "build minimal wgpu example":
  compileWgpuApp("examples/minimal", "/tmp/koi_minimal_d")

task layoutInspectorDemo, "build layout inspector wgpu demo":
  compileWgpuApp("examples/layout_inspector_demo", "/tmp/koi_layout_inspector_demo_d")

task layoutAttachDemo, "build layout attach wgpu demo":
  compileWgpuApp("examples/layout_attach_demo", "/tmp/koi_layout_attach_demo_d")

task layoutAspectDemo, "build layout aspect-ratio wgpu demo":
  compileWgpuApp("examples/layout_aspect_demo", "/tmp/koi_layout_aspect_demo_d")

task layoutErrorsDemo, "build layout diagnostics wgpu demo":
  compileWgpuApp("examples/layout_errors_demo", "/tmp/koi_layout_errors_demo_d")

task layoutStressDemo, "build layout stress wgpu demo":
  compileWgpuApp("examples/layout_stress_demo", "/tmp/koi_layout_stress_demo_d")

task layoutDemos, "build every layout-focused wgpu demo":
  buildWgpuBackendIfNeeded()
  nimCompile(
    "examples/layout_inspector_demo",
    wgpuFlags() & " -d:debug",
    nimcache = "/tmp/koi_layout_inspector_demo_d",
  )
  nimCompile(
    "examples/layout_attach_demo",
    wgpuFlags() & " -d:debug",
    nimcache = "/tmp/koi_layout_attach_demo_d",
  )
  nimCompile(
    "examples/layout_aspect_demo",
    wgpuFlags() & " -d:debug",
    nimcache = "/tmp/koi_layout_aspect_demo_d",
  )
  nimCompile(
    "examples/layout_errors_demo",
    wgpuFlags() & " -d:debug",
    nimcache = "/tmp/koi_layout_errors_demo_d",
  )
  nimCompile(
    "examples/layout_stress_demo",
    wgpuFlags() & " -d:debug",
    nimcache = "/tmp/koi_layout_stress_demo_d",
  )

task waylandMinimal, "build native Wayland minimal example":
  buildWaylandBackend()
  nimCompile(
    "examples/wayland_minimal",
    WaylandFlags & " -d:debug",
    nimcache = "/tmp/koi_wayland_minimal_d",
  )

task waylandWgpuMinimal, "build native Wayland wgpu minimal example":
  buildWaylandBackend()
  nimCompile(
    "examples/wayland_wgpu_minimal",
    waylandWgpuFlags() & " -d:debug",
    nimcache = "/tmp/koi_wayland_wgpu_minimal_d",
  )

task testLayout, "run headless layout tests":
  nimRun(
    "tests/test_layout",
    CommonFlags & " -d:debug",
    outPath = "/tmp/koi_test_layout",
    nimcache = "/tmp/koi_test_layout_d",
  )

task testAlgorithms, "run headless algorithm tests":
  nimRun(
    "tests/test_algorithms",
    CommonFlags & " -d:debug",
    outPath = "/tmp/koi_test_algorithms",
    nimcache = "/tmp/koi_test_algorithms_d",
  )

task testWidgetBehavior, "run headless widget behavior tests":
  nimRun(
    "tests/test_widget_behavior",
    CommonFlags & " -d:debug",
    outPath = "/tmp/koi_test_widget_behavior",
    nimcache = "/tmp/koi_test_widget_behavior_d",
  )

task testMenuMacro, "compile menu macro syntax smoke":
  nimCompile(
    "tests/test_menu_macro",
    CommonFlags & " -d:debug",
    outPath = "/tmp/koi_test_menu_macro",
    nimcache = "/tmp/koi_test_menu_macro_d",
  )

task testDrawState, "run headless draw-state tests":
  nimRun(
    "tests/test_draw_state",
    CommonFlags & " -d:debug",
    outPath = "/tmp/koi_test_draw_state",
    nimcache = "/tmp/koi_test_draw_state_d",
  )

# Per-widget headless behaviour tests (share tests/widget_test_common.nim).

const WidgetBehaviorTests = [
  "popup", "dropdown", "menu", "slider", "scrollbar", "colorpicker", "textinput",
  "adversarial", "fuzz",
]

proc runHeadlessTest(name: string) =
  nimRun(
    "tests/test_" & name,
    CommonFlags & " -d:debug",
    outPath = "/tmp/koi_test_" & name,
    nimcache = "/tmp/koi_test_" & name & "_d",
  )

# Windowed integration tests run against a real (hidden) WebGPU window/context,
# so they use the wgpu flags and need a GPU/display.
const WindowTests = ["textinput", "textarea", "slider", "scrollbar", "renderer"]

proc runWindowTest(name: string) =
  nimRun(
    "tests/test_window_" & name,
    glfwWgpuFlags() & " -d:debug",
    outPath = "/tmp/koi_win_" & name,
    nimcache = "/tmp/koi_win_" & name & "_d",
  )

proc runAllHeadlessTests() =
  for name in ["algorithms", "layout", "draw_state", "widget_behavior"]:
    nimRun(
      "tests/test_" & name,
      CommonFlags & " -d:debug",
      outPath = "/tmp/koi_test_" & name,
      nimcache = "/tmp/koi_test_" & name & "_d",
    )
  for name in WidgetBehaviorTests:
    runHeadlessTest(name)
  when defined(linux):
    buildWaylandBackend()
    nimRun(
      "tests/test_wayland_backend",
      WaylandFlags & " -d:debug",
      outPath = "/tmp/koi_test_wayland_backend",
      nimcache = "/tmp/koi_test_wayland_backend_d",
    )

task testPopup, "run headless popup tests":
  runHeadlessTest("popup")

task testDropdown, "run headless dropdown tests":
  runHeadlessTest("dropdown")

task testMenu, "run headless menu tests":
  runHeadlessTest("menu")

task testSlider, "run headless slider tests":
  runHeadlessTest("slider")

task testScrollbar, "run headless scrollbar tests":
  runHeadlessTest("scrollbar")

task testColorPicker, "run headless color picker tests":
  runHeadlessTest("colorpicker")

task testTextInput, "run headless text field/area tests":
  runHeadlessTest("textinput")

task testAdversarial, "run adversarial cross-widget tests":
  runHeadlessTest("adversarial")

task testFuzz, "run invariant-based randomized tests":
  runHeadlessTest("fuzz")

task benchTextEditing, "profile representative text editing workloads":
  nimRun(
    "tests/bench_text_editing",
    glfwWgpuFlags() & " -d:release",
    outPath = "/tmp/koi_bench_text_editing",
    nimcache = "/tmp/koi_bench_text_editing_r",
  )

task bench, "profile representative WebGPU render workloads":
  nimRun(
    "tests/bench_render",
    glfwWgpuFlags() & " -d:release",
    outPath = "/tmp/koi_bench_render",
    nimcache = "/tmp/koi_bench_render_r",
  )

task testWindowTextInput, "run windowed text field tests (wgpu)":
  runWindowTest("textinput")

task testWindowTextArea, "run windowed text area tests (wgpu)":
  runWindowTest("textarea")

task testWindowSlider, "run windowed slider cursor-capture tests (wgpu)":
  runWindowTest("slider")

task testWindowScrollbar, "run windowed scrollbar cursor-capture tests (wgpu)":
  runWindowTest("scrollbar")

task testWindowRenderer, "run windowed WebGPU renderer readback tests":
  runWindowTest("renderer")

task testWindow, "run every windowed (wgpu) integration test":
  for name in WindowTests:
    runWindowTest(name)

task testHeadless, "run every headless test suite":
  runAllHeadlessTests()

task testAll, "run every headless suite and every windowed (wgpu) test":
  runAllHeadlessTests()
  for name in WindowTests:
    runWindowTest(name)

task testRelease, "build release test example":
  nimCompile(
    "examples/test", CommonFlags & " -d:release", nimcache = "/tmp/koi_example_test_r"
  )

task paneltestRelease, "build release panel test example":
  nimCompile(
    "examples/paneltest", CommonFlags & " -d:release", nimcache = "/tmp/koi_paneltest_r"
  )

task tidy, "format sources and remove generated example binaries":
  for path in walkDirRec("."):
    if path.startsWith("./.git") or path.startsWith("./koi/wayland/.zig-cache"):
      continue
    if path.endsWith(".nim") or path.endsWith(".nims") or path.endsWith(".nimble"):
      sh "nph " & quoteShell(path)

  sh "zig fmt " & quoteShell("koi/wayland/build.zig") & " " &
    quoteShell("koi/wayland/koi_wayland.zig")

  var cleanup = "rm -f"
  for path in [
    "examples/test", "examples/test.exe", "examples/paneltest",
    "examples/paneltest.exe", "examples/minimal", "examples/minimal.exe",
    "examples/layout_inspector_demo", "examples/layout_inspector_demo.exe",
    "examples/layout_attach_demo", "examples/layout_attach_demo.exe",
    "examples/layout_aspect_demo", "examples/layout_aspect_demo.exe",
    "examples/layout_errors_demo", "examples/layout_errors_demo.exe",
    "examples/layout_stress_demo", "examples/layout_stress_demo.exe",
    "examples/wayland_minimal", "examples/wayland_minimal.exe",
    "examples/wayland_wgpu_minimal", "examples/wayland_wgpu_minimal.exe",
  ]:
    cleanup.add " " & quoteShell(path)
  sh cleanup
