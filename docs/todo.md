# Koi Todo

This file tracks current follow-up work. Historical audit notes were folded down
to the deferred candidates that still look useful.

## Active Items

- Replace the temporary `greenm01/webgpu-nim:wgvk-stencil-render-pass` pin with
  an upstream `webgpu-nim` submodule bump after WGVK PR 51 merges.
- Track the local WGVK and `webgpu-nim` fork status until the stencil render
  pass fix is released upstream.
- Add a compact backend compatibility matrix for Wayland, X11, macOS, and
  Windows after each platform has a fresh smoke pass.
- Keep Gridmonger in the WebGPU smoke checklist: theme edits, HSE picker
  rendering, quit confirmation mouse input, and map rendering.
- Keep a small benchmark history for draw calls, vertices, indices, staged
  upload bytes, and expanded-vertex byte estimates.

## Notes

- Use `KOI_WEBGPU_PATH=/path/to/webgpu-nim` when building Koi against a local
  dependency checkout instead of the Nimble cache.
- `dumpWebGpuDiagnostics` is the first stop for backend feature/format reports.
- Wayland cursor shape and close/resize polish are tracked by the native
  Wayland ABI and smoke/demo builds.
- Text-editing profiling is repeatable with `nimble benchTextEditing`; current
  profiling keeps the per-operation rune navigation approach until benchmark
  results justify a persistent cache.
