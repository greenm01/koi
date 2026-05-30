proc color*(
    id: ItemId, x, y, w, h: float, color_out: var Color, disabled: bool = false
) =
  discard drawColorSwatch(id, x, y, w, h, color_out, disabled)

proc colorPicker*(
    id: ItemId, x, y, w, h: float, color: var Color, disabled: bool = false
) =
  alias(ui, g_uiState)
  alias(cs, ui.colorPickerState)

  let (sx, sy) = addDrawOffset(x, y)
  let swatchSlot = layoutSlot(id, rect(sx, sy, w, h))

  if not disabled and
      isHit(
        swatchSlot.previousBounds.x, swatchSlot.previousBounds.y,
        swatchSlot.previousBounds.w, swatchSlot.previousBounds.h,
      ):
    if hasEvent() and ui.currEvent.kind == ekKey and ui.currEvent.action == kaDown:
      let shortcut = mkKeyShortcut(ui.currEvent.key, ui.currEvent.mods)
      if shortcut == copyColorShortcut():
        markEventHandled()
        cs.colorCopyBuffer = color
      elif shortcut == pasteColorShortcut():
        markEventHandled()
        color = cs.colorCopyBuffer

  if drawColorSwatchWithSlot(swatchSlot, id, color, disabled = disabled):
    cs.activeItem = id
    cs.opened = true
    cs.mouseMode = cmmNormal
    openPopup(id)

  let popupId = hashId($id & ":popup")
  if disabled and isPopupOpen(id):
    closePopup()

  if not disabled and isPopupOpen(id):
    let popupSlot = layoutFollowerSlot(
      popupId,
      rect(sx - 1, sy + h, ColorPickerPopupWidth, ColorPickerPopupHeight),
      swatchSlot.nodeId,
      lfkDropdownPopup,
    )
    if beginPopupWithSlot(id, popupSlot):
      try:
        var
          px = ColorPickerPad
          py = 178.0
          pw = ColorPickerPopupWidth - ColorPickerPad * 2
          ph = 20.0

        cs.lastColorMode = cs.colorMode
        var activeModes = @[cs.colorMode]
        radioButtons(
          hashId($id & ":mode"),
          px,
          py,
          pw + 2,
          ph + 2,
          @["RGB", "HSV", "Hex"],
          activeModes,
          style = ColorPickerRadioButtonStyle,
        )
        cs.colorMode = activeModes[0]

        py += 30

        const
          RgbMax = 255.0
          HueMax = 360.0
          SatMax = 100.0
          ValMax = 100.0
          AlphaMax = 255.0
          Eps = 0.0001

        case cs.colorMode
        of ccmRGB:
          var
            r = color.r.float * RgbMax
            g = color.g.float * RgbMax
            b = color.b.float * RgbMax
            a = color.a.float * AlphaMax

          horizSlider(
            hashId($id & ":r"),
            px,
            py,
            pw,
            ph,
            startVal = 0,
            endVal = RgbMax,
            r,
            grouping = wgStart,
            label = "R",
            style = ColorPickerSliderStyle,
          )
          py += 20
          horizSlider(
            hashId($id & ":g"),
            px,
            py,
            pw,
            ph,
            startVal = 0,
            endVal = RgbMax,
            g,
            grouping = wgMiddle,
            label = "G",
            style = ColorPickerSliderStyle,
          )
          py += 20
          horizSlider(
            hashId($id & ":b"),
            px,
            py,
            pw,
            ph,
            startVal = 0,
            endVal = RgbMax,
            b,
            grouping = wgEnd,
            label = "B",
            style = ColorPickerSliderStyle,
          )
          py += 30
          horizSlider(
            hashId($id & ":a-rgb"),
            px,
            py,
            pw,
            ph - 1,
            startVal = 0,
            endVal = AlphaMax,
            a,
            label = "A",
            style = ColorPickerSliderStyle,
          )

          var (hue, sat, value) =
            rgba(r / RgbMax, g / RgbMax, b / RgbMax, a / AlphaMax).toHSV
          if sat < Eps or (r < Eps and g < Eps and b < Eps):
            hue = cs.lastHue
          colorWheel(
            hashId($id & ":wheel"),
            px,
            ColorPickerWheelY,
            pw + 0.5,
            pw + 0.5,
            hue,
            sat,
            value,
          )
          cs.lastHue = hue
          color = hsva(hue, sat, value, a / AlphaMax)
        of ccmHSV:
          if cs.opened or cs.lastColorMode != ccmHSV:
            (cs.h, cs.s, cs.v) = color.toHSV

          var
            hue = cs.h * HueMax
            sat = cs.s * SatMax
            value = cs.v * ValMax
            a = color.a.float * AlphaMax

          horizSlider(
            hashId($id & ":h"),
            px,
            py,
            pw,
            ph,
            startVal = 0,
            endVal = HueMax,
            hue,
            grouping = wgStart,
            label = "H",
            style = ColorPickerSliderStyle,
          )
          py += 20
          horizSlider(
            hashId($id & ":s"),
            px,
            py,
            pw,
            ph,
            startVal = 0,
            endVal = SatMax,
            sat,
            grouping = wgMiddle,
            label = "S",
            style = ColorPickerSliderStyle,
          )
          py += 20
          horizSlider(
            hashId($id & ":v"),
            px,
            py,
            pw,
            ph,
            startVal = 0,
            endVal = ValMax,
            value,
            grouping = wgEnd,
            label = "V",
            style = ColorPickerSliderStyle,
          )
          py += 30
          horizSlider(
            hashId($id & ":a-hsv"),
            px,
            py,
            pw,
            ph - 1,
            startVal = 0,
            endVal = AlphaMax,
            a,
            label = "A",
            style = ColorPickerSliderStyle,
          )

          (cs.h, cs.s, cs.v) = (hue / HueMax, sat / SatMax, value / ValMax)
          colorWheel(
            hashId($id & ":wheel"),
            px,
            ColorPickerWheelY,
            pw + 0.5,
            pw + 0.5,
            cs.h,
            cs.s,
            cs.v,
          )
          color = hsva(cs.h, cs.s, cs.v, a / AlphaMax)
        of ccmHex:
          if cs.opened or cs.lastColorMode != ccmHex:
            cs.hexString = color.toHex

          var a = color.a.float * AlphaMax
          textField(
            hashId($id & ":hex"),
            px,
            py,
            pw,
            ph - 1,
            cs.hexString,
            style = ColorPickerTextFieldStyle,
            filter = tffHex,
          )

          py += 70
          horizSlider(
            hashId($id & ":a-hex"),
            px,
            py,
            pw,
            ph - 1,
            startVal = 0,
            endVal = AlphaMax,
            a,
            label = "A",
            style = ColorPickerSliderStyle,
          )

          var editedColor =
            if cs.hexString.len >= 6:
              colorFromHexStr(cs.hexString).withAlpha(a / AlphaMax)
            else:
              color.withAlpha(a / AlphaMax)
          var (hue, sat, value) = editedColor.toHSV
          let (oldHue, oldSat, oldValue) = (hue, sat, value)
          colorWheel(
            hashId($id & ":wheel"),
            px,
            ColorPickerWheelY,
            pw + 0.5,
            pw + 0.5,
            hue,
            sat,
            value,
          )
          editedColor = hsva(hue, sat, value, a / AlphaMax)
          if hue != oldHue or sat != oldSat or value != oldValue:
            cs.hexString = editedColor.toHex
          color = editedColor

        cs.opened = false
      finally:
        endPopup()

  if not isPopupOpen(id) and cs.activeItem == id:
    cs.activeItem = 0
    cs.mouseMode = cmmNormal
