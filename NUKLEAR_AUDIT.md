# Nuklear Audit

This audit compares Koi with the local Nuklear source in `~/src/Nuklear`.
Nuklear is a reference for proven immediate-mode layout and widget coverage, not
a target architecture. Koi should keep explicit widget bounds, vertical
auto-layout, additive layout blocks, Nim-friendly APIs, and Gridmonger
compatibility.

Recommendations use four labels:

- `adopt`: add the feature directly in Koi terms.
- `adapt`: keep the idea, but reshape it around Koi's API and state model.
- `defer`: useful, but depends on lower-level layout, focus, popup, or drawing
  work first.
- `reject`: do not copy this into Koi.

Priorities are `P0`, `P1`, `P2`, and `Later`.

## Layout Feature Matrix

| Area | Nuklear Reference | Koi Status | Gap | Recommendation | Priority |
| --- | --- | --- | --- | --- | --- |
| Explicit widget bounds | Widgets consume bounds resolved from the active layout row or layout space. | Core Koi model. Explicit `x, y, w, h` calls remain the base path. | None. | Keep this as the source of truth. | P0 |
| Vertical auto-layout | Nuklear rows are the normal layout unit. | Koi has `AutoLayoutParams`, `autoLayoutPre`, and `autoLayoutPost` for vertical shorthand calls. | Koi should keep vertical layout as the simple path, not replace it with mandatory row calls. | Preserve and document as the default convenience model. | P0 |
| Static rows | `nk_layout_row_static` gives repeated fixed-width columns. | `layoutRow(height, [col(width), ...])` and legacy `beginColumn(colStatic, width)` cover fixed columns. | Needs examples that show repeat and overflow behavior. | Adapt with examples and tests, not C-style API names. | P0 |
| Dynamic rows | `nk_layout_row_dynamic` splits a row into equal growing columns. | `colDynamic()` shares remaining row width. | Equal-column shorthand is less obvious than Nuklear's direct API. | Add examples; consider a Koi-native helper only if repeated call sites justify it. | P1 |
| Ratio rows | `nk_layout_row_begin` plus dynamic ratios, or `nk_layout_row` with ratio arrays. | `colRatio(ratio)` exists. | Ratio semantics should be documented against row width and spacing. | Adapt with examples and layout tests. | P0 |
| Variable columns | `nk_layout_row_template_push_variable` grows while honoring a minimum width. | `colVariable(minWidth)` exists. | Needs documented behavior when available width is below the sum of minimums. | Adopt the concept and specify clamping behavior in Koi terms. | P1 |
| Row templates | `nk_layout_row_template_begin/push/end` creates an auto-repeating mixed column template. | Koi has column arrays and lexical row blocks, but no named template concept. | Repeating mixed rows are possible manually but not packaged as a reusable primitive. | Defer until real code repeats the pattern; prefer Nim templates over a new runtime object. | P2 |
| Layout spaces | `nk_layout_space_begin/push/end` supports local coordinates. | `layoutSpace`, `layoutSpaceBounds`, and coordinate conversion helpers exist. | Nuklear supports both static pixel bounds and dynamic ratio bounds inside spaces; Koi currently emphasizes local pixel coordinates. | Adapt ratio-space bounds only if examples need proportional placement. | P2 |
| Layout-space bounds | `nk_layout_space_bounds` returns the allocated space. | `layoutSpaceBounds()` exists. | Needs examples that show querying bounds for custom drawing. | Adopt as documented public guidance. | P1 |
| Coordinate conversion | Nuklear exposes space-to-screen and screen-to-space helpers for points and rects. | Koi has point and rect conversions. | None beyond coverage. | Keep and test nested cases if layout spaces are expanded. | P1 |
| Current widget bounds | Nuklear exposes `nk_widget_bounds` and related widget-space helpers. | Koi has `autoLayoutNextBounds()` before consumption. | Name and timing are layout-centric, not widget-centric. | Adapt with docs first; consider a clearer helper only as an additive alias. | P1 |
| Ratio-from-pixel helper | `nk_layout_ratio_from_pixel` converts pixels to row ratios. | No equivalent helper is exposed. | Users must calculate ratios by hand. | Adopt as a small Koi-native helper if ratio rows become common. | P2 |
| Spacer | `nk_spacer` consumes layout space without drawing. | No dedicated public spacer was found. | Empty layout cells require an inert widget or manual coordinate work. | Adopt a `spacer` widget that only advances layout. | P1 |
| Minimum row height | Nuklear has min row height setters and reset helpers. | Koi has `nextRowHeight`, `nextItemHeight`, and row height parameters. | No global or scoped minimum row-height policy. | Defer; current explicit row height is simpler and fits Koi. | Later |
| Groups | Nuklear groups provide nested regions with optional title and scrollbars. | Koi has lightweight `beginGroup`, `endGroup`, and `group`; scroll views are separate. | Koi groups are layout grouping, not full scrollable titled panels. | Adapt only the useful nesting behavior; reject Nuklear panel ownership. | P2 |
| Scrollable regions | Nuklear group APIs include internal and manual x/y scroll offsets. | Koi has `beginView`, `beginScrollView`, `endScrollView`, and y-scroll state. | Horizontal scroll and titled/manual-scroll variants are limited. | Defer until generated UI or Gridmonger needs horizontal scroll. | P2 |
| Window and panel layout | Nuklear's main context owns windows, panels, groups, and clipping. | Koi does not use Nuklear-style windows. | Full adoption would create a second UI ownership model. | Reject. Keep Koi draw layers, dialogs, views, and explicit bounds. | P0 |

