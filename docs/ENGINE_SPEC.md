# Koi UI Engine Specification

## 1. Overview
Koi is a minimalist, immediate-mode GUI library for Nim. It operates on a "Stateful Procedural" model where the UI is defined through function calls every frame, and internal state (interaction, layout, styling) is managed through a central global state object (`g_uiState`).

---

## 2. Layout Engine
Koi employs a hybrid layout engine that supports three distinct positioning paradigms:

### A. Explicit Positioning
The most fundamental layer. Every widget proc accepts `x, y, w, h` parameters. If provided, the widget is drawn at those exact virtual pixel coordinates.
*   **Coordinate System:** Origin (0,0) at top-left.
*   **Draw Offsets:** Coordinates are transformed by the current `DrawOffset` stack (used for nested views or layout spaces).

### B. Standard Auto-Layout (Vertical)
The default mode when explicit bounds are omitted.
*   **Mechanism:** Uses `AutoLayoutStateVars` to track the current `y` cursor and `rowHeight`.
*   **Flow:** Top-to-bottom, filling the `rowWidth` defined in `AutoLayoutParams`.
*   **Padding:** Respects `leftPad`, `rightPad`, `rowPad`, and `sectionPad`.

### C. Hierarchical Blocks (New)
A Nuklear-inspired, stack-based layout system utilizing Nim's lexical scoping.
*   **Rows (`layoutRow`):** Segments a row into columns.
    *   `col(width)`: Fixed pixel width.
    *   `colDynamic()`: Occupies remaining available width in the row.
    *   `colRatio(0..1)`: Occupies a percentage of total available width.
*   **Spaces (`layoutSpace`):** Creates a local coordinate system. Widgets called with explicit `x,y` inside this block are relative to the space's origin.
*   **State Management:** Managed via a `layoutStack`. Each widget call invokes `autoLayoutPre()` which inspects the stack to resolve its bounds.

---

## 3. Widget Engine
The widget engine handles interaction logic, state transitions, and rendering commands.

### A. Execution Cycle
A typical widget execution follows this internal pattern:
1.  **Resolve Bounds:** `autoLayoutPre()` determines the `x, y, w, h`.
2.  **Hit Testing:** Checks if `mx, my` (mouse) is within bounds and not occluded by a `hitClipRect`.
3.  **State Update:**
    *   **Hot:** Mouse is over the widget.
    *   **Active:** Left Mouse Button (LMB) is pressed down while Hot.
    *   **Action:** Triggered if LMB is released while the widget is Active.
4.  **Drawing:** Pushes drawing primitives (rects, text, gradients) to the `currentLayer` via NanoVG.
5.  **Finalize:** `autoLayoutPost()` advances the layout cursor.

### B. State Management
*   **Global State:** Uses `ItemId` (usually generated via `instantiationInfo`) to track specific instances across frames.
*   **Focus:** `focusCaptured` prevents other widgets from becoming Hot (e.g., when a text field is being edited).
*   **Persistence:** Per-instance data (like scroll positions) is stored in a `Table[ItemId, ref RootObj]`.

### C. Styling
*   **Static Styles:** Default styles are defined as global constants or objects.
*   **In-line Overrides:** Procs use Nim's default/named arguments, allowing per-call styling (e.g., `button("OK", style = MyCustomStyle)`).

---

## 4. Interaction Model
Koi follows standard IMGUI interaction rules:
*   **Hot Item:** The item under the cursor. Only one per frame.
*   **Active Item:** The item being interacted with (e.g., button being held).
*   **Layering:** Widgets are drawn on specific `DrawLayer` enums to handle overlays like tooltips and popups without requiring complex z-index management.
