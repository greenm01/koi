## Headless behaviour tests for the text input widgets (textField / textArea).
##
## These widgets measure glyph positions through the live NVG context the
## moment they enter edit mode, so the actual editing interaction (typing,
## cursor movement, selection, clipboard) cannot run without a window. That
## pure editing logic is exercised directly in tests/test_algorithms.nim
## (handleCommonTextEditingShortcuts, insertString, deleteSelection,
## textFieldViewForCursor, textArea*View algorithms, ...).
##
## What we cover here is the headless-reachable state machine: hover/hit
## testing, the guards that decide whether a click *enters* edit mode
## (disabled, focus already captured), the begin-frame pre-pass that exits a
## field on an outside click, and the explicit exit/focus-release path.

import widget_test_common

const
  TfId: ItemId = 390
  TaId: ItemId = 400
  Fx = 40.0
  Fy = 40.0
  Fw = 30.0
  Fh = 12.0

suite "text field hit testing":
  test "hovering marks the field hot without entering edit mode":
    resetUi()
    var text = "hello"
    placeRect(TfId, rect(Fx, Fy, Fw, Fh))
    mouseTo(Fx + 5, Fy + 5) # hover, no button

    textField(TfId, 0, 0, Fw, Fh, text)

    check isHot(TfId)
    check g_uiState.textFieldState.activeItem == 0
    check g_uiState.textFieldState.state == tfsDefault
    check not g_uiState.focusCaptured

suite "text field entry guards":
  test "a disabled field does not enter edit mode on click":
    resetUi()
    var text = "hello"
    placeRect(TfId, rect(Fx, Fy, Fw, Fh))
    pressLeftAt(Fx + 5, Fy + 5)

    textField(TfId, 0, 0, Fw, Fh, text, disabled = true)

    check g_uiState.textFieldState.activeItem == 0
    check g_uiState.textFieldState.state == tfsDefault
    check not g_uiState.focusCaptured

  test "a click is ignored while focus is already captured elsewhere":
    resetUi()
    var text = "hello"
    placeRect(TfId, rect(Fx, Fy, Fw, Fh))
    g_uiState.focusCaptured = true
    pressLeftAt(Fx + 5, Fy + 5)

    textField(TfId, 0, 0, Fw, Fh, text)

    check g_uiState.textFieldState.activeItem == 0
    check g_uiState.textFieldState.state == tfsDefault
    check not isHot(TfId)

suite "text field pre-pass and exit":
  test "the pre-pass exits edit mode on a press outside the field":
    resetUi()
    placeRect(TfId, rect(Fx, Fy, Fw, Fh))
    g_uiState.textFieldState.activeItem = TfId
    g_uiState.textFieldState.state = tfsEdit
    g_uiState.focusCaptured = true
    pressLeftAt(5, 5) # well outside the field

    textFieldPre()

    check g_uiState.textFieldState.activeItem == 0
    check not g_uiState.focusCaptured

  test "the pre-pass keeps edit mode on a press inside the field":
    resetUi()
    placeRect(TfId, rect(Fx, Fy, Fw, Fh))
    g_uiState.textFieldState.activeItem = TfId
    g_uiState.textFieldState.state = tfsEdit
    g_uiState.focusCaptured = true
    pressLeftAt(Fx + 5, Fy + 5) # inside the field

    textFieldPre()

    check g_uiState.textFieldState.activeItem == TfId
    check g_uiState.focusCaptured

  test "exitEditMode resets state and releases captured focus":
    resetUi()
    g_uiState.textFieldState.activeItem = TfId
    g_uiState.textFieldState.state = tfsEdit
    g_uiState.textFieldState.cursorPos = 3
    g_uiState.focusCaptured = true

    textFieldExitEditMode(TfId)

    check g_uiState.textFieldState.activeItem == 0
    check g_uiState.textFieldState.state == tfsDefault
    check g_uiState.textFieldState.cursorPos == 0
    check not g_uiState.focusCaptured

suite "text area hit testing":
  test "hovering marks the area hot without entering edit mode":
    resetUi()
    var text = "hello world"
    placeRect(TaId, rect(Fx, Fy, 40, 30))
    mouseTo(Fx + 5, Fy + 5)

    textArea(TaId, 0, 0, 40, 30, text)

    check isHot(TaId)
    check not g_uiState.focusCaptured

  test "a disabled area does not capture focus on click":
    resetUi()
    var text = "hello world"
    placeRect(TaId, rect(Fx, Fy, 40, 30))
    pressLeftAt(Fx + 5, Fy + 5)

    textArea(TaId, 0, 0, 40, 30, text, disabled = true)

    check not g_uiState.focusCaptured