## Widget Feature Matrix

| Feature | Nuklear Reference | Koi Status | Gap | Recommendation | Priority |
| --- | --- | --- | --- | --- | --- |
| Label | `nk_label`, text alignment variants. | `label` exists with explicit and auto-layout forms. | Alignment and rich label variants may be narrower than Nuklear. | Keep simple; expand only around concrete needs. | P2 |
| Button | `nk_button_*`, text, image, symbol, color variants. | `button` exists with explicit and auto-layout forms. | No dedicated image or symbol button API. | Adapt image/symbol variants after icon/image drawing policy is settled. | P2 |
| Toggle button | Nuklear uses selectable/toggle patterns and button behavior flags. | `toggleButton` exists. | None for current needs. | Keep Koi-native API. | P2 |
| Check box | `nk_checkbox_*`. | `checkBox` exists. | None for current needs. | Keep. | P2 |
| Radio buttons | `nk_option_*` and selectable patterns. | `radioButtons` and `multiRadioButtons` exist. | Koi has a higher-level grouped API rather than one option per call. | Keep Koi API; add lower-level selectable rows separately if needed. | P1 |
| Slider | `nk_slider_*` for numeric ranges. | `horizSlider` and `vertSlider` exist. | Generated parameter UI may want label, value text, and drag precision as one control. | Adapt via property controls rather than changing slider API. | P1 |
| Scrollbar | `nk_scrollbar_*`. | Horizontal and vertical scrollbars exist. | Existing audit already noted shared scrollbar logic could be unified. | Defer to algorithm-audit cleanup; no new widget surface needed. | P2 |
| Text field | `nk_edit_*` supports filters, selection, clipboard, and edit modes. | `textField` and `rawTextField` exist with selection and editing behavior. | Advanced gestures and filters are partial. | Defer richer editing until widget state is stable. | P2 |
| Text area | Nuklear has edit/text-editor internals. | `textArea` exists. | Advanced editor behavior is not full Nuklear coverage. | Defer unless multiline editing becomes a product requirement. | Later |
| Dropdown and combo | `nk_combo_*`, combobox helpers, image/symbol/color combo variants. | `dropDown` exists for generic values and enums. | Keyboard navigation and richer popup variants are limited. | Adapt the simple combo checklist; prioritize keyboard navigation. | P1 |
| Color picker | `nk_color_picker`, color combo helpers. | `color` and `colorPicker` exist. | Koi has basic coverage; combo integration is not clear. | Keep existing picker; consider combo wrapper later. | P2 |
| Tooltip | `nk_tooltip_*` with positioning options. | Tooltip helpers exist through widget common code. | Position policy is simpler. | Keep simple; add placement options only if overlap bugs appear. | P2 |
| Dialog and popup | Nuklear has popups, contextual popups, menus, and combo popups. | Koi has dialogs and dropdown layering. | No general popup/contextual framework. | Adapt a small popup model before menus/contextual widgets. | P1 |
| Tree | `nk_tree_*` and tree element APIs. | `sectionHeader` and `subSectionHeader` provide collapsible sections. | No full tree API with nested node semantics or external state variants. | Adapt on top of section headers; keep it additive. | P1 |
| Progress | `nk_progress`. | No dedicated progress widget was found. | Generated parameter and loading UI need this primitive. | Adopt as a simple explicit/auto-layout widget. | P1 |
| Property and spinner | `nk_property_*` supports labeled numeric edit, step buttons, and dragging. | Koi has sliders and text fields, but no combined property editor. | Plugin/generated parameter UI needs compact numeric controls. | Adopt in Koi style as numeric property widgets for int and float. | P0 |
| Chart and plot | `nk_chart_*`, `nk_plot`, line and column charts. | No chart widget was found. | Useful for meters, automation, or diagnostics, but not layout-critical. | Defer until drawing/data needs are clearer. | Later |
| List view | `nk_list_view_*` supports large scrollable lists. | Scroll views exist, but no virtualized list abstraction was found. | Large plugin or preset lists need efficient row virtualization. | Adapt a minimal virtual list after selectable rows exist. | P1 |
| Selectable row | `nk_selectable_*`. | No dedicated selectable row widget was found; radio/multi-radio cover grouped choices. | Menus, lists, and trees need a reusable row selection primitive. | Adopt as a core building block. | P0 |
| Menu bar and menus | `nk_menubar_*`, `nk_menu_*`. | No menu bar API was found. | Requires popup/focus/menu item behavior first. | Defer until popup model and selectable rows are stable. | P2 |
| Contextual popup | `nk_contextual_*`. | No general right-click contextual popup API was found. | Useful, but depends on popup ownership and input capture. | Defer behind popup model. | P2 |
| Image widget | Nuklear supports image drawing in several widgets. | Koi has `image` drawing helpers. | Widgets do not consistently expose image-bearing variants. | Adapt only for button, selectable, and combo once needed. | P2 |
| Symbol widgets | Nuklear has built-in symbol types for buttons, menus, selectables, and trees. | Koi does not expose a symbol widget family. | A fixed symbol enum may not fit Koi's style model. | Reject a Nuklear-style symbol enum; prefer text/icon drawing hooks. | Later |
| Table | Nuklear has table internals and row/column layout patterns. | Koi rows can approximate simple tables. | No stateful table features such as headers, sorting, resizing, or virtual rows. | Defer; use rows plus selectable/list primitives first. | Later |

