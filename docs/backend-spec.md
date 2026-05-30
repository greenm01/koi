# Koi Backend Spec

This document specifies the windowing and rendering backend split for Koi.
The goal is a native Wayland path on Linux alongside the existing GLFW path
for X11, macOS, and Windows, with wgpu replacing NanoVG/OpenGL as the
renderer on all platforms.

## Design constraints

- The existing GLFW + NanoVG/OpenGL path must continue to compile and run
  unchanged until the wgpu backend is proven stable.
- The Wayland windowing layer must not pull in any non-Wayland platform code.
- The wgpu rendering layer must be platform-agnostic above the surface
  creation seam.
- No double evaluation of widget bodies. Layout and rendering constraints from
  `layout-model.md` are unaffected by this spec.
- Gridmonger must continue to build against the GLFW path without changes.

## Layer overview

```
┌─────────────────────────────────────────────────┐
│                   Koi (Nim)                     │
│           layout · widgets · input state        │
└───────────────────┬─────────────────────────────┘
                    │
        ┌───────────┴───────────┐
        │                       │
┌───────▼───────┐       ┌───────▼────────┐
│  Windowing    │       │   Windowing    │
│  Wayland      │       │   GLFW         │
│  (Zig · C ABI)│       │  (C · existing)│
└───────┬───────┘       └───────┬────────┘
        │                       │
        │  wl_display           │  GLFWwindow
        │  wl_surface           │
        └───────────┬───────────┘
                    │ WGPUSurface
          ┌─────────▼──────────┐
          │   wgpu rendering   │
          │   (webgpu-nim)     │
          │   cross-platform   │
          └────────────────────┘
```

The split has two seams:

1. **Windowing seam** — platform-specific. Either the Zig Wayland layer or
   GLFW provides a window, input events, and a raw surface handle.
2. **Surface seam** — the only platform-specific line in the wgpu path.
   Everything above it (adapter, device, queue, pipelines, render passes) is
   identical on all platforms.

---

## Windowing layer A — Wayland (Zig)

### Purpose

Provides native Wayland windowing and input for Linux sessions running on
compositors that do not support OpenGL deprecation workarounds or where
Wayland-native behavior is required (Niri, Sway, future compositors).

### Dependencies

| Dependency | Source | Role |
| --- | --- | --- |
| `zig` compiler | system / ziglang.org | build tool |
| `zig-wayland` | isaacfreund/zig-wayland | Wayland protocol scanner + libwayland bindings |
| `zig-xkbcommon` | isaacfreund/zig-xkbcommon | keyboard input |
| `libwayland-client` | system | Wayland wire protocol |
| `libxkbcommon` | system | key symbol mapping |
| `libdecor` | system (optional) | client-side window decorations |

### Wayland protocols used

| Protocol | Role |
| --- | --- |
| `wl_compositor` | surface creation |
| `xdg_wm_base` / `xdg_surface` / `xdg_toplevel` | window management |
| `wl_seat` / `wl_pointer` / `wl_keyboard` | input |
| `xdg_decoration_manager_v1` | server-side decorations (Niri supports this) |
| `wp_cursor_shape_v1` | cursor icons (optional, graceful fallback) |
| `wl_output` | monitor info, HiDPI scale factor |

### C ABI surface

The Zig layer compiles to `libkoi_wayland.a` and exposes this interface:

