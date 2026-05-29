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
  CommonFlags = "--mm:orc --deepcopy:on -d:nimPreviewFloatRoundtrip " &
    "-d:nvgGL3 -d:glfwStaticLib -d:glStaticProcs --path:. --hint:Name:off"
  WgpuBaseFlags = "--mm:orc --deepcopy:on -d:nimPreviewFloatRoundtrip " &
    "-d:wgpu -d:wgvkWGSL -d:NoGLFW -d:koiWebGpu -d:wayland " &
    "--path:. --passC:-Wno-incompatible-pointer-types --hint:Name:off"
  WaylandFlags = "--mm:orc --deepcopy:on -d:waylandBackend --path:. --hint:Name:off " &
    "--passL:\"-Lkoi/wayland/zig-out/lib -lkoi_wayland\" " &
    "--passL:\"-lwayland-client -lxkbcommon\" --passC:-Ikoi/wayland"

proc sh(cmd: string) =
  exec cmd

proc wgpuFlags(): string =
  let webgpuPath = gorge("nimble path webgpu").strip()
  WgpuBaseFlags & " --path:" & quoteShell(webgpuPath / "src")

proc buildWaylandBackend() =
  sh "zig build -Doptimize=Debug --build-file koi/wayland/build.zig"

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

task test, "build test example":
  nimCompile("examples/test", CommonFlags & " -d:debug", nimcache = "/tmp/koi_example_test_d")

task paneltest, "build panel test example":
  nimCompile("examples/paneltest", CommonFlags & " -d:debug", nimcache = "/tmp/koi_paneltest_d")

task minimal, "build minimal wgpu example":
  nimCompile("examples/minimal", wgpuFlags() & " -d:debug", nimcache = "/tmp/koi_minimal_d")

task waylandMinimal, "build native Wayland minimal example":
  buildWaylandBackend()
  nimCompile(
    "examples/wayland_minimal",
    WaylandFlags & " -d:debug",
    nimcache = "/tmp/koi_wayland_minimal_d",
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
  "popup", "dropdown", "menu", "slider", "scrollbar", "colorpicker", "textinput"
]

proc runHeadlessTest(name: string) =
  nimRun(
    "tests/test_" & name,
    CommonFlags & " -d:debug",
    outPath = "/tmp/koi_test_" & name,
    nimcache = "/tmp/koi_test_" & name & "_d",
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

task tests, "run every headless test suite":
  for name in [
    "algorithms", "layout", "draw_state", "widget_behavior",
  ]:
    nimRun(
      "tests/test_" & name,
      CommonFlags & " -d:debug",
      outPath = "/tmp/koi_test_" & name,
      nimcache = "/tmp/koi_test_" & name & "_d",
    )
  for name in WidgetBehaviorTests:
    runHeadlessTest(name)

task testRelease, "build release test example":
  nimCompile("examples/test", CommonFlags & " -d:release", nimcache = "/tmp/koi_example_test_r")

task paneltestRelease, "build release panel test example":
  nimCompile("examples/paneltest", CommonFlags & " -d:release", nimcache = "/tmp/koi_paneltest_r")

task tidy, "format sources and remove generated example binaries":
  for path in walkDirRec("."):
    if path.startsWith("./.git") or path.startsWith("./koi/wayland/.zig-cache"):
      continue
    if path.endsWith(".nim") or path.endsWith(".nims") or path.endsWith(".nimble"):
      sh "nimpretty " & quoteShell(path)

  sh "zig fmt " & quoteShell("koi/wayland/build.zig") & " " &
    quoteShell("koi/wayland/koi_wayland.zig")

  var cleanup = "rm -f"
  for path in [
    "examples/test",
    "examples/test.exe",
    "examples/paneltest",
    "examples/paneltest.exe",
    "examples/minimal",
    "examples/minimal.exe",
    "examples/wayland_minimal",
    "examples/wayland_minimal.exe",
  ]:
    cleanup.add " " & quoteShell(path)
  sh cleanup
