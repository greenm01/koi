import std/os
import std/strutils

proc setCommonCompileParams() =
  --gc:
    orc
  --deepcopy:
    on
  --d:
    nimPreviewFloatRoundtrip
  --d:
    nvgGL3
  --d:
    glfwStaticLib
  --d:
    glStaticProcs
  --path:
    "."
  --hint:
    "Name:off"

task test, "build test":
  --d:
    debug
  setCommand "c", "examples/test"
  setCommonCompileParams()

task paneltest, "build panel test":
  --d:
    debug
  setCommand "c", "examples/paneltest"
  setCommonCompileParams()

task webgpuMinimal, "build WebGPU minimal example":
  let webgpuPath = gorge("nimble path webgpu").strip()

  --gc:
    orc
  --deepcopy:
    on
  --d:
    nimPreviewFloatRoundtrip
  --d:
    wgpu
  --d:
    wgvkWGSL
  --d:
    NoGLFW
  --d:
    koiWebGpu
  --d:
    wayland
  --path:
    "."
  switch("path", webgpuPath / "src")
  switch("passC", "-Wno-incompatible-pointer-types")
  --hint:
    "Name:off"
  --d:
    debug
  setCommand "c", "examples/webgpu_minimal"

task testLayout, "run headless layout tests":
  --d:
    debug
  --nimcache:
    "/tmp/koi_test_layout_d"
  --out:
    "/tmp/koi_test_layout"
  setCommonCompileParams()
  setCommand "r", "tests/test_layout"

task testAlgorithms, "run headless algorithm tests":
  --d:
    debug
  --nimcache:
    "/tmp/koi_test_algorithms_d"
  --out:
    "/tmp/koi_test_algorithms"
  setCommonCompileParams()
  setCommand "r", "tests/test_algorithms"

task testWidgetBehavior, "run headless widget behavior tests":
  --d:
    debug
  --nimcache:
    "/tmp/koi_test_widget_behavior_d"
  --out:
    "/tmp/koi_test_widget_behavior"
  setCommonCompileParams()
  setCommand "r", "tests/test_widget_behavior"

task testRelease, "build test":
  --d:
    release
  setCommand "c", "examples/test"
  setCommonCompileParams()

task paneltestRelease, "build panel test":
  --d:
    release
  setCommand "c", "examples/paneltest"
  setCommonCompileParams()
