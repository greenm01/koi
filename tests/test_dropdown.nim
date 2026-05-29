## Headless behaviour tests for the dropdown widget: opening from a click,
## mouse selection, keyboard navigation and commit, escape/outside-click
## dismissal, and the disabled guard.

import widget_test_common

type Choice = enum
  choiceA
  choiceB
  choiceC

const Items = @["A", "B", "C"]

# Button geometry reused across tests.
const
  DdId: ItemId = 47
  BtnX = 40.0
  BtnY = 40.0
  BtnW = 30.0
  BtnH = 20.0

proc placeButton() =
  placeRect(DdId, rect(BtnX, BtnY, BtnW, BtnH))

proc openDropDown(selected: var Choice) =
  ## Drive a press inside the button to open the popup.
  placeButton()
  pressLeftAt(BtnX + 5, BtnY + 5)
  dropDown(DdId, BtnX, BtnY, BtnW, BtnH, Items, selected, "", disabled = false)

suite "dropdown opening":
  test "click on the button opens the popup and captures focus":
    resetUi()
    var selected = choiceA
    openDropDown(selected)

    check isPopupOpen(DdId)
    check g_uiState.focusCaptured
    check dropDownStateOf(DdId).state == dsOpenLMBPressed
    check dropDownStateOf(DdId).activeItem == DdId
    check dropDownStateOf(DdId).keyboardItem == ord(choiceA)

  test "disabled dropdown does not open on click":
    resetUi()
    var selected = choiceA
    placeButton()
    pressLeftAt(BtnX + 5, BtnY + 5)
    dropDown(DdId, BtnX, BtnY, BtnW, BtnH, Items, selected, "", disabled = true)

    check not isPopupOpen(DdId)
    check dropDownStateOf(DdId).state == dsClosed

  test "click outside an open dropdown closes it":
    resetUi()
    var selected = choiceA
    openDropDown(selected)

    # Release, then press far from both the button and the item list.
    releaseLeft()
    dropDown(DdId, BtnX, BtnY, BtnW, BtnH, Items, selected, "", disabled = false)

    pressLeftAt(5, 5)
    dropDown(DdId, BtnX, BtnY, BtnW, BtnH, Items, selected, "", disabled = false)

    check not isPopupOpen(DdId)
    check dropDownStateOf(DdId).state == dsClosed
    check not g_uiState.focusCaptured

suite "dropdown keyboard navigation":
  test "down arrow advances the keyboard item":
    resetUi()
    var selected = choiceA
    openDropDown(selected)

    releaseLeft()
    mouseTo(0, 0) # keep the mouse clear of the list so it doesn't override
    sendKey(keyDown)
    dropDown(DdId, BtnX, BtnY, BtnW, BtnH, Items, selected, "", disabled = false)

    check dropDownStateOf(DdId).keyboardItem == ord(choiceB)
    check eventHandled()
    check isPopupOpen(DdId)

  test "down arrow clamps at the last item":
    resetUi()
    var selected = choiceC
    openDropDown(selected)

    releaseLeft()
    mouseTo(0, 0)
    for _ in 0 .. 3:
      sendKey(keyDown)
      dropDown(DdId, BtnX, BtnY, BtnW, BtnH, Items, selected, "", disabled = false)

    check dropDownStateOf(DdId).keyboardItem == ord(choiceC)

  test "enter commits the keyboard item and closes":
    resetUi()
    var selected = choiceA
    openDropDown(selected)

    releaseLeft()
    mouseTo(0, 0)
    sendKey(keyDown)
    dropDown(DdId, BtnX, BtnY, BtnW, BtnH, Items, selected, "", disabled = false)

    sendKey(keyEnter)
    dropDown(DdId, BtnX, BtnY, BtnW, BtnH, Items, selected, "", disabled = false)

    check selected == choiceB
    check not isPopupOpen(DdId)
    check dropDownStateOf(DdId).state == dsClosed

  test "escape closes without changing the selection":
    resetUi()
    var selected = choiceB
    openDropDown(selected)

    releaseLeft()
    mouseTo(0, 0)
    sendKey(keyEscape)
    dropDown(DdId, BtnX, BtnY, BtnW, BtnH, Items, selected, "", disabled = false)

    check selected == choiceB
    check not isPopupOpen(DdId)
    check eventHandled()

suite "dropdown mouse selection":
  test "release over an item selects it and closes":
    resetUi()
    var selected = choiceA
    let listId = hashId($DdId & ":popupList")
    let style = borrowDefaultDropDownStyle()

    # Item list directly below the button; item height equals button height.
    let listRect = rect(BtnX, BtnY + BtnH, BtnW, BtnH * Items.len.float)
    openDropDown(selected)
    placeRect(listId, listRect)

    # Drag down onto the second item (visible index 1), still holding LMB.
    let itemY = listRect.y + style.itemListPadVert + BtnH * 1.5
    mouseTo(BtnX + 5, itemY)
    dropDown(DdId, BtnX, BtnY, BtnW, BtnH, Items, selected, "", disabled = false)
    check dropDownStateOf(DdId).keyboardItem == ord(choiceB)

    # Release over the item -> commit + close.
    releaseLeft()
    dropDown(DdId, BtnX, BtnY, BtnW, BtnH, Items, selected, "", disabled = false)

    check selected == choiceB
    check not isPopupOpen(DdId)
