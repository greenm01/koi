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

## High-Value Follow-Ups

1. Text field caret and glyph tracking.
   - The TODO about the cursor at the right edge is likely in display-start
     calculation, not shortcut handling.
   - Add visual/state tests around long single-line text before changing it.

2. Text area editing model.
   - Text area recalculates wrapped rows after edits and has partial state for
     cursor and selection behavior.
   - The next pass should extract row/cursor mapping helpers before adding
     vertical movement, selection drawing, or scrollbar behavior.

3. Widget behavior duplication.
   - Button, toggle button, checkbox, radio buttons, sliders, and scrollbars
     repeat hot/active/disabled state transitions.
   - Extract this only after the current behavior has tests, because small
     differences are user-visible.

4. WebGPU backend draw expansion.
   - The backend expands fans and strips into triangle lists on the CPU and
     binds per draw call.
   - Before optimizing, add image-based or geometry tests for scissor,
     composite-operation behavior, and antialiasing so performance changes do
     not regress rendering.

5. Default style copies.
   - Default style accessors deep-copy ref-object styles on every call.
   - This is correct for isolation, but expensive if done in hot paths. Cache or
     borrowing APIs would need an explicit mutability policy.

## Deferred Candidates

- Unify horizontal and vertical scrollbar implementations around one orientation
  helper after the pure math tests settle.
- Add dropdown keyboard navigation before deeper popup/list refactors.
- Replace repeated rune-length scans in text editing with cached rune metadata
  only if profiling shows it matters for real text sizes.
- Coalesce adjacent WebGPU draw calls with the same texture after correctness
  coverage exists for layer order and paint state.
