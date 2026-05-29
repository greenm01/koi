import std/options

import glad/gl
import glfw
from glfw/wrapper import showWindow
import nanovg

import koi

type
  LineWidth = enum
    lwThin = (0, "Thin")
    lwNormal = (1, "Normal")

  GridStyle = enum
    gsNone = (0, "None")
    gsSolid = (1, "Solid")
    gsLoose = (2, "Loose")
    gsCross = (3, "Cross")

  OutlineStyle = enum
    osNone = (0, "None")
    osCell = (1, "Cell")
    osSquareEdges = (2, "Square Edges")
    osRoundedEdges = (3, "Rounded Edges")
    osRoundedEdgesFilled = (4, "Filled Rounded Edges")

  OutlineFillStyle = enum
    ofsSolid = (0, "Solid")
    ofsHatched = (1, "Hatched")

  Theme = object
    general: GeneralStyle
    widget: WidgetStyle
    textField: TextFieldStyle
    dialog: DialogStyle
    window: WindowStyle
    statusBar: StatusBarStyle
    levelDropDown: LevelDropDownStyle
    aboutButton: AboutButtonStyle
    level: LevelStyle
    notesPane: NotesPaneStyle
    toolbarPane: ToolbarPaneStyle

  GeneralStyle = object
    backgroundColor: Color
    highlightColor: Color

  WidgetStyle = object
    bgColor: Color
    bgColorHover: Color
    bgColorDisabled: Color
    textColor: Color
    textColorDisabled: Color

  TextFieldStyle = object
    bgColorActive: Color
    textColorActive: Color
    cursorColor: Color
    selectionColor: Color

  DialogStyle = object
    titleBarBgColor: Color
    titleBarTextColor: Color
    backgroundColor: Color
    textColor: Color
    warningTextColor: Color

  WindowStyle = object
    backgroundColor: Color
    bgColorUnfocused: Color
    textColor: Color
    textColorUnfocused: Color
    modifiedFlagColor: Color
    buttonColor: Color
    buttonColorHover: Color
    buttonColorDown: Color

  StatusBarStyle = object
    backgroundColor: Color
    textColor: Color
    commandBgColor: Color
    commandColor: Color
    coordsColor: Color

  LevelDropDownStyle = object
    buttonColor: Color
    buttonColorHover: Color
    textColor: Color
    itemListColor: Color
    itemColor: Color
    itemColorHover: Color

  AboutButtonStyle = object
    color: Color
    colorHover: Color
    colorActive: Color

  LevelStyle = object
    backgroundColor: Color
    drawColor: Color
    lightDrawColor: Color
    lineWidth: LineWidth
    coordsColor: Color
    coordsHighlightColor: Color
    cursorColor: Color
    cursorGuideColor: Color
    gridStyleBackground: GridStyle
    gridColorBackground: Color
    gridStyleFloor: GridStyle
    gridColorFloor: Color
    selectionColor: Color
    pastePreviewColor: Color
    linkMarkerColor: Color
    bgHatch: bool
    bgHatchColor: Color
    bgHatchStrokeWidth: float
    bgHatchSpacingFactor: float
    outlineStyle: OutlineStyle
    outlineFillStyle: OutlineFillStyle
    outlineOverscan: bool
    outlineColor: Color
    outlineWidthFactor: float
    innerShadowColor: Color
    innerShadowWidthFactor: float
    outerShadowColor: Color
    outerShadowWidthFactor: float
    floorColor: array[9, Color]
    noteMarkerColor: Color
    noteCommentColor: Color
    noteIndexColor: Color
    noteIndexBgColor: array[4, Color]
    noteTooltipBgColor: Color
    noteTooltipTextColor: Color

  NotesPaneStyle = object
    textColor: Color
    indexColor: Color
    indexBgColor: array[4, Color]

  ToolbarPaneStyle = object
    buttonBgColor: Color
    buttonBgColorHover: Color

# Global NanoVG context
var vg: NVGContext

### UI DATA ##################################################################
var
  sectionUserInterface = true
  sectionUserInterfaceGeneral = false
  sectionWidget = false
  sectionTextField = false
  sectionDialog = false
  sectionTitleBar = false
  sectionStatusBar = false
  sectionLeveldropDown = true
  sectionAboutButton = false

  sectionLevel = true
  sectionLevelGeneral = true
  sectionOutline = true
  sectionShadow = true
  sectionBackgroundHatch = true
  sectionFloorColors = true
  sectionNotes = true

  sectionPanes = true
  sectionNotesPane = true
  sectionToolbarPane = true

