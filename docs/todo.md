# Koi Todo

This file tracks current follow-up work. Historical audit notes were folded down
to the deferred candidates that still look useful.

## Active Items

- Replace the temporary `greenm01/webgpu-nim:wgvk-stencil-render-pass` pin with
  an upstream `webgpu-nim` submodule bump after WGVK PR 51 merges.

## Notes

- Use `KOI_WEBGPU_PATH=/path/to/webgpu-nim` when building Koi against a local
  dependency checkout instead of the Nimble cache.
- Wayland cursor shape and close/resize polish are tracked by the native
  Wayland ABI and smoke/demo builds.
- Text-editing profiling is repeatable with `nimble benchTextEditing`; current
  profiling keeps the per-operation rune navigation approach until benchmark
  results justify a persistent cache.
