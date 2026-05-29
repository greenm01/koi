# Koi Toolset

This is a reference for Koi's layout and widget toolset: what is available today
and how the pieces relate. For the design of the unified layout solver and its
execution model, see `layout-model.md`.

Koi is a small immediate-mode UI library for Nim. UI is described by widget calls
every frame; interaction, layout, style, focus, and drawing live in the central
runtime state (`UIState` / `g_uiState`). A few conventions run through the whole
toolset:

- **Two call forms.** Most widgets have an explicit-bounds form
  (`button(x, y, w, h, "OK")`) and an auto-layout shorthand (`button("OK")`) that
  pulls its rectangle from the active layout. The shorthand derives a stable item
  ID from the call site; the explicit form takes an `ItemId`.
- **Styles are values.** Each widget takes a `*Style` object defaulted from the
  active theme and overridable with named arguments. Custom `drawProc`s are
  supported where a widget already exposes one.
- **State is retained by ID.** Per-widget persistent state lives in `itemState`
  keyed by the call-site ID. Drawing is deferred: widgets queue draw commands into
  layers that flush at frame end.

## Layout Tools

Koi uses a single unified container solver. Vertical auto-layout, rows, manual
spaces, scroll regions, popups, and framed containers are presets over that one
model rather than separate positioning systems.

### Sizing model (shipped)

The unified solver sizes each axis of a container independently. Rows and
auto-layout map onto these primitives.

| Sizing | Meaning | Today's equivalent |
| --- | --- | --- |
| `fixed` | A fixed pixel size on that axis. | `col(width)`, explicit `w`/`h` |
| `percent` | A fraction of the parent's content size. | `colRatio(ratio)` |
| `grow` | A share of the parent's remaining space. | `colDynamic()`, `colVariable(min)` |
| `fit` | Shrink-wrap to intrinsic child content. | wrapped text and fit-height containers |

`fixed`, `percent`, and `grow` resolve top-down once the parent size is known.
`fit` and text-wrapped height use bottom-up measurement through the solver's
text measurement callback.

Nodes can also declare `aspectRatio`; when one axis is fixed or already solved
and the other is flexible, the solver derives the flexible axis from the ratio.

### Vertical auto-layout (shipped)

The default convenience path. Widgets flow top to bottom in a grid driven by
`AutoLayoutParams`; each shorthand widget call advances the cursor.

| Tool | What it does |
| --- | --- |
| `initAutoLayout(params)` | Sets the active auto-layout parameters (row width, columns, padding, default heights). |
| `autoLayoutPre()` / `autoLayoutPost()` | The pre/place/post bracket every shorthand widget resolves bounds through. |
| `nextRowHeight(h)` | Overrides the height of the next row. |
| `nextItemWidth(w)` / `nextItemHeight(h)` | Override the next item's width or height. |
| `spacer()` / `spacer(height)` | Consumes a column, or a vertical gap, without drawing. |

### Rows and columns (shipped)

Rows allocate columns deterministically before widget calls consume them. Column
widths are resolved up front from the column specs, then bodies fill each cell —
the same declare-then-fill discipline the unified solver generalizes.

| Tool | What it does |
| --- | --- |
| `layoutRow(height, [cols]): body` | Scoped row block; resolves column widths, runs the body. |
| `beginRowLayout(height, [cols])` / `endLayout()` | Imperative form of the row block. |
| `col(width)` | Fixed-pixel column → maps to `fixed`. |
| `colRatio(ratio)` | Fraction of available row width → maps to `percent`. |
| `colDynamic()` | Equal share of remaining width → maps to `grow`. |
| `colVariable(minWidth)` | Grows but clamps to a minimum → maps to `grow` with a floor. |
| `beginColumn(mode, value)` / `endColumn()` | Overrides the next column's resolution at runtime. |
| `ratioFromPixels(...)` | Converts a pixel width into a ratio for ratio rows. |

### Layout spaces (shipped)

A space creates a local coordinate system for spatial surfaces — node graphs,
racks, timelines, canvases — where widgets are placed by hand and drawing and
hit-testing share the same origin.

| Tool | What it does |
| --- | --- |
| `layoutSpace(height): body` | Scoped space block with a local `(0, 0)` origin. |
| `beginSpaceLayout(height)` / `endLayout()` | Imperative form of the space block. |
| `layoutSpaceBounds()` | The space's allocated rectangle. |
| `layoutSpaceRatioRect(x, y, w, h)` | A sub-rectangle expressed as `0..1` fractions of the space. |
| `layoutSpaceToScreen` / `layoutSpaceToLocal` | Point conversions between space and screen. |
| `layoutSpaceRectToScreen` / `layoutSpaceRectToLocal` | Rectangle conversions between space and screen. |

### Floating and attached layout (shipped)

Floating content can attach one of its nine anchor points to a parent, root, or
target node anchor point. Attached nodes do not consume row/content size.

| Tool | What it does |
| --- | --- |
| `attach(target, targetPoint, selfPoint, ...)` | Builds node-to-node attach placement. |
| `attachParent(...)` / `attachRoot(...)` | Builds parent/root attach placement. |
| `layoutAttachSlot(...)` | Registers an attached leaf slot. |
| `layoutAttachParentSlot(...)` / `layoutAttachRootSlot(...)` | Convenience attached slots for parent/root targets. |
| `beginLayoutAttachContainerSlotAt(...)` / `endLayoutContainerSlot()` | Scoped attached container for popup-like content. |
| `beginLayoutAttachParentContainerSlotAt(...)` / `beginLayoutAttachRootContainerSlotAt(...)` | Convenience attached containers for parent/root targets. |
| `layoutFollowerSlot(...)` | Compatibility wrapper for existing scrollbar, match-target, inset, and dropdown followers. |

