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

| Area | Nuklear Reference | Koi Status | Remaining Gap | Recommendation | Priority |
| --- | --- | --- | --- | --- | --- |
| Explicit widget bounds | Widgets consume bounds resolved from the active layout row or layout space. | Core Koi model. Explicit `x, y, w, h` calls remain the base path. | None. | Keep this as the source of truth. | P0 |
| Vertical auto-layout | Nuklear rows are the normal layout unit. | Koi has `AutoLayoutParams`, `autoLayoutPre`, and `autoLayoutPost` for vertical shorthand calls. | None. | Preserve this as the default convenience model. | P0 |
| Static rows | `nk_layout_row_static` gives repeated fixed-width columns. | `layoutRow(height, [col(width), ...])` and legacy `beginColumn(cmStatic, width)` cover fixed columns. | None for current needs. | Keep Koi-native row APIs and examples. | P0 |
| Dynamic rows | `nk_layout_row_dynamic` splits a row into equal growing columns. | `colDynamic()` shares remaining row width, with predeclared and lexical row examples. | No dedicated equal-column shorthand. | Defer a helper until repeated call sites justify it. | P2 |
| Ratio rows | `nk_layout_row_begin` plus dynamic ratios, or `nk_layout_row` with ratio arrays. | `colRatio(ratio)` and `ratioFromPixels` exist with tests. | None for current needs. | Keep the Koi-native helper names. | P0 |
| Variable columns | `nk_layout_row_template_push_variable` grows while honoring a minimum width. | `colVariable(minWidth)` exists and clamps to the minimum when space is tight. | None for current needs. | Keep current behavior covered by tests. | P1 |
| Row templates | `nk_layout_row_template_begin/push/end` creates an auto-repeating mixed column template. | Koi has reusable column arrays and lexical row blocks, but no named template concept. | None for current needs. | Prefer reusable `openArray[LayoutColumn]` definitions over a runtime object. | P2 |
| Layout spaces | `nk_layout_space_begin/push/end` supports local coordinates. | `layoutSpace`, `layoutSpaceBounds`, ratio rectangles, and coordinate conversion helpers exist. | None for current needs. | Keep local pixel coordinates as the default and use ratio rects selectively. | P2 |
| Layout-space bounds | `nk_layout_space_bounds` returns the allocated space. | `layoutSpaceBounds()` exists and is used in the layout demo. | None. | Keep as documented public guidance through examples. | P1 |
| Coordinate conversion | Nuklear exposes space-to-screen and screen-to-space helpers for points and rects. | Koi has point and rect conversions with offset coverage. | None for current needs. | Keep testing draw-offset conversion. | P1 |
| Current widget bounds | Nuklear exposes `nk_widget_bounds` and related widget-space helpers. | Koi has `autoLayoutNextBounds()` and the additive `nextWidgetBounds()` alias before consumption. | None for current needs. | Keep both names source-compatible. | P2 |
| Spacer | `nk_spacer` consumes layout space without drawing. | `spacer()` and `spacer(height)` exist with tests and demo coverage. | None. | Keep as an inert layout primitive. | P1 |
| Minimum row height | Nuklear has min row height setters and reset helpers. | Koi has `nextRowHeight`, `nextItemHeight`, and row height parameters. | No global or scoped minimum row-height policy. | Defer; explicit row height fits Koi. | Later |
| Groups | Nuklear groups provide nested regions with optional title and scrollbars. | Koi has lightweight `beginGroup`, `endGroup`, and `group`; scroll views are separate. | Koi groups are layout grouping, not full scrollable titled panels. | Adapt only nesting behavior; reject Nuklear panel ownership. | P2 |
| Scrollable regions | Nuklear group APIs include internal and manual x/y scroll offsets. | Koi has `beginView`, `beginScrollView`, `endScrollView`, and x/y scroll state. | Titled/manual-scroll variants are limited. | Defer wrappers until generated UI or Gridmonger needs them. | P2 |
| Window and panel layout | Nuklear's main context owns windows, panels, groups, and clipping. | Koi does not use Nuklear-style windows. | Full adoption would create a second UI ownership model. | Reject. Keep Koi draw layers, dialogs, views, and explicit bounds. | P0 |