var currTheme: Theme

var
  themeName = "Default"
  themeAuthor = "chaos"

  section1 = true
  section2 = true

  dropDownVal1 = 0
  dropDownVal2 = 0
  dropDownVal3 = 0

  checkBoxVal1 = false
  checkBoxVal2 = false
  checkBoxVal3 = false
  checkBoxVal4 = false
  checkBoxVal5 = false
  checkBoxVal6 = false

##############################################################################

proc createWindow(): Window =
  var cfg = DefaultOpenglWindowConfig
  cfg.size = (w: 1000, h: 800)
  cfg.title = "Koi Test"
  cfg.resizable = true
  cfg.visible = false
  cfg.bits = (
    r: 8'i32.some,
    g: 8'i32.some,
    b: 8'i32.some,
    a: 8'i32.some,
    stencil: 8'i32.some,
    depth: 16'i32.some,
  )
  cfg.debugContext = true
  cfg.nMultiSamples = 4

  when defined(macosx):
    cfg.version = glv32
    cfg.forwardCompat = true
    cfg.profile = opCoreProfile

  newWindow(cfg)

proc loadData(vg: NVGContext) =
  let regularFont = vg.createFont("sans", "data/Roboto-Regular.ttf")
  if regularFont == NoFont:
    quit "Could not add font italic.\n"

  let boldFont = vg.createFont("sans-bold", "data/Roboto-Bold.ttf")
  if boldFont == NoFont:
    quit "Could not add font italic.\n"

var propsSliderStyle = defaultSliderStyle()
propsSliderStyle.trackCornerRadius = 8.0
propsSliderStyle.valueCornerRadius = 6.0