Attached layout stores `zIndex`; layout-backed draw calls inherit it and are
sorted within their draw layer while preserving insertion order for equal
z-index values. Attached containers with `capturePointer = true` temporarily
scope hit testing to their previous solved rect while their body is being built.

### Grouping and queries (shipped)

| Tool | What it does |
| --- | --- |
| `group(): body`, `beginGroup()` / `endGroup()` | Lightweight nesting of layout state (not a scrollable panel). |
| `autoLayoutNextBounds()` / `nextWidgetBounds()` | The rectangle the next shorthand widget will occupy. |
| `autoLayoutNextX` / `…NextY` / `…NextItemWidth` / `…NextItemHeight` | Individual components of the next bounds. |
| `nextLayoutColumn()` | The next column to be resolved in the active row. |
| `autoLayoutFinal()` | Finalizes layout advance after a nested region (e.g. a view) ends. |

## Widgets

All widgets follow the conventions above (two call forms, value styles, retained
state by ID). The tables group them by role.

### Text and display

| Widget | Purpose | Notes |
| --- | --- | --- |
| `label` | Static text. | Explicit and auto-layout forms. |
| `progress` | Progress bar. | Simple value-driven primitive. |
| `sectionHeader` / `subSectionHeader` | Collapsible section headers. | Used as the base for tree wrappers. |

### Buttons and toggles

| Widget | Purpose | Notes |
| --- | --- | --- |
| `button` / `buttonImage` / `buttonImageLabel` | Push button, with optional Paint image and image+label variants. | Returns `true` on click. |
| `toggleButton` | Button that holds an on/off state. | Koi-native toggle. |
| `checkBox` | Boolean checkbox. | |
| `radioButtons` / `multiRadioButtons` | Grouped single/multi selection, including enum and grid layouts. | Custom item draw procs supported. |
| `selectable` / `selectableImage` / `selectableImageLabel` | Click-sensitive list/row item. | Core building block for lists and menus. |

### Values and numeric input

| Widget | Purpose | Notes |
| --- | --- | --- |
| `horizSlider` / `vertSlider` | Numeric range sliders. | Edit mode and value display. |
| `intProperty` / `floatProperty` | Labeled numeric value editors. | Compact parameter-style controls. |
| `color` / `colorPicker` / `colorCombo` | Color swatch, full RGB/HSV/hex picker, and a combo-style picker. | |

### Text input

| Widget | Purpose | Notes |
| --- | --- | --- |
| `textField` / `rawTextField` | Single-line text input with selection, editing, and input filters. | `textFieldExitEditMode` ends editing programmatically. |
| `textArea` | Multi-line text input. | Cursor tracking; advanced editor gestures are partial. |

### Lists, trees, and tables

| Widget | Purpose | Notes |
| --- | --- | --- |
| `dropDown` | Combo/dropdown over generic values or enums. | Keyboard navigation, scroll-to-active, optional item paints. |
| `listView` (`beginListView` / `endListView` / `listViewRange`) | Virtualized scrolling list — renders only visible rows. | Compose rows with `selectable`. |
| `tableView` (`beginTableRow`, `drawTableHeader`, `tableCell`) | Header + resolved columns + virtual rows over caller-owned data. | Sorting/resizing are caller-driven. |
| `treeNode` / `treeSubNode` | Expandable tree nodes. | Wrap section headers. |

### Containers and overlays

| Widget | Purpose | Notes |
| --- | --- | --- |
| `scrollView` (`beginScrollView` / `endScrollView`) | Scrollable, clipped content region with scrollbars. | `beginView` / `endView` give a clipped sub-region without scrollbars. |
| `groupBox` / `titledScrollView` | Visual grouping frame, and a titled scrollable panel. | `begin*`/`end*` forms available. |
| `dialog` (`beginDialog` / `endDialog` / `closeDialog`) | Modal dialog on the dialog draw layer. | |
| `popup` (`beginPopup` / `endPopup`, `openPopup` / `closePopup` / `isPopupOpen`) | General popup: focus capture, Escape/outside-click close, clipping, popup layer. | Foundation for dropdowns and menus. |
| `menuBar` / `menu` / `menuItem` / `menuItemImage` / `menuItemImageLabel` / `menuLabel` / `menuSeparator` | Menu bar and menus with keyboard traversal. | Built on popups and selectables. |
| `contextMenu` (`beginContextMenu` / `endContextMenu`) | Right-click context menu anchored at the click. | |
| Tooltips | Hover tooltips. | Driven by the `tooltip` argument on widgets (`handleTooltip` / `drawTooltip` internally). |

### Data visualization

| Widget | Purpose | Notes |
| --- | --- | --- |
| `plotLine` / `plotColumns` / `plotChart` | Minimal line and column charts. | Data owned by the caller; no multi-series or interactive state. |

### Low-level scrollbars

| Widget | Purpose | Notes |
| --- | --- | --- |
| `horizScrollBar` / `vertScrollBar` | Standalone scrollbars. | Usually composed inside `scrollView`; rarely called directly. |

## Where this is going

The unified layout refactor is in place: one frame-local arena is sized with
`fixed`/`grow`/`percent`/`fit`, solved at frame end with current visuals, while
pointer interaction reads previous-frame rects. Future work should build on that
foundation: richer widget coverage, more complete theming, and higher-level
fit-content container APIs where applications need them.
