import koi

proc exampleQuitShortcutDown*(): bool =
  ctrlDown() and (isKeyDown(keyQ) or isKeyDown(keyC))
