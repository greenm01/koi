# Koi Todo

This file tracks current follow-up work. Historical audit notes were folded down
to the deferred candidates that still look useful.

## Backend And Rendering

- Wire the native Wayland window path into the default wgpu surface creation
  path, beyond the current ABI and smoke examples.
- Add image-based renderer validation for layer order, paint state, texture
  sampling, clipping, and blend behavior.
- Move inline wgpu shader source out of Nim modules and into dedicated shader
  files once the backend API has settled.
- Coalesce adjacent wgpu draw calls with the same texture and blend state after
  image-based coverage exists.
- Complete broader Wayland input support, especially keyboard/xkb mapping,
  modifiers, repeat, cursor shape, output scale, and robust close/resize flow.

## Widgets And Input

- Add dropdown keyboard navigation before deeper popup/list refactors.
- Add double-click word selection and richer selection gestures to text areas.
- Extract deeper slider and scrollbar drag-state logic after focused tests cover
  drag, hidden cursor behavior, and track-repeat behavior.
- Unify horizontal and vertical scrollbar implementations around one orientation
  helper after the pure math tests settle.
- Revisit the scrollbar click-repeat edge cases:
  - click and hold until the track moves under the cursor, then click and hold
    at the opposite side without leaving the widget;
  - click-hold while a tooltip is visible.
- Normalize disabled state and custom draw hooks across remaining widgets.

## Text And Editing

- Retest text-field shortcuts with edge cases:
  - empty string;
  - single space;
  - one character with cursor at start and end;
  - multiple characters with cursor at end.
- Retest text-area shortcuts with edge cases:
  - empty string;
  - single space;
  - single newline;
  - two newline characters;
  - cursor in first and last rows;
  - cursor at first and last characters.
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
