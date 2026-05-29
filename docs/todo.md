# Koi Todo

This file tracks current follow-up work. Historical audit notes were folded down
to the deferred candidates that still look useful.

## Backend And Rendering

- Wire the native Wayland window path into the default wgpu surface creation
  path, beyond the current ABI and smoke examples.
- Complete broader Wayland input support, especially keyboard/xkb mapping,
  modifiers, repeat, cursor shape, output scale, and robust close/resize flow.

## Widgets And Input

- Extract deeper slider and scrollbar drag-state logic now that focused tests
  cover drag, hidden cursor behavior, and track-repeat behavior.
- Unify horizontal and vertical scrollbar implementations around one orientation
  helper after the pure math tests settle.
- Normalize disabled state and custom draw hooks across remaining widgets.

## Text And Editing

- Replace repeated rune-length scans in text editing with cached rune metadata
  only if profiling shows it matters for real text sizes.

## Layout And Theming

- Add more visual examples for `fit`, wrapped text, scroll views, tables, and
  popup followers now that the unified layout model is shipped.
- Finish complete theming coverage, including global theme parameters such as
  font, corner roundness, and colors.
- Decide whether gradient, shadow, and text-shadow style support belongs in core
  Koi or in renderer-specific extensions.
- Revisit tooltip sizing and formatting against the shipped wrapped-text
  measurement path.