```c
// koi_wayland.h

typedef struct KoiWaylandDisplay KoiWaylandDisplay;
typedef struct KoiWaylandWindow  KoiWaylandWindow;

typedef enum {
  KOI_WAYLAND_CURSOR_DEFAULT,
  KOI_WAYLAND_CURSOR_TEXT,
  KOI_WAYLAND_CURSOR_CROSSHAIR,
  KOI_WAYLAND_CURSOR_POINTER,
  KOI_WAYLAND_CURSOR_RESIZE_EW,
  KOI_WAYLAND_CURSOR_RESIZE_NS,
  KOI_WAYLAND_CURSOR_RESIZE_NWSE,
  KOI_WAYLAND_CURSOR_RESIZE_NESW,
  KOI_WAYLAND_CURSOR_RESIZE_ALL,
} KoiWaylandCursorShape;

typedef struct {
  void (*on_close)       (void* ud);
  void (*on_focus)       (bool focused, void* ud);
  void (*on_resize)      (uint32_t w, uint32_t h, void* ud);
  void (*on_key_down)    (uint32_t keycode, uint32_t mods, void* ud);
  void (*on_key_repeat)  (uint32_t keycode, uint32_t mods, void* ud);
  void (*on_key_up)      (uint32_t keycode, uint32_t mods, void* ud);
  void (*on_mouse_move)  (double x, double y, void* ud);
  void (*on_mouse_button)(uint32_t btn, bool pressed, void* ud);
  void (*on_scroll)      (double dx, double dy, void* ud);
  void (*on_scale)       (double scale, void* ud);
  void* userdata;
} KoiWaylandCallbacks;

// Key callbacks report physical Wayland keycodes for shortcuts. Text input
// uses on_char, which reports layout-aware UTF-32 codepoints from xkbcommon.

KoiWaylandDisplay* koi_wayland_init(void);
KoiWaylandWindow*  koi_wayland_create_window(KoiWaylandDisplay*, uint32_t w,
                                              uint32_t h, const char* title);
void               koi_wayland_set_callbacks(KoiWaylandWindow*,
                                              const KoiWaylandCallbacks*);
void               koi_wayland_poll_events(KoiWaylandDisplay*);
void               koi_wayland_roundtrip(KoiWaylandDisplay*);
void*              koi_wayland_get_wl_display(KoiWaylandDisplay*);
void*              koi_wayland_get_wl_surface(KoiWaylandWindow*);
bool               koi_wayland_window_should_close(KoiWaylandWindow*);
void               koi_wayland_set_title(KoiWaylandWindow*, const char*);
void               koi_wayland_set_size(KoiWaylandWindow*, uint32_t w, uint32_t h);
void               koi_wayland_set_cursor_shape(KoiWaylandWindow*,
                                                 KoiWaylandCursorShape);
void               koi_wayland_destroy_window(KoiWaylandWindow*);
void               koi_wayland_destroy(KoiWaylandDisplay*);
```

`koi_wayland_get_wl_display` and `koi_wayland_get_wl_surface` return opaque
pointers passed directly to wgpu-native's surface descriptor. Koi's Nim code
never dereferences them.

`koi_wayland_set_cursor_shape` uses `wp_cursor_shape_v1` when the compositor
advertises it and is otherwise a no-op. `koi_wayland_window_should_close`
mirrors the close callback so direct event loops can poll close state without
maintaining separate userdata.

### Build

`build.zig` in the Koi repo root fetches `zig-wayland` and `zig-xkbcommon`
via the Zig package manager, generates protocol bindings at build time, and
produces `zig-out/lib/libkoi_wayland.a`. The build is invoked from Nim's
`config.nims` when `waylandBackend` is defined.

---

## Windowing layer B — GLFW (existing)

No changes. Koi's existing GLFW integration handles:

- X11 on Linux (GLFW 3.4, both Wayland and X11 enabled by default)
- macOS
- Windows

For wgpu surface creation on these platforms, GLFW exposes raw handles:

```c
// X11
Display* x11_display = glfwGetX11Display();
Window   x11_window  = glfwGetX11Window(window);

// macOS — CAMetalLayer via glfwGetCocoaWindow
// Windows — HWND via glfwGetWin32Window
```

These are passed to the appropriate `WGPUSurfaceSource*` descriptor. The
`webgpu-nim` extras module already wraps this.

---

## Rendering layer — wgpu (cross-platform)

### Purpose

Replaces NanoVG/OpenGL on all platforms. Handles all GPU work above the
surface creation seam.

### Dependencies

| Dependency | Source | Role |
| --- | --- | --- |
| `wgpu-native` | gfx-rs/wgpu-native | WebGPU C API implementation |
| `webgpu-nim` | RowDaBoat/webgpu-nim | Nim wrapper (Futhark-generated) |
| `cargo` | system | required to build wgpu-native |

Koi normally resolves `webgpu-nim` with `nimble path webgpu`. Set
`KOI_WEBGPU_PATH` to a local `webgpu-nim` checkout when testing dependency
patches before they are released. The current local fork branch is
`greenm01/webgpu-nim:wgvk-stencil-render-pass`, which pins WGVK to the stencil
render-pass fix while upstream WGVK PR 51 is pending.

wgpu-native is compiled once with Cargo and linked statically. Pre-built
release binaries from the gfx-rs GitHub releases can substitute for a local
build.

### Platform matrix

| Platform | wgpu backend | Surface source |
| --- | --- | --- |
| Linux / Wayland | Vulkan | `WGPUSType_SurfaceSourceWaylandSurface` |
| Linux / X11 | Vulkan | `WGPUSType_SurfaceSourceXlibWindow` |
| macOS | Metal | `WGPUSType_SurfaceSourceMetalLayer` |
| Windows | D3D12 | `WGPUSType_SurfaceSourceWindowsHWND` |

wgpu selects the GPU backend automatically. `WGPU_BACKEND` can override at
runtime.