proc renderUI() =
  koi.beginFrame()

  vg.beginPath()
  vg.rect(0, 0, koi.winWidth(), koi.winHeight())
  vg.fillColor(gray(0.3))
  vg.fill()

  ############################################################################

  var w = 314.0
  koi.beginScrollView(x = 100, y = 100, w = w, h = 600)

  var ap = DefaultAutoLayoutParams
  ap.rowWidth = w
  ap.rightPad = 16

  initAutoLayout(ap)

  if koi.sectionHeader("User Interface", sectionUserInterface):
    if koi.subSectionHeader("General", sectionUserInterfaceGeneral):
      koi.label("Background")
      discard koi.colorCombo(currTheme.general.backgroundColor)

      koi.label("Highlight")
      discard koi.colorCombo(currTheme.general.highlightColor)

    if koi.subSectionHeader("Widget", sectionWidget):
      koi.label("Background")
      discard koi.colorCombo(currTheme.widget.bgColor)

      koi.label("Background Hover")
      discard koi.colorCombo(currTheme.widget.bgColorHover)

      koi.label("Background Disabled")
      discard koi.colorCombo(currTheme.widget.bgColorDisabled)

      koi.label("Text")
      discard koi.colorCombo(currTheme.widget.textColor)

      koi.label("Text Disabled")
      discard koi.colorCombo(currTheme.widget.textColorDisabled)

    if koi.subSectionHeader("Text Field", sectionTextField):
      koi.label("Background Active")
      discard koi.colorCombo(currTheme.textField.bgColorActive)

      koi.label("Text Active")
      discard koi.colorCombo(currTheme.textField.textColorActive)

      koi.label("Cursor")
      discard koi.colorCombo(currTheme.textField.cursorColor)

      koi.label("Selection")
      discard koi.colorCombo(currTheme.textField.selectionColor)

    if koi.subSectionHeader("Dialog", sectionDialog):
      koi.label("Title Bar Background")
      koi.nextItemHeight(81)
      discard koi.colorCombo(currTheme.dialog.titleBarBgColor)

      koi.label("Title Bar Text")
      discard koi.colorCombo(currTheme.dialog.titleBarTextColor)

      koi.label("Background")
      koi.nextItemHeight(61)
      discard koi.colorCombo(currTheme.dialog.backgroundColor)

      koi.label("Text")
      discard koi.colorCombo(currTheme.dialog.textColor)

      koi.label("Warning Text")
      discard koi.colorCombo(currTheme.dialog.warningTextColor)

    if koi.subSectionHeader("Title Bar", sectionTitleBar):
      koi.label("Background")
      discard koi.colorCombo(currTheme.window.backgroundColor)

      koi.label("Background Unfocused")
      discard koi.colorCombo(currTheme.window.bgColorUnfocused)

      koi.label("Text")
      discard koi.colorCombo(currTheme.window.textColor)

      koi.label("Text Unfocused")
      discard koi.colorCombo(currTheme.window.textColorUnfocused)

      koi.label("Modified Flag")
      discard koi.colorCombo(currTheme.window.modifiedFlagColor)

      koi.label("Button")
      discard koi.colorCombo(currTheme.window.buttonColor)

      koi.label("Button Hover")
      discard koi.colorCombo(currTheme.window.buttonColorHover)

      koi.label("Button Down")
      discard koi.colorCombo(currTheme.window.buttonColorDown)

    if koi.subSectionHeader("Status Bar", sectionStatusBar):
      koi.label("Background")
      discard koi.colorCombo(currTheme.statusBar.backgroundColor)

      koi.label("Text")
      discard koi.colorCombo(currTheme.statusBar.textColor)

      koi.label("Command Background")
      discard koi.colorCombo(currTheme.statusBar.commandBgColor)

      koi.label("Command")
      discard koi.colorCombo(currTheme.statusBar.commandColor)

      koi.label("Coordinates")
      discard koi.colorCombo(currTheme.statusBar.coordsColor)

    if koi.subSectionHeader("Level Drop Down", sectionLeveldropDown):
      koi.nextRowHeight(21)
      koi.label("Button")
      discard koi.colorCombo(currTheme.levelDropDown.buttonColor)

      koi.label("Button Hover")
      discard koi.colorCombo(currTheme.levelDropDown.buttonColorHover)

      koi.nextRowHeight(21)
      koi.label("Text")
      discard koi.colorCombo(currTheme.levelDropDown.textColor)

      koi.label("Item List")
      discard koi.colorCombo(currTheme.levelDropDown.itemListColor)

      koi.nextRowHeight(21)
      koi.label("Item")
      discard koi.colorCombo(currTheme.levelDropDown.itemColor)

      koi.label("Item Hover")
      discard koi.colorCombo(currTheme.levelDropDown.itemColorHover)

    if koi.subSectionHeader("About Button", sectionAboutButton):
      koi.label("Color")
      discard koi.colorCombo(currTheme.aboutButton.color)

      koi.label("Hover")
      discard koi.colorCombo(currTheme.aboutButton.colorHover)

      koi.label("Active")
      discard koi.colorCombo(currTheme.aboutButton.colorActive)

  if koi.sectionHeader("Level", sectionLevel):
    if koi.subSectionHeader("General", sectionLevelGeneral):
      group:
        koi.label("Background")
        discard koi.colorCombo(currTheme.level.backgroundColor)

        koi.label("Draw")
        discard koi.colorCombo(currTheme.level.drawColor)

        koi.label("Draw Light")
        discard koi.colorCombo(currTheme.level.lightDrawColor)

        koi.label("Line Width")
        koi.dropDown(currTheme.level.lineWidth)

      group:
        koi.label("Coordinates")
        discard koi.colorCombo(currTheme.level.coordsColor)

        koi.label("Coordinates Highlight")
        discard koi.colorCombo(currTheme.level.coordsHighlightColor)

        koi.label("Cursor")
        discard koi.colorCombo(currTheme.level.cursorColor)

        koi.label("Cursor Guides")
        discard koi.colorCombo(currTheme.level.cursorGuideColor)

      group:
        koi.label("Grid Style Background")
        koi.dropDown(currTheme.level.gridStyleBackground)

        koi.label("Grid Background")
        discard koi.colorCombo(currTheme.level.gridColorBackground)

        koi.label("Grid Style Floor")
        koi.dropDown(currTheme.level.gridStyleFloor)

        koi.label("Grid Floor")
        discard koi.colorCombo(currTheme.level.gridColorFloor)

      group:
        koi.label("Selection")
        discard koi.colorCombo(currTheme.level.selectionColor)

        koi.label("Paste Preview")
        discard koi.colorCombo(currTheme.level.pastePreviewColor)

      group:
        koi.label("Link Marker")
        discard koi.colorCombo(currTheme.level.linkMarkerColor)

    if koi.subSectionHeader("Background Hatch", sectionBackgroundHatch):
      koi.label("Background Hatch?")
      koi.checkBox(currTheme.level.bgHatch)

      koi.label("Hatch")
      discard koi.colorCombo(currTheme.level.bgHatchColor)

      koi.label("Hatch Stroke Width")
      koi.horizSlider(
        startVal = 0,
        endVal = 10,
        currTheme.level.bgHatchStrokeWidth,
        style = propsSliderStyle,
      )

      koi.label("Hatch Spacing")
      koi.horizSlider(
        startVal = 0,
        endVal = 10,
        currTheme.level.bgHatchSpacingFactor,
        style = propsSliderStyle,
      )

    if koi.subSectionHeader("Outline", sectionOutline):
      koi.label("Outline Style")
      koi.dropDown(currTheme.level.outlineStyle)

      koi.label("Outline Fill Style")
      koi.dropDown(currTheme.level.outlineFillStyle)

      koi.label("Outline Overscan")
      koi.checkBox(currTheme.level.outlineOverscan)

      koi.label("Outline")
      discard koi.colorCombo(currTheme.level.outlineColor)

      koi.label("Outline Width")
      koi.horizSlider(
        startVal = 0,
        endVal = 10,
        currTheme.level.outlineWidthFactor,
        style = propsSliderStyle,
      )

    if koi.subSectionHeader("Shadow", sectionShadow):
      group:
        koi.label("Inner Shadow")
        discard koi.colorCombo(currTheme.level.innerShadowColor)

        koi.label("Inner Shadow Width")
        koi.horizSlider(
          startVal = 0,
          endVal = 10,
          currTheme.level.innerShadowWidthFactor,
          style = propsSliderStyle,
        )

      group:
        koi.label("Outer Shadow")
        discard koi.colorCombo(currTheme.level.outerShadowColor)

        koi.label("Outer Shadow Width")
        koi.horizSlider(
          startVal = 0,
          endVal = 10,
          currTheme.level.outerShadowWidthFactor,
          style = propsSliderStyle,
        )

    if koi.subSectionHeader("Floor Colors", sectionFloorColors):
      koi.label("Floor 1")
      discard koi.colorCombo(currTheme.level.floorColor[0])

      koi.label("Floor 2")
      discard koi.colorCombo(currTheme.level.floorColor[1])

      koi.label("Floor 3")
      discard koi.colorCombo(currTheme.level.floorColor[2])

      koi.label("Floor 4")
      discard koi.colorCombo(currTheme.level.floorColor[3])

      koi.label("Floor 5")
      discard koi.colorCombo(currTheme.level.floorColor[4])

      koi.label("Floor 6")
      discard koi.colorCombo(currTheme.level.floorColor[5])

      koi.label("Floor 7")
      discard koi.colorCombo(currTheme.level.floorColor[6])

      koi.label("Floor 8")
      discard koi.colorCombo(currTheme.level.floorColor[7])

      koi.label("Floor 9")
      discard koi.colorCombo(currTheme.level.floorColor[8])

    if koi.subSectionHeader("Notes", sectionNotes):
      group:
        koi.label("Marker")
        discard koi.colorCombo(currTheme.level.noteMarkerColor)

        koi.label("Comment")
        discard koi.colorCombo(currTheme.level.noteCommentColor)

      group:
        koi.label("Index")
        discard koi.colorCombo(currTheme.level.noteIndexColor)

        koi.label("Index Background 1")
        discard koi.colorCombo(currTheme.level.noteIndexBgColor[0])

        koi.label("Index Background 2")
        discard koi.colorCombo(currTheme.level.noteIndexBgColor[1])

        koi.label("Index Background 3")
        discard koi.colorCombo(currTheme.level.noteIndexBgColor[2])

        koi.label("Index Background 4")
        discard koi.colorCombo(currTheme.level.noteIndexBgColor[3])

      group:
        koi.label("Tooltip Background")
        discard koi.colorCombo(currTheme.level.noteTooltipBgColor)

        koi.label("Tooltip Text")
        discard koi.colorCombo(currTheme.level.noteTooltipTextColor)

  if koi.sectionHeader("Panes", sectionPanes):
    if koi.subSectionHeader("Notes Pane", sectionNotesPane):
      koi.label("Text")
      discard koi.colorCombo(currTheme.notesPane.textColor)

      koi.label("Index")
      discard koi.colorCombo(currTheme.notesPane.indexColor)

      koi.label("Index Background 1")
      discard koi.colorCombo(currTheme.notesPane.indexBgColor[0])

      koi.label("Index Background 2")
      discard koi.colorCombo(currTheme.notesPane.indexBgColor[1])

      koi.label("Index Background 3")
      discard koi.colorCombo(currTheme.notesPane.indexBgColor[2])

      koi.label("Index Background 4")
      discard koi.colorCombo(currTheme.notesPane.indexBgColor[3])

    if koi.subSectionHeader("Toolbar Pane", sectionToolbarPane):
      koi.label("Button Background")
      discard koi.colorCombo(currTheme.toolbarPane.buttonBgColor)

      koi.label("Button Background Hover")
      discard koi.colorCombo(currTheme.toolbarPane.buttonBgColorHover)

  koi.endScrollView()

  #[


