import koi

proc exampleQuitShortcutDown*(): bool =
  isKeyDown(keyEscape) or (isKeyDown(keyC) and ctrlDown())
