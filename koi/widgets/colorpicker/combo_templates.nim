proc colorCombo*(
    id: ItemId,
    x, y, w, h: float,
    color: var Color,
    label: string = "",
    style: ColorComboStyle = borrowDefaultColorComboStyle(),
    disabled: bool = false,
): bool =
  let oldColor = color
  let (sx, sy) = addDrawOffset(x, y)
  let buttonSlot = layoutSlot(id, rect(sx, sy, w, h))
  if buttonWithSlot(buttonSlot, id, label, "", disabled, style = style.button):
    openPopup(id)

  let swatchPad = max(3.0, h * 0.18)
  let swatchSize = max(0.0, h - swatchPad * 2)
  let previewId = hashId($id & ":preview")
  let previewSlot = layoutFollowerSlot(
    previewId,
    rect(sx + swatchPad, sy + swatchPad, swatchSize, swatchSize),
    buttonSlot.nodeId,
    lfkInsetFixed,
    followInset = padding(swatchPad, 0, swatchPad, 0),
  )
  discard drawColorSwatchWithSlot(previewSlot, previewId, color, interactive = false)

  let popupId = hashId($id & ":popup")
  if disabled and isPopupOpen(id):
    closePopup()

  if not disabled and isPopupOpen(id):
    let popupSlot = layoutFollowerSlot(
      popupId,
      rect(sx, sy + h, style.popupWidth, style.popupHeight),
      buttonSlot.nodeId,
      lfkDropdownPopup,
    )
    if beginPopupWithSlot(id, popupSlot, style.popup):
      try:
        var
          px = style.popupPad
          py = style.popupPad
        for i, preset in style.presetColors:
          if px + style.swatchSize > style.popupWidth - style.popupPad:
            px = style.popupPad
            py += style.swatchSize + style.swatchGap
          if drawColorSwatch(
            hashId($id & ":preset:" & $i),
            px,
            py,
            style.swatchSize,
            style.swatchSize,
            preset,
            disabled,
          ):
            color = preset
            closePopup()
          px += style.swatchSize + style.swatchGap
      finally:
        endPopup()

  result =
    color.r != oldColor.r or color.g != oldColor.g or color.b != oldColor.b or
    color.a != oldColor.a

template color*(x, y, w, h: float, color: var Color, disabled: bool = false) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)
  color(id, x, y, w, h, color, disabled)

template color*(col: var Color, disabled: bool = false) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)
  autoLayoutPre()
  color(
    id,
    g_uiState.autoLayoutState.x,
    autoLayoutNextY(),
    autoLayoutNextItemWidth(),
    autoLayoutNextItemHeight(),
    col,
    disabled,
  )
  autoLayoutPost()

template colorPicker*(x, y, w, h: float, color: var Color, disabled: bool = false) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)
  colorPicker(id, x, y, w, h, color, disabled)

template colorPicker*(color: var Color, disabled: bool = false) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)
  autoLayoutPre()
  colorPicker(
    id,
    g_uiState.autoLayoutState.x,
    autoLayoutNextY(),
    autoLayoutNextItemWidth(),
    autoLayoutNextItemHeight(),
    color,
    disabled,
  )
  autoLayoutPost()

template colorCombo*(
    x, y, w, h: float,
    color: var Color,
    label: string = "",
    style: ColorComboStyle = borrowDefaultColorComboStyle(),
    disabled: bool = false,
): bool =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line, label)
  colorCombo(id, x, y, w, h, color, label, style, disabled)

template colorCombo*(
    color: var Color,
    label: string = "",
    style: ColorComboStyle = borrowDefaultColorComboStyle(),
    disabled: bool = false,
): bool =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line, label)
  autoLayoutPre()
  let changed = colorCombo(
    id,
    g_uiState.autoLayoutState.x,
    autoLayoutNextY(),
    autoLayoutNextItemWidth(),
    autoLayoutNextItemHeight(),
    color,
    label,
    style,
    disabled,
  )
  autoLayoutPost()
  changed