#-----------------------------------------------------------------------------

[toolbarPane]
]#
  w = 300.0
  koi.beginScrollView(x = 600, y = 150, w = w, h = 300)

  ap = DefaultAutoLayoutParams
  ap.rowWidth = w
  ap.rightPad = 16

  initAutoLayout(ap)

  if koi.sectionHeader("First section", section1):
    koi.beginGroup()
    koi.label("CheckBox 1")
    koi.checkBox(checkBoxVal1, tooltip = "Checkbox 1")

    koi.label("CheckBox 2")
    koi.checkBox(checkBoxVal2, tooltip = "Checkbox 2")

    koi.label("CheckBox 3")
    koi.checkBox(checkBoxVal3, tooltip = "Checkbox 3")

    koi.label("CheckBox 4")
    koi.checkBox(checkBoxVal4, tooltip = "Checkbox 4")
    koi.endGroup()

    koi.beginGroup()
    koi.label("dropDown 1")
    koi.dropDown(
      items = @["Orange", "Banana", "Blueberry", "Apricot", "Apple"],
      dropDownVal1,
      tooltip = "Select a fruit",
    )

    koi.label("dropDown 2")
    koi.dropDown(
      items = @["One", "Two", "Three"], dropDownVal2, tooltip = "Select a number"
    )
    koi.endGroup()

  if koi.sectionHeader("Second section", section2):
    koi.label("dropDown 1")
    koi.dropDown(
      items = @["Orange", "Banana", "Blueberry", "Apricot", "Apple"],
      dropDownVal3,
      tooltip = "Select a fruit",
    )

    koi.beginGroup()
    koi.label("CheckBox 1")
    koi.checkBox(checkBoxVal5, tooltip = "Checkbox 1")

    koi.label("CheckBox 2")
    koi.checkBox(checkBoxVal6, tooltip = "Checkbox 2")
    koi.endGroup()

  koi.endScrollView()

  ############################################################################

  koi.endFrame()