---

## Surface creation seam

This is the only platform-specific code in the wgpu path. It lives in a
single Nim module `backends/surface.nim`:

```nim
# backends/surface.nim

proc createSurface*(instance: WGPUInstance): WGPUSurface =
  when defined(waylandBackend):
    # Zig windowing layer provides raw Wayland handles
    let wlDisplay = koiWaylandGetWlDisplay(gDisplay)
    let wlSurface = koiWaylandGetWlSurface(gWindow)
    let src = WGPUSurfaceSourceWaylandSurface(
      chain:   WGPUChainedStruct(sType: WGPUSType_SurfaceSourceWaylandSurface),
      display: wlDisplay,
      surface: wlSurface,
    )
    wgpuInstanceCreateSurface(instance, addr WGPUSurfaceDescriptor(
      nextInChain: cast[ptr WGPUChainedStruct](addr src)
    ))

  elif defined(linux):
    # GLFW X11 path
    let display = glfwGetX11Display()
    let win     = glfwGetX11Window(gGlfwWindow)
    let src = WGPUSurfaceSourceXlibWindow(
      chain:   WGPUChainedStruct(sType: WGPUSType_SurfaceSourceXlibWindow),
      display: display,
      window:  win,
    )
    wgpuInstanceCreateSurface(instance, addr WGPUSurfaceDescriptor(
      nextInChain: cast[ptr WGPUChainedStruct](addr src)
    ))

  elif defined(macosx):
    # GLFW Metal path — CAMetalLayer from NSWindow
    ...

  elif defined(windows):
    # GLFW Win32 path
    ...
```

Everything above this module — adapter selection, device creation, swap
chain configuration, render pass recording, pipeline compilation — is
identical across platforms and goes through `webgpu-nim` unchanged.

---

## Nim module layout

```
koi/
├── backends/
│   ├── surface.nim        ← surface creation seam (new)
│   ├── wayland.nim        ← importc bindings to koi_wayland.h (new)
│   ├── glfw.nim           ← existing GLFW bindings (unchanged)
│   └── wgpu_renderer.nim  ← wgpu device, queue, pipelines (new, cross-platform)
├── wayland/
│   ├── build.zig          ← Zig build for libkoi_wayland.a (new)
│   ├── koi_wayland.zig    ← Zig windowing implementation (new)
│   └── koi_wayland.h      ← C header for Nim importc (new)
└── config.nims            ← build routing by compile-time define
```

---

## Build routing

```nim
# config.nims

when defined(waylandBackend):
  # Build the Zig windowing layer
  exec "zig build -Doptimize=ReleaseSafe --build-file wayland/build.zig"
  switch("passL", "-Lwayland/zig-out/lib -lkoi_wayland")
  switch("passL", "-lwayland-client -lxkbcommon")
  # wgpu-native (built separately or pre-built)
  switch("passL", "-Lwgpu-native/lib -lwgpu_native")
  switch("define", "koiWgpu")

elif defined(linux) or defined(macosx) or defined(windows):
  # GLFW path — existing behaviour
  switch("passL", "-lglfw")
  when defined(koiWgpu):
    switch("passL", "-Lwgpu-native/lib -lwgpu_native")
```

Koi is built with `-d:waylandBackend` to activate the Zig windowing layer and
wgpu renderer. Without the flag, the GLFW + NanoVG/OpenGL path builds as
before. Gridmonger never passes `-d:waylandBackend` and is unaffected.

---

## Migration path

The wgpu renderer and Wayland windowing layer are independent work items that
can land in either order.

1. **Wayland windowing first** — implement `koi_wayland.zig` and
   `backends/wayland.nim`. Wire input events to Koi's existing event model.
   Keep NanoVG/OpenGL for rendering for now; surface creation under Wayland
   via OpenGL/EGL is possible as a temporary bridge.

2. **wgpu renderer** — implement `backends/wgpu_renderer.nim` against the
   GLFW + X11 path first, where the surface creation is simpler and the
   existing test suite runs. Prove rendering parity with NanoVG.

3. **Wayland + wgpu combined** — wire `backends/surface.nim` to the Zig
   windowing layer. This is the final production path on Niri.

4. **Gridmonger fork validation** — build Gridmonger against Koi with
   `-d:waylandBackend` to validate the layout model and rendering pipeline
   against a real application before upstreaming layout changes.

---

## Non-goals

- No wgpu backend for WASM. Not planned.
- No dynamic linking of wgpu-native. Static only.
- No changes to Koi's widget API, row layout, or manual space API.
- No removal of the GLFW path. It remains the default and the Gridmonger path.
- No support for Wayland on macOS or Windows.
