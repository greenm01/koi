## Headless behaviour tests for the menu widget, focused on context-menu
## interaction: opening from a right click, ignoring clicks outside the anchor,
## escape-to-close, the disabled-item guard, and enabled-item activation
## closing the popup.

import widget_test_common

const MenuId: ItemId = 40

proc openContextMenu(): bool =
  ## Right click inside the anchor bounds to open the popup.
  pressRightAt(16, 16)
  result = beginContextMenu(MenuId, 0, 0, 30, 30, 100, 60)

suite "context menu opening":
  test "right click inside the anchor opens the popup":
    resetUi()
    check openContextMenu()
    check isPopupOpen(MenuId)
    endContextMenu()

  test "right click outside the anchor does not open":
    resetUi()
    pressRightAt(50, 50)
    check not beginContextMenu(MenuId, 0, 0, 30, 30, 100, 60)
    check not isPopupOpen(MenuId)

suite "context menu dismissal":
  test "escape closes an open context menu":
    resetUi()
    check openContextMenu()
    endContextMenu()

    releaseRight()
    nextFrame()
    sendKey(keyEscape)
    check not beginContextMenu(MenuId, 0, 0, 30, 30, 100, 60)
    check not isPopupOpen(MenuId)
    check eventHandled()

suite "menu item activation":
  test "a disabled item never activates and keeps the menu open":
    resetUi()
    check openContextMenu()
    endContextMenu()

    releaseRight()
    nextFrame()
    pressLeftAt(22, 22)
    check beginContextMenu(MenuId, 0, 0, 30, 30, 100, 60)
    check not menuItem(41, "Nope", disabled = true)
    endContextMenu()

    nextFrame()
    releaseLeft()
    mouseTo(22, 22)
    check beginContextMenu(MenuId, 0, 0, 30, 30, 100, 60)
    check not menuItem(41, "Nope", disabled = true)
    endContextMenu()

    check isPopupOpen(MenuId)

  test "an enabled item activates on release and closes the menu":
    resetUi()
    check openContextMenu()
    endContextMenu()

    releaseRight()
    nextFrame()
    pressLeftAt(22, 22)
    check beginContextMenu(MenuId, 0, 0, 30, 30, 100, 60)
    check not menuItem(41, "Action") # not selected until release
    endContextMenu()

    nextFrame()
    releaseLeft()
    mouseTo(22, 22)
    check beginContextMenu(MenuId, 0, 0, 30, 30, 100, 60)
    check menuItem(41, "Action")
    check not isPopupOpen(MenuId)
    endContextMenu()
