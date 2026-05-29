## Headless behaviour tests for color widgets: the full HSV color picker popup
## and the preset color combo popup.

import widget_test_common

const
  CcId: ItemId = 80
  Bx = 40.0
  By = 40.0
  Bw = 40.0
  Bh = 20.0

let PopupId = hashId($CcId & ":popup")

proc combo(color: var Color): bool =
  colorCombo(CcId, Bx, By, Bw, Bh, color, "Accent")

proc openCombo(color: var Color) =
  ## Press then release on the button to open the preset popup.
  placeRect(CcId, rect(Bx, By, Bw, Bh))
  pressLeftAt(Bx + Bw * 0.5, By + Bh * 0.5)
  discard combo(color)
  nextFrame()
  releaseLeft()
  mouseTo(Bx + Bw * 0.5, By + Bh * 0.5)
  discard combo(color)

const
  CpId: ItemId = 90
  Px = 30.0
  Py = 30.0
  Pw = 40.0
  Ph = 20.0

let PickerPopupId = hashId($CpId & ":popup")

proc picker(color: var Color) =
  colorPicker(CpId, Px, Py, Pw, Ph, color)

proc openPicker(color: var Color) =
  placeRect(CpId, rect(Px, Py, Pw, Ph))
  pressLeftAt(Px + Pw * 0.5, Py + Ph * 0.5)
  picker(color)
  nextFrame()
  releaseLeft()
  mouseTo(Px + Pw * 0.5, Py + Ph * 0.5)
  picker(color)

proc placePickerPopup() =
  placeRect(PickerPopupId, rect(Px, Py + Ph, 180, 311))

suite "color combo popup":
  test "click on the button opens the preset popup":
    resetUi()
    var color = rgb(0.2, 0.4, 0.8)

    placeRect(CcId, rect(Bx, By, Bw, Bh))
    pressLeftAt(Bx + Bw * 0.5, By + Bh * 0.5)
    check not combo(color)
    check isActive(CcId)
    check not isPopupOpen(CcId)

    nextFrame()
    releaseLeft()
    check not combo(color)
    check isPopupOpen(CcId)
    check g_uiState.focusCaptured

suite "color combo selection":
  test "clicking a preset swatch commits the color and closes the popup":
    resetUi()
    var color = rgb(0.2, 0.4, 0.8)
    let presetId = hashId($CcId & ":preset:2") # red preset rgb(0.88, 0.18, 0.16)
    let expected = rgb(0.88, 0.18, 0.16)

    openCombo(color)
    check isPopupOpen(CcId)

    # Place the popup and the target preset rects so hit testing resolves.
    # Park every non-target preset off-screen so only preset 2 can be hit.
    placeRect(PopupId, rect(Bx, By + Bh, 140, 120))
    for i in 0 .. 8:
      placeRect(hashId($CcId & ":preset:" & $i), rect(-100, -100, 1, 1))
    placeRect(presetId, rect(50, 70, 12, 12))

    # Press on the preset swatch.
    nextFrame()
    pressLeftAt(56, 76)
    discard combo(color)

    # Release on the preset -> commit + close.
    nextFrame()
    releaseLeft()
    mouseTo(56, 76)
    let changed = combo(color)

    check not isPopupOpen(CcId)
    check abs(color.r - expected.r) < 1e-6
    check abs(color.g - expected.g) < 1e-6
    check abs(color.b - expected.b) < 1e-6
    check changed

  test "a frame with no swatch interaction reports no change":
    resetUi()
    var color = rgb(0.2, 0.4, 0.8)
    openCombo(color)
    placeRect(PopupId, rect(Bx, By + Bh, 140, 120))

    nextFrame()
    mouseTo(0, 0) # away from every swatch
    let changed = combo(color)

    check not changed
    check isPopupOpen(CcId)

suite "color picker popup":
  test "clicking the swatch opens the full picker popup":
    resetUi()
    var color = rgb(0.2, 0.4, 0.8)

    openPicker(color)

    check isPopupOpen(CpId)
    check g_uiState.focusCaptured
    check g_uiState.colorPickerState.activeItem == CpId

  test "outside click closes the picker popup and releases focus":
    resetUi()
    var color = rgb(0.2, 0.4, 0.8)

    openPicker(color)
    placePickerPopup()

    nextFrame()
    releaseLeft()
    picker(color)

    nextFrame()
    pressLeftAt(5, 5)
    picker(color)

    check not isPopupOpen(CpId)
    check not g_uiState.focusCaptured

  test "open auto-layout picker popup follows the swatch":
    resetUi()
    var params = DefaultAutoLayoutParams
    params.itemsPerRow = 1
    params.rowWidth = 60
    params.leftPad = 0
    params.rightPad = 0
    params.rowPad = 0
    params.sectionPad = 0
    params.defaultRowHeight = 20
    params.defaultItemHeight = 20
    initAutoLayout(params)
    openPopup(CpId)

    beginFrameLayout()
    var color = rgb(0.2, 0.4, 0.8)
    autoLayoutPre()
    let pickerRow = g_uiState.autoLayoutState.autoRow
    colorPicker(
      CpId,
      g_uiState.autoLayoutState.x,
      autoLayoutNextY(),
      autoLayoutNextItemWidth(),
      autoLayoutNextItemHeight(),
      color,
    )
    autoLayoutPost()
    finishFrameLayout()

    var rowChildren = 0
    var popupNode = NullLayoutNodeId
    for node in g_uiState.layoutArena.nodes:
      if int32(node.parent) == int32(pickerRow):
        inc rowChildren
      if node.itemId == PickerPopupId:
        popupNode = node.id

    check rowChildren == 1
    check not popupNode.isNull
    check g_uiState.layoutArena.nodes[popupNode.int].placement.kind == lpkFollow
    check g_uiState.layoutArena.nodes[popupNode.int].placement.followKind ==
      lfkDropdownPopup
    check int32(g_uiState.layoutArena.nodes[popupNode.int].placement.target) !=
      int32(NullLayoutNodeId)

suite "color picker editing":
  test "RGB slider updates the color":
    resetUi()
    var color = rgb(0.0, 0.4, 0.8)
    openPicker(color)
    g_uiState.colorPickerState.colorMode = ccmRGB
    placePickerPopup()
    placeRect(hashId($CpId & ":r"), rect(43, 258, 152, 20))

    nextFrame()
    pressLeftAt(194, 268)
    picker(color)

    check color.r > 0.95

  test "HSV slider updates the color":
    resetUi()
    var color = rgb(1.0, 0.0, 0.0)
    openPicker(color)
    g_uiState.colorPickerState.colorMode = ccmHSV
    placePickerPopup()
    placeRect(hashId($CpId & ":h"), rect(43, 258, 152, 20))

    nextFrame()
    pressLeftAt(119, 268)
    picker(color)

    check g_uiState.colorPickerState.h > 0.45
    check g_uiState.colorPickerState.h < 0.55

  test "hex text state updates the color":
    resetUi()
    var color = rgb(0.0, 0.0, 0.0)
    openPicker(color)
    g_uiState.colorPickerState.colorMode = ccmHex
    g_uiState.colorPickerState.opened = false
    g_uiState.colorPickerState.lastColorMode = ccmHex
    g_uiState.colorPickerState.hexString = "00FF00"
    placePickerPopup()

    nextFrame()
    mouseTo(5, 5)
    picker(color)

    check color.g > 0.95
    check color.r < 0.05
    check color.b < 0.05