proc renderFrame(win: Window, res: tuple[w, h: int32] = (0, 0)) =
  if win.iconified:
    return
  renderUI()
  glfw.swapBuffers(win)

proc windowPosCb(win: Window, pos: tuple[x, y: int32]) =
  renderFrame(win)

proc framebufSizeCb(win: Window, size: tuple[w, h: int32]) =
  renderFrame(win)

proc init(): Window =
  glfw.initialize()

  var win = createWindow()

  nvgInit(getProcAddress)
  vg = nvgCreateContext({nifStencilStrokes, nifAntialias, nifDebug})

  if not gladLoadGL(getProcAddress):
    quit "Error initialising OpenGL"

  loadData(vg)

  koi.init(vg, getProcAddress)

  #  koi.scale(1.5)
  win.windowPositionCb = windowPosCb
  win.framebufferSizeCb = framebufSizeCb

  win.pos = (400, 150)
  wrapper.showWindow(win.getHandle())

  result = win

proc cleanup() =
  koi.deinit()
  nvgDeleteContext(vg)
  glfw.terminate()

proc main() =
  let win = init()

  currTheme.levelDropDown.buttonColor = red().withAlpha(0.5)

  while not win.shouldClose:
    if koi.shouldRenderNextFrame():
      glfw.pollEvents()
    else:
      glfw.waitEvents()
    renderFrame(win)

  cleanup()

main()

# vim: et:ts=2:sw=2:fdm=marker
