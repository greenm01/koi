# WebGPU Notes

This document records WebGPU ecosystem context that affects Koi's renderer. The
implementation architecture remains in [backend-spec.md](./backend-spec.md).

## External context

Branimir Karadzic's bgfx note,
[WebGPU backend, second take](https://bkaradzic.github.io/posts/webgpu/), is
useful context for Koi but not a reason to switch to bgfx. The relevant signal
is that WebGPU is becoming a serious native rendering target, while the native C
ecosystem is still uneven across Dawn, wgpu-native, Emscripten, headers, and
validation behavior.

The bgfx work also reinforces several practical points:

- Prefer the C API boundary over C++-specific bindings.
- Keep backend feature and format assumptions explicit.
- Use object labels aggressively so validation output is useful.
- Expect WebGPU behavior to feel closer to Metal, D3D11, and D3D12 than to
  raw Vulkan, even when the selected native backend is Vulkan.
- Treat shader translation and backend portability as separate problems.

bgfx also carries a modified NanoVG copy, but the useful changes are mostly in
the bgfx renderer wrapper: view-id control, framebuffer helpers, bgfx texture
wrapping, transient buffers, stencil fills, convex fill handling, and
flush-before-`uint16_t` index overflow. It does not replace NanoVG's path
processing with CDT or a retained polygon mesh. Koi should borrow backend
tactics, not adopt bgfx's renderer or fork NanoVG around bgfx concepts.

## Koi position

Koi keeps a direct NanoVG-to-WebGPU backend. We should borrow proven backend
tactics from bgfx and similar engines, but we should not hide Koi's renderer
behind bgfx.

Current policy:

- Keep the WebGPU backend small and explicit.
- Keep WGSL hand-authored while the shader set is small.
- Keep the surface creation seam isolated from renderer code.
- Keep the binding layer version-pinned when testing local WebGPU fixes.
- Keep Gridmonger in the smoke-test loop because it exercises the real app
  path.

## Practical lessons

The renderer should be easy to debug when the WebGPU implementation changes
under us.

- Label every WebGPU object with useful names: device, queue, buffers, textures,
  texture views, bind groups, pipelines, render passes, command encoders, and
  capture/readback resources.
- Add a backend diagnostics dump for adapter name, selected surface format,
  alpha mode, stencil/depth format, limits, features, and selected platform
  surface type.
- Keep validation-friendly resource setup: explicit usage flags, clear pass
  labels, conservative format selection, and narrow pipeline keys.
- Keep dependency overrides documented. Use `KOI_WEBGPU_PATH` when testing a
  local `webgpu-nim` checkout.
- Prefer direct, measured optimizations over broad renderer rewrites. The
  current indexed draw path and convex-fill fast path are examples of changes
  that improve the existing backend without changing the public rendering model.

## Current risks

- `webgpu.h` and native WebGPU bindings are still fragmented across projects.
- Koi currently depends on local WebGPU binding fixes until upstream releases
  catch up.
- Feature and format support can differ between WGVK, wgpu-native, Dawn, and
  browser/Emscripten paths.
- Validation behavior and error messages vary enough that labels and diagnostic
  dumps are not optional for serious debugging.

## Mitigation plan

| Risk | Mitigation |
| --- | --- |
| `webgpu.h` fragmentation | Keep Koi behind `webgpu-nim`, pin known-good revisions, and document the local override workflow with `KOI_WEBGPU_PATH`. |
| Local WGVK and `webgpu-nim` fixes | Track fork branches in [todo.md](./todo.md). Remove pins only after the upstream merge lands and Koi plus Gridmonger smoke tests pass. |
| Feature and format variance | Use `dumpWebGpuDiagnostics` for adapter info, surface format, alpha mode, stencil/depth format, limits, features, and platform surface type. |
| Validation variance | Require useful labels on every WebGPU object, render pass, command encoder, shader module, pipeline, bind group, texture, and buffer. |
| Backend regressions | Keep `nimble testWindowRenderer`, `nimble testHeadless`, `nimble bench`, and Gridmonger Wayland smoke builds as the minimum validation loop. |
| Renderer performance drift | Keep benchmark output reporting draw calls, vertices, indices, staged upload bytes, and old expanded-vertex byte estimates. |
| bgfx/NanoVG confusion | Treat bgfx as a backend reference only. Do not port bgfx's public NanoVG wrapper or framebuffer API unless Koi needs the same feature directly. |

## Follow-up work

Now:

- Track WGVK and `webgpu-nim` fork status in [todo.md](./todo.md).

Next:

- Add a backend compatibility matrix for Wayland, X11, macOS, and Windows.
- Add a short Gridmonger smoke checklist for theme editing, color picker
  rendering, quit confirmation input, and map rendering.
- Keep a small benchmark history for indexed rendering, convex fills, draw call
  count, and upload bytes.

Later:

- Evaluate Dawn or wgpu-native only as an additional backend option if WGVK
  becomes a blocker.
- Revisit moving paint data from vertices to per-call uniforms only if
  benchmark data shows vertex bandwidth is still the limiting cost.

## Validation loop

Use the local binding checkout while WGVK and `webgpu-nim` fixes are pinned:

```sh
KOI_WEBGPU_PATH=/home/niltempus/src/webgpu-nim nimble testHeadless
KOI_WEBGPU_PATH=/home/niltempus/src/webgpu-nim nimble testWindowRenderer
KOI_WEBGPU_PATH=/home/niltempus/src/webgpu-nim nimble bench
```

Gridmonger stays in the smoke loop because it exercises the real app path:

```sh
cd /home/niltempus/dev/gridmonger-koi
KOI_PATH=/home/niltempus/dev/koi-webgpu KOI_WEBGPU_PATH=/home/niltempus/src/webgpu-nim nimble debugWayland
```

Smoke Gridmonger by opening the theme editor, changing a color, checking the
HSE picker triangle, dismissing the quit confirmation with the mouse, and
rendering a map.