## Widget Feature Matrix

| Feature | Nuklear Reference | Koi Status | Remaining Gap | Recommendation | Priority |
| --- | --- | --- | --- | --- | --- |
| Label | `nk_label`, text alignment variants. | `label` exists with explicit and auto-layout forms. | Alignment and rich label variants may be narrower than Nuklear. | Keep simple; expand only around concrete needs. | P2 |
| Button | `nk_button_*`, text, image, symbol, color variants. | `button`, `buttonImage`, and `buttonImageLabel` exist with explicit and auto-layout forms. | None for current bitmap image needs. | Keep Paint-based variants; reject a fixed symbol enum. | P2 |
| Toggle button | Nuklear uses selectable/toggle patterns and button behavior flags. | `toggleButton` exists. | None for current needs. | Keep Koi-native API. | P2 |
| Check box | `nk_checkbox_*`. | `checkBox` exists. | None for current needs. | Keep. | P2 |
| Radio buttons | `nk_option_*` and selectable patterns. | `radioButtons`, `multiRadioButtons`, and `selectable` exist. | Koi favors grouped radio APIs. | Keep Koi API; use selectable rows for list-like choices. | P1 |
| Slider | `nk_slider_*` for numeric ranges. | `horizSlider`, `vertSlider`, `intProperty`, and `floatProperty` exist. | Drag precision and generated parameter polish may still need work. | Improve property controls rather than changing slider APIs. | P1 |
| Scrollbar | `nk_scrollbar_*`. | Horizontal and vertical scrollbars exist. | Shared scrollbar cleanup belongs to algorithm work. | No new widget surface needed here. | P2 |
| Text field | `nk_edit_*` supports filters, selection, clipboard, and edit modes. | `textField` and `rawTextField` exist with selection, editing behavior, and basic input filters. | Advanced gestures remain partial. | Keep filters additive; defer editor-scale behavior. | P2 |
| Text area | Nuklear has edit/text-editor internals. | `textArea` exists. | Advanced editor behavior is not full Nuklear coverage. | Defer unless multiline editing becomes a product requirement. | Later |
| Dropdown and combo | `nk_combo_*`, combobox helpers, image/symbol/color combo variants. | `dropDown` exists for generic values and enums, with keyboard navigation tests and optional item paints. | Color-specific combo wrappers are not implemented. | Keep simple combo behavior; add wrappers only if needed. | P1 |
| Color picker | `nk_color_picker`, color combo helpers. | `color` and `colorPicker` exist. | Combo integration is not clear. | Keep existing picker; consider combo wrapper later. | P2 |
| Tooltip | `nk_tooltip_*` with positioning options. | Tooltip helpers exist through widget common code. | Position policy is simpler. | Add placement options only if overlap bugs appear. | P2 |
| Dialog and popup | Nuklear has popups, contextual popups, menus, and combo popups. | Koi has dialogs plus a general popup helper with focus, close, clipping, layer, and draw-offset handling. | Popup placement helpers are still basic. | Keep the small popup model; extend placement only as needed. | P1 |
| Tree | `nk_tree_*` and tree element APIs. | `treeNode` and `treeSubNode` wrap section headers. | No full tree API with external state variants. | Keep additive wrappers; defer richer tree semantics. | P1 |
| Progress | `nk_progress`. | `progress` exists with explicit and auto-layout forms. | None for current needs. | Keep the simple primitive. | P1 |
| Property and spinner | `nk_property_*` supports labeled numeric edit, step buttons, and dragging. | `intProperty` and `floatProperty` exist. | Drag editing is not implemented. | Keep compact numeric controls; add drag only if users need it. | P0 |
| Chart and plot | `nk_chart_*`, `nk_plot`, line and column charts. | `plotLine` and `plotColumns` exist as minimal drawing widgets. | No multi-series or interactive chart state. | Keep charts data-owned by the caller. | Later |
| List view | `nk_list_view_*` supports large scrollable lists. | `listViewRange`, `beginListView`, and `listView` exist for virtualized rows. | Horizontal and richer row features are not implemented. | Keep the minimal virtual list and compose rows with selectable. | P1 |
| Selectable row | `nk_selectable_*`. | `selectable` exists with explicit and auto-layout forms. | None for current needs. | Keep as a core building block. | P0 |
| Menu bar and menus | `nk_menubar_*`, `nk_menu_*`. | `menuBar`, `menu`, `menuItem`, and image menu items exist on top of popup and selectable. | Traversal is intentionally small. | Keep current API; extend traversal only around real workflows. | P2 |
| Contextual popup | `nk_contextual_*`. | `contextMenu` and `beginContextMenu` exist with right-click anchoring. | Keyboard/context placement refinements are not implemented. | Keep the small contextual API. | P2 |
| Image widget | Nuklear supports image drawing in several widgets. | Koi has `image` drawing helpers plus Paint-based button, selectable, menu item, and dropdown variants. | None for current bitmap image needs. | Keep Paint variants instead of symbol enums. | P2 |
| Symbol widgets | Nuklear has built-in symbol types for buttons, menus, selectables, and trees. | Koi does not expose a symbol widget family. | A fixed symbol enum may not fit Koi's style model. | Reject a Nuklear-style symbol enum; prefer text/icon drawing hooks. | Later |
| Table | Nuklear has table internals and row/column layout patterns. | `tableView` provides headers, resolved columns, and virtual rows with caller-owned data. | No built-in sorting, resizing, or data ownership. | Keep tables as composition helpers. | Later |

