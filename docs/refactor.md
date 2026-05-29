# Koi Refactor Direction

This document records the direction of the Koi refactor. It folds in the engine
intent from `engine-spec.md` and adds direction for borrowing layout and widget
ideas from Nuklear without turning Koi into a Nuklear clone.

The current layout direction is documented in `layout-model.md`. That document
describes a single unified layout solver: Clay-inspired sizing
(`fixed`/`grow`/`percent`/`fit`) drives one container model, and the row,
vertical auto-layout, and manual-space APIs become presets over it rather than
separate systems. The row, space, and bounds-resolution layout-core work
described later in this document has shipped together with the container solver
and same-frame solve execution model.

Koi remains a small immediate-mode UI library for Nim. The UI is still described
by function calls every frame, and interaction, layout, style, focus, and draw
state still live in Koi's central runtime state.

## Goals

- Build one unified layout solver and express vertical auto-layout, rows, and
  manual spaces as presets over it.
- Use Nuklear as a source of proven ideas for rows, layout spaces, widget
  coverage, and behavior split points.
- Keep APIs Koi-native and Nim-friendly.
- Get the execution model right deliberately, even where that replaces current
  types and call styles.

## Non-Goals

- Do not port Nuklear's C API.
- Do not adopt Nuklear's window and panel architecture.
- Do not make every widget a retained layout node.
- Do not mix unrelated documentation cleanup with runtime implementation work.

Backward compatibility with Gridmonger and the current public call shape is no
longer a constraint. Prefer Koi-native names and lexical Nim templates over
Nuklear-like C naming.

## Current Engine Model

Koi is stateful immediate mode:

- The user describes UI by calling widget procs every frame.
- Widgets derive stable item IDs from call sites unless an explicit ID is used.
- Runtime state tracks hot item, active item, focus capture, layout, style, draw
  layers, input, and per-widget persistent state.
- Rendering is queued into draw layers and flushed at frame end.

A normal widget follows this cycle:

1. Resolve bounds from explicit arguments or layout state.
2. Hit-test against the current mouse position and clip rectangle.
3. Update hot, active, focus, and action state.
4. Emit draw commands using the current style and draw layer.
5. Advance layout state when the widget used auto-layout.

This cycle is part of Koi's design. Refactors should make it clearer and easier
to reuse, not hide it behind a second model.

## Layout Direction

The target is one unified container solver (see `layout-model.md`). Vertical
auto-layout, rows, and manual spaces become presets over it rather than separate
positioning layers. All of them feed widget bounds through the same widget
execution cycle.

The row, layout-space, bounds-resolution, and unified solver work below shipped
(`koi/layout.nim`): `AutoLayoutParams`/`autoLayoutPre`/`autoLayoutPost`, the
`ColMode` columns (`cmStatic`/`cmDynamic`/`cmRatio`/`cmVariable`) with
`beginRowLayout`/`layoutRow`, the `lmSpace` draw-offset spaces, layout slots,
followers, and frame-local solved rect caching. They are retained here as the
design record for the unified node and presets.

### Rows (shipped)

Rows provide deterministic column allocation before widget calls consume
bounds. A row knows:

- its origin and available width;
- its height;
- its item spacing;
- its column definitions;
- its current column index.

Column kinds should stay Koi-native:

- fixed pixel width;
- ratio of available row width;
- dynamic share of remaining width;
- variable width with a minimum, if needed later.

Do not rely on a single mutable "current column mode" for the whole row. The row
should have enough information to resolve each column in order.

### Layout Spaces (shipped)

A layout space creates a local coordinate system. Inside a space:

- explicit widget coordinates are relative to the space origin;
- draw offsets and hit testing must agree;
- the space consumes vertical layout height when it ends;
- the caller should be able to query or reason about the space bounds.

Layout spaces should not create a second widget model. They only change the
coordinate origin and available rectangle.

### Bounds Resolution (shipped)

Every shorthand widget should resolve bounds through one path:

```text
autoLayoutPre()
widget(id, resolvedX, resolvedY, resolvedW, resolvedH, ...)
autoLayoutPost()
```

The layout stack may affect `autoLayoutPre()`, but widgets should not need to
know which layout mode produced their bounds.

## Nuklear Ideas Worth Borrowing

Borrow concepts, not naming or architecture.

Good ideas to adapt:

- row layouts with fixed, ratio, dynamic, and template-like columns;
- explicit layout spaces for local coordinates;
- helpers for current widget bounds and current layout-space bounds;
- a clear split between widget bounds resolution, behavior, and drawing;
- a broad widget checklist: property editors, progress, tree/header, combo,
  contextual popup, tooltip, chart, color picker, menus, and list view.

Ideas to avoid:

- Nuklear's C-style API names as primary Koi API;
- Nuklear's window/panel ownership model;
- C memory configuration patterns;
- direct translation of `nk_context` into Koi;
- requiring users to call begin/end blocks around all UI.

Koi already has Nim templates, named arguments, draw layers, styles, and explicit
bounds. Use those strengths.

## Widget Direction

Widget expansion should happen after the unified layout core is stable. When
adding or normalizing widgets:

- keep style passed through Nim defaults and named arguments;
- keep custom draw procs where the widget already supports them;
- split shared behavior only when it removes real duplication;
- make disabled state and focus behavior consistent across widgets;
- keep generated parameter-style UI possible for host applications.

Nuklear can guide the widget checklist, but Koi should keep its simpler user
surface.

## Refactor Sequencing

1. Finish the current split-module refactor without changing behavior. (done)
2. Stabilize the row/space/bounds-resolution layout core. (done — see the
   shipped sections above)
3. Build the unified container solver and execution model per `layout-model.md`:
   - frame-local arena with `fixed`/`grow`/`percent`/`fit` sizing;
   - solve at `endFrame`, draws deferred to solved rects, interaction read from
     previous-frame rects;
   - fold rows, spaces, and vertical auto-layout into the unified node as
     presets. (done)
4. Add `fit` and text wrapping via the `measureText` callback. (done)
5. Integrate existing widgets, overlays, scroll regions, dialogs, tables, and
   framed containers with layout slots/followers. (done)
6. Plan widget feature expansion from the Nuklear checklist as a separate pass.

## Acceptance Checks

The unified layout refactor is accepted when:

- the unified solver produces predictable rects for `fixed`/`grow`/`percent`,
  with row, auto-layout, and space presets resolving through it;
- visuals are current on the frame layout changes (no stale-visual lag);
- widget bodies are evaluated once per frame (no double evaluation);
- layout-space examples draw and hit-test in the same coordinate system;
- additions use Koi-native names;
- docs and examples describe the shipped call style;
- pure sizing/placement tests cover sizing, alignment, gap, and the one-frame
  interaction-lag semantics.

## Assumptions

- `engine-spec.md` remains in place until a later cleanup pass decides whether
  to remove or replace it.
- The unified layout core comes before widget feature expansion.
