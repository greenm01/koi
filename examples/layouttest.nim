import std/lenientops
import std/options

import glad/gl
import glfw
from glfw/wrapper import showWindow
import nanovg

import koi

# Global NanoVG context
var vg: NVGContext

var
  selectedRow = false
  popupId = hashId("layout-popup")
  progressValue = 0.45
  intValue = 4
  floatValue = 0.5
  dropIndex = 0
  filteredText = ""
  comboColor = rgb(0.16, 0.45, 0.82)
  pickerColor = rgb(0.88, 0.18, 0.16)
  treeOpen = true
  treeChildOpen = true
  listSelected: array[30, bool]
  chartValues = @[0.15, 0.45, 0.25, 0.8, 0.55, 0.95, 0.35]
  chartValuesAlt = @[0.30, 0.25, 0.55, 0.35, 0.75, 0.50, 0.85]
  tableSort = TableSortState(column: -1, direction: tsdNone)
  tableWidths: seq[float]
  tableColumns =
    @[
      TableColumn(label: "Name", width: 120),
      TableColumn(label: "Kind", width: 80),
      TableColumn(label: "Value", width: 0),
    ]

proc createWindow(): Window =
  var cfg = DefaultOpenglWindowConfig
  cfg.size = (w: 800, h: 600)
  cfg.title = "Koi Layout Test"
  cfg.resizable = true
  cfg.visible = true
  cfg.nMultiSamples = 4
  newWindow(cfg)

proc loadData(vg: NVGContext) =
  # Assuming Roboto-Regular.ttf exists in data/ as in test.nim
  discard vg.createFont("sans", "data/Roboto-Regular.ttf")