## Completed Passes

| Pass | Covered Work |
| --- | --- |
| Layout foundations | Static, dynamic, ratio, variable, and space layout examples and tests. |
| Small layout helpers | `spacer()` and `spacer(height)`, plus `ratioFromPixels`. |
| Core list widgets | `selectable`, `progress`, `intProperty`, and `floatProperty`. |
| Tree wrappers | `treeNode` and `treeSubNode` over section headers. |
| Popup/list foundations | General popup state, Escape close, outside-click close, clipping, popup draw layer, virtual list ranges, and list-view templates. |
| Combo navigation | Drop-down keyboard navigation for Up, Down, Enter, Escape, and scroll-to-active behavior. |
| Menu/context primitives | Menu bars, menus, menu items, and right-click context menus anchored at the original click. |
| Backlog primitives | Paint-based image variants, ratio-space rectangles, horizontal scroll views, text filters, menu traversal, minimal charts, and table views. |

## Remaining Backlog

| Area | Next Decision |
| --- | --- |
| Row templates | Keep using reusable `openArray[LayoutColumn]` definitions until real code needs a named template API. |
| Groups and scroll regions | Keep lightweight groups; add titled/manual-scroll wrappers only for a concrete generated UI or Gridmonger need. |
| Text editing | Add richer gestures or clipboard refinements only after widget state stabilizes. |
| Charts and tables | Add multi-series charts, sorting, resizing, or richer table interaction only when application needs are concrete. |
| Menu traversal | Extend traversal beyond the current Left/Right/Up/Down/Enter/Escape support only around real menu-heavy workflows. |

## Non-Goals

- Do not copy Nuklear's C names as primary Koi API.
- Do not adopt Nuklear windows, panels, or `nk_context` ownership.
- Do not require all widgets to live inside begin/end layout blocks.
- Do not break explicit bounds or existing auto-layout shorthand calls.
- Do not break Gridmonger-facing usage.
