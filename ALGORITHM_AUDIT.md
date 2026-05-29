# Koi Algorithm Audit

This audit is correctness-first. It records the algorithmic weak spots found in
the current core Koi fork and separates fixes made in this pass from deferred
work that needs broader design or visual validation.

## Fixed In This Pass

1. Dropdown hover math treated list padding as selectable item space.
   - Added a pure hover-index helper.
   - Padding and rows beyond the visible or real item range now return no item.
   - Scroll wheel events are consumed only while the pointer is inside the open
     item list.

2. Scrollbar thumb/value math did unchecked division across both orientations.
   - Added shared pure helpers for range, thumb length, thumb-to-value,
     value-to-thumb, and track-click stepping.
   - Degenerate ranges now produce a full-length thumb and stable value instead
     of relying on divide-by-zero behavior.

3. Auto-layout divided by `itemsPerRow` directly.
   - Added an effective item count helper that treats zero as one column.
   - Standard layout now advances deterministically with invalid zero input.

4. Text insertion limits ignored the selected text being replaced.
   - Insert length now accounts for the post-deletion base length.
   - Delete-right at the end of a field now avoids unnecessary substring work.

5. Text field caret and glyph tracking kept the end cursor short of the right edge.
   - Added pure helpers for text-field view state, cursor X, and mouse-to-cursor
     mapping.
   - Long single-line text now keeps the caret visible at the right edge when
     the cursor is after the last character.
   - The helpers are covered with synthetic glyph metrics and do not require a
     live NanoVG context.

6. Text area editing had no tested row/cursor layer.
   - Added pure helpers for wrapped row selection, display-start clamping, and
     row-local mouse/caret mapping.
   - Active text areas now place the cursor from mouse clicks and draw a caret.
   - Selection rendering, drag selection, vertical cursor movement, and scrollbar
     behavior remain deferred.

7. Text area selection and scrolling had state but no complete behavior.
   - Added row helpers for selection spans, line starts/ends, row deltas, and
     scroll clamping.
   - Text areas now render selection, support drag selection, handle vertical
     and page movement, consume scroll-wheel rows, and expose an embedded
     scrollbar while focused.
   - Double-click word selection and advanced selection gestures remain
     deferred.

8. Simple widget behavior duplicated hot/active/click state.
   - Added internal behavior helpers for hot/active capture, release-click
     detection, plain widget states, selectable widget states, and radio button
     draw states.
   - Button, toggle button, checkbox, and radio buttons now share the tested
     helper layer while keeping their public APIs and draw procs unchanged.
   - Slider and scrollbar behavior remains deferred because their drag and
     repeat states need separate coverage.

9. Drag widget behavior duplicated capture and draw-state code.
   - Added internal helpers for drag-widget capture and normal/hover/down state
     selection.
   - Sliders and scrollbars now share those helpers while keeping their public
     APIs, draw behavior, and drag state machines unchanged.
   - Full slider/scrollbar drag-state unification remains deferred.

## High-Value Follow-Ups

1. WebGPU backend draw expansion.
   - The backend expands fans and strips into triangle lists on the CPU and
   binds per draw call.
   - Before optimizing, add image-based or geometry tests for scissor,
   composite-operation behavior, and antialiasing so performance changes do
   not regress rendering.

2. Default style copies.
   - Default style accessors deep-copy ref-object styles on every call.
   - This is correct for isolation, but expensive if done in hot paths. Cache or
   borrowing APIs would need an explicit mutability policy.

## Deferred Candidates

- Unify horizontal and vertical scrollbar implementations around one orientation
  helper after the pure math tests settle.
- Extract deeper slider and scrollbar drag-state logic only after drag, hidden
  cursor, and track-repeat behavior have focused tests.
- Add dropdown keyboard navigation before deeper popup/list refactors.
- Add double-click word selection and richer selection gestures to text areas
  after the basic multiline behavior settles.
- Replace repeated rune-length scans in text editing with cached rune metadata
  only if profiling shows it matters for real text sizes.
- Coalesce adjacent WebGPU draw calls with the same texture after correctness
  coverage exists for layer order and paint state.