proc renderUI() =
  koi.beginFrame()
  let iconPaint = vg.imagePattern(
    0.cfloat, 0.cfloat, g_checkeredImageSize.cfloat, g_checkeredImageSize.cfloat,
    0.cfloat, g_checkeredImage, 1.cfloat,
  )

  menuBar(0, 0, koi.winWidth(), 24):
    menu("File", 160, 110):
      menuLabel("Project")
      if menuItem("New"):
        echo "New selected"
      if menuItemImageLabel(iconPaint, "Open"):
        echo "Open selected"
      menuSeparator()
      discard menuItem("Recent", disabled = true)
    menu("Edit", 160, 70):
      if menuItem("Copy"):
        echo "Copy selected"
      if menuItem("Paste"):
        echo "Paste selected"

  spacer(24)

  # Standard auto-layout
  label("Standard Auto-layout:")
  if button("Standard Button"):
    echo "Standard Button clicked"

  label("Hierarchical Layout (Row 30px, Static 150 + Dynamic):")
  layoutRow(30.0):
    col(150.0):
      if button("Static 150"):
        echo "Static Button clicked"
    colDynamic:
      if button("Dynamic"):
        echo "Dynamic Button clicked"

  label("Hierarchical Layout (Row 30px, 3x Ratio 0.33):")
  layoutRow(30.0):
    colRatio(0.33):
      if button("Ratio 1"):
        echo "Ratio 1 clicked"
    colRatio(0.33):
      if button("Ratio 2"):
        echo "Ratio 2 clicked"
    colRatio(0.33):
      if button("Ratio 3"):
        echo "Ratio 3 clicked"

  label("Predeclared Row (Fixed 100 + 2x Dynamic):")
  layoutRow(30.0, [col(100.0), colDynamic(), colDynamic()]):
    if button("Fixed"):
      echo "Fixed clicked"
    if button("Dynamic 1"):
      echo "Dynamic 1 clicked"
    if button("Dynamic 2"):
      echo "Dynamic 2 clicked"

  label("Variable Row (Fixed 80 + Variable min 80 + Dynamic):")
  layoutRow(30.0, [col(80.0), colVariable(80.0), colDynamic()]):
    discard button("Fixed")
    discard button("Variable")
    discard button("Dynamic")

  label("Spacer in Row:")
  layoutRow(30.0, [colDynamic(), colDynamic(), colDynamic()]):
    discard button("Left")
    spacer()
    discard button("Right")

  label("Layout Space (200px height):")
  layoutSpace(200.0):
    # Absolute positioning relative to the space
    label(20, 20, 100, 20, "At 20,20")
    if button(150, 50, 100, 30, "At 150,50"):
      echo "Space Button clicked"
    let b = layoutSpaceBounds()
    label(20, b.h - 30, 180, 20, "Space bounds: " & $b.w & " x " & $b.h)

  label("Selectable, Progress, Properties:")
  discard selectable("Selectable row", selectedRow)
  discard selectableImageLabel(iconPaint, "Image selectable", selectedRow)
  discard buttonImageLabel(iconPaint, "Image button")
  dropDown(@["Paint A", "Paint B"], dropIndex, itemPaints = @[iconPaint, iconPaint])
  progress(progressValue, 1.0, "Progress")
  discard intProperty("Int value", 0, 10, 1, intValue)
  discard floatProperty("Float value", 0.0, 1.0, 0.1, floatValue)
  textField(filteredText, filter = tffFloat)
  discard colorCombo(comboColor, "Accent")
  colorPicker(pickerColor)

  treeNode("Tree Node", treeOpen):
    label("Tree child")
    treeSubNode("Tree Subnode", treeChildOpen):
      label("Nested content")

  label("Popup and Virtual List:")
  if button("Open Popup"):
    openPopup(popupId)

  popup(popupId, 120, 120, 220, 80):
    label(10, 8, 200, 22, "Popup content")
    if button(10, 38, 90, 24, "Close"):
      closePopup()

  layoutSpace(130.0):
    listView(0, 0, 300, 120, listSelected.len.Natural, 22.0, i):
      discard selectable(0, i.float * 22.0, 280, 20, "List item " & $i, listSelected[i])

  label("Groups, Horizontal Scroll, Chart, Table:")
  layoutSpace(110.0):
    groupBox(0, 0, 260, 100, "Group Box"):
      label(0, 0, 220, 22, "Grouped content")
      discard button(0, 30, 120, 24, "Action")
    titledScrollView(280, 0, 280, 100, "Titled Scroll", 480, 76):
      label(0, 0, 140, 22, "Scroll content")
      label(340, 46, 120, 22, "Far edge")

  layoutSpace(80.0):
    scrollView(0, 0, 260, 60, 520, 50):
      label(0, 0, 120, 22, "Scroll left")
      label(400, 0, 120, 22, "Scroll right")

  layoutSpace(90.0):
    let series = [
      ChartSeries(label: "A", values: chartValues, kind: ckLine, color: HighlightColor),
      ChartSeries(
        label: "B", values: chartValuesAlt, kind: ckLine, color: rgb(0.18, 0.62, 0.24)
      ),
    ]
    plotChart(0, 0, 300, 80, series, 0.0, 1.0, "Lines")
    plotColumns(320, 0, 240, 80, chartValues, 0.0, 1.0, "Columns")

  layoutSpace(120.0):
    tableView(0, 0, 360, 110, tableColumns, tableWidths, tableSort, 4.Natural, i):
      tableCell("Row " & $i)
      tableCell(if i mod 2 == 0: "Even" else: "Odd")
      tableCell($(i * 10))

  label("Context Menu Area:")
  layoutSpace(60.0):
    label(20, 18, 220, 22, "Right-click this row")
    contextMenu(20, 10, 240, 38, 160, 70):
      if menuItem("Context Action"):
        echo "Context action selected"
      if menuItem("Disabled Item", disabled = true):
        echo "disabled"

  koi.endFrame()

proc renderFrame(win: Window) =
  if win.iconified:
    return

  let size = win.size
  glViewport(0, 0, size.w.int32, size.h.int32)
  glClearColor(0.2, 0.2, 0.2, 1.0)
  glClear(GL_COLOR_BUFFER_BIT or GL_STENCIL_BUFFER_BIT)

  vg.beginFrame(size.w.float, size.h.float, 1.0)
  renderUI()
  vg.endFrame()

  win.swapBuffers()

proc main() =
  glfw.initialize()
  let win = createWindow()
  win.makeContextCurrent()

  if not gladLoadGL(glfw.getProcAddress):
    quit "Failed to load GL"

  vg = nvgCreateContext({nifStencilStrokes, nifAntialias})
  loadData(vg)

  koi.init(vg, glfw.getProcAddress)
  initAutoLayout(DefaultAutoLayoutParams)

  while not win.shouldClose:
    if koi.shouldRenderNextFrame():
      glfw.pollEvents()
    else:
      glfw.waitEvents()
    renderFrame(win)

  koi.deinit()
  nvgDeleteContext(vg)
  glfw.terminate()

main()
