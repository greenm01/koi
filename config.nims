import std/os
import std/strutils

when defined(waylandBackend):
  exec "zig build -Doptimize=Debug --build-file koi/wayland/build.zig"
  switch("passL", "-Lkoi/wayland/zig-out/lib -lkoi_wayland")
  switch("passL", "-lwayland-client -lxkbcommon")
  switch("passC", "-Ikoi/wayland")

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

proc setWebGpuCompileParams() =
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
  --d:
    debug
  setWebGpuCompileParams()
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

task testWebGpuDrawState, "run headless WebGPU draw-state tests":
  --d:
    debug
  --nimcache:
    "/tmp/koi_test_webgpu_draw_state_d"
  --out:
    "/tmp/koi_test_webgpu_draw_state"
  setCommonCompileParams()
  setCommand "r", "tests/test_webgpu_draw_state"

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