## Recommended Sequence

| Phase | Work | Reason |
| --- | --- | --- |
| 1 | Add small layout examples and tests for static, ratio, dynamic, variable, and space layouts. | The current layout model is already close; examples will lock behavior without API churn. |
| 2 | Add `spacer` and consider a ratio-from-pixel helper. | These are small additive primitives that make row layouts easier to use. |
| 3 | Add selectable rows and numeric property widgets. | These directly support generated parameter UIs and list-like tools. |
| 4 | Add progress and a minimal tree wrapper over section headers. | These fill common UI gaps while honoring Koi's existing section model. |
| 5 | Design a small popup model before menus, contextual popups, richer combos, and virtual lists. | Nuklear's richer widgets depend on consistent popup focus, clipping, and layering. |

## Implementation Notes

The first P0/P1 pass should be considered addressed when Koi has:

- layout tests and examples for static, ratio, dynamic, variable, and space
  layouts;
- `spacer` and `ratioFromPixels` as small layout helpers;
- `selectable`, `progress`, `intProperty`, and `floatProperty` widgets;
- `treeNode` and `treeSubNode` wrappers over section headers;
- focused headless tests for the new layout helpers and pure widget math.

## Non-Goals

- Do not copy Nuklear's C names as primary Koi API.
- Do not adopt Nuklear windows, panels, or `nk_context` ownership.
- Do not require all widgets to live inside begin/end layout blocks.
- Do not break explicit bounds or existing auto-layout shorthand calls.
- Do not break Gridmonger-facing usage.
