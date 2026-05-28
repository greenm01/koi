# Koi Refactor Direction

This document records the next step after the current Koi refactor. It folds in
the engine intent from `ENGINE_SPEC.md` and adds direction for borrowing layout
and widget ideas from Nuklear without turning Koi into a Nuklear clone.

Koi remains a small immediate-mode UI library for Nim. The UI is still described
by function calls every frame, and interaction, layout, style, focus, and draw
state still live in Koi's central runtime state.

## Goals

- Preserve Koi's existing public shape for Gridmonger and current users.
- Keep explicit widget bounds as the base model.
- Keep the existing vertical auto-layout as the default convenience path.
- Add hierarchical layout blocks as an extra layer, not a replacement.
- Use Nuklear as a source of proven ideas for rows, layout spaces, widget
  coverage, and behavior split points.
- Keep APIs Koi-native and Nim-friendly.

## Non-Goals

- Do not port Nuklear's C API.
- Do not adopt Nuklear's window and panel architecture.
- Do not force every widget through a new layout model.
- Do not remove explicit `x, y, w, h` widget calls.
- Do not break Gridmonger-style call sites.
- Do not mix documentation cleanup with runtime implementation work.

## Compatibility Rules

Existing Koi APIs must continue to compile and behave the same unless a later
document explicitly marks a break and gives a migration path. The default rule is
no breakage.

The following call styles must remain valid:

```nim
button(x, y, w, h, "OK")
button("OK")
label(x, y, w, h, "Name")
textField(x, y, w, h, value)
```

Every widget that currently accepts explicit bounds should keep accepting them.
Every widget that currently has an auto-layout shorthand should keep it.

New layout APIs should be additive. Prefer Koi-native names and lexical Nim
templates over Nuklear-like C naming.

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

Koi has three positioning layers. They should stay ordered by authority:

1. Explicit positioning
2. Standard vertical auto-layout
3. Hierarchical layout blocks

Explicit positioning is the ground truth. A widget with `x, y, w, h` is placed at
those virtual-pixel bounds, adjusted only by the current draw offset or view
context.

Standard auto-layout remains the simple path. It flows top to bottom, uses
`AutoLayoutParams`, and advances through `autoLayoutPre()` and
`autoLayoutPost()`.

Hierarchical layout blocks should be additive. They may provide rows, columns,
and local spaces, but they still feed widget bounds through the same widget
execution cycle.

### Rows

Rows should provide deterministic column allocation before widget calls consume
bounds. A row should know:

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

### Layout Spaces

A layout space creates a local coordinate system. Inside a space:

- explicit widget coordinates are relative to the space origin;
- draw offsets and hit testing must agree;
- the space consumes vertical layout height when it ends;
- the caller should be able to query or reason about the space bounds.

Layout spaces should not create a second widget model. They only change the
coordinate origin and available rectangle.

### Bounds Resolution

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

Widget expansion should happen after the layout core is stable. When adding or
normalizing widgets:

- preserve explicit and auto-layout call forms;
- keep style passed through Nim defaults and named arguments;
- keep custom draw procs where the widget already supports them;
- split shared behavior only when it removes real duplication;
- make disabled state and focus behavior consistent across widgets;
- keep generated parameter-style UI possible for host applications.

Nuklear can guide the widget checklist, but Koi should keep its simpler user
surface.

## Refactor Sequencing

1. Finish the current split-module refactor without changing behavior.
2. Create this document as the next-step design record.
3. Stabilize the layout core:
   - define row data clearly;
   - make column width resolution deterministic;
   - make layout spaces explicit about origin, bounds, and vertical advance;
   - add small examples for rows, ratios, dynamic columns, and spaces.
4. Normalize widget bounds resolution so every auto-layout shorthand follows the
   same pre/widget/post pattern.
5. Only then plan widget feature expansion from the Nuklear checklist.

## Acceptance Checks

The next implementation pass should be accepted only if:

- existing explicit widget calls still compile;
- existing auto-layout shorthand calls still compile;
- Gridmonger can still point at the refactored Koi without API churn;
- row layout examples have predictable widths;
- layout-space examples draw and hit-test in the same coordinate system;
- Nuklear-inspired additions use Koi-native names;
- docs and examples describe the intended call style.

## Assumptions

- The active refactor in `~/src/koi` is still in progress.
- `ENGINE_SPEC.md` remains in place until a later cleanup pass decides whether
  to remove or replace it.
- This document is planning guidance, not permission to break the API.
- Layout core work comes before widget feature expansion.
