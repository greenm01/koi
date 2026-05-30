import std/math

import nanovg

import koi/types
import koi/core
import koi/drawing
import koi/layout
import koi/rect
import koi/input
import koi/defaults
import koi/deps/with
import koi/internal/widget_behavior
import koi/widgets/button
import koi/widgets/popup
import koi/widgets/radiobuttons
import koi/widgets/slider
import koi/widgets/textfield
import koi/utils

const
  ColorPickerPopupWidth = 180.0
  ColorPickerPopupHeight = 311.0
  ColorPickerPad = 14.0
  ColorPickerWheelY = 14.0

func copyColorShortcut(): KeyShortcut =
  when defined(macosx):
    mkKeyShortcut(keyC, {mkSuper})
  else:
    mkKeyShortcut(keyC, {mkCtrl})

func pasteColorShortcut(): KeyShortcut =
  when defined(macosx):
    mkKeyShortcut(keyV, {mkSuper})
  else:
    mkKeyShortcut(keyV, {mkCtrl})

var ColorPickerRadioButtonStyle = RadioButtonsStyle(
  buttonPadHoriz: 2.0,
  buttonPadVert: 3.0,
  buttonCornerRadius: 4.0,
  buttonStrokeWidth: 0.0,
  buttonStrokeColor: black(),
  buttonStrokeColorHover: black(),
  buttonStrokeColorDown: black(),
  buttonStrokeColorActive: black(),
  buttonStrokeColorActiveHover: black(),
  buttonFillColor: gray(0.25),
  buttonFillColorHover: gray(0.25),
  buttonFillColorDown: gray(0.45),
  buttonFillColorActive: gray(0.45),
  buttonFillColorActiveHover: gray(0.45),
  label: defaultLabelStyle(),
)

with ColorPickerRadioButtonStyle.label:
  fontSize = 13.0
  fontFace = "sans-bold"
  padHoriz = 0.0
  align = haCenter
  color = gray(0.6)
  colorHover = gray(0.6)
  colorDown = gray(0.8)
  colorActive = white()
  colorActiveHover = white()

var ColorPickerSliderStyle = SliderStyle(
  trackCornerRadius: 4.0,
  trackPad: 0.0,
  trackStrokeWidth: 1.0,
  trackStrokeColor: gray(0.1),
  trackStrokeColorHover: gray(0.1),
  trackStrokeColorDown: gray(0.1),
  trackFillColor: gray(0.25),
  trackFillColorHover: gray(0.30),
  trackFillColorDown: gray(0.25),
  valuePrecision: 0,
  valueSuffix: "",
  valueCornerRadius: 4.0,
  sliderColor: gray(0.45),
  sliderColorHover: gray(0.55),
  sliderColorDown: gray(0.45),
  label: defaultLabelStyle(),
  value: defaultLabelStyle(),
  cursorFollowsValue: true,
  commitOnPress: true,
)

with ColorPickerSliderStyle:
  label.padHoriz = 5.0
  label.fontSize = 13.0
  label.fontFace = "sans-bold"
  label.align = haLeft
  label.color = gray(0.8)
  label.colorHover = gray(0.9)
  label.colorDown = gray(0.8)

  value.padHoriz = 5.0
  value.fontSize = 13.0
  value.fontFace = "sans"
  value.align = haRight
  value.color = white()
  value.colorHover = white()
  value.colorDown = white()

var ColorPickerTextFieldStyle = TextFieldStyle(
  bgCornerRadius: 4.0,
  bgStrokeWidth: 1.0,
  bgStrokeColor: gray(0.1),
  bgStrokeColorHover: gray(0.1),
  bgStrokeColorActive: gray(0.1),
  bgStrokeColorDisabled: gray(0.1),
  bgFillColor: gray(0.25),
  bgFillColorHover: gray(0.30),
  bgFillColorActive: gray(0.25),
  bgFillColorDisabled: gray(0.20),
  textPadHoriz: 8.0,
  textPadVert: 2.0,
  textFontSize: 13.0,
  textFontFace: "sans-bold",
  textColor: gray(0.8),
  textColorHover: gray(0.8),
  textColorActive: gray(0.8),
  textColorDisabled: gray(0.5),
  cursorColor: rgb(255, 190, 0),
  cursorWidth: 1.0,
  selectionColor: rgba(200, 130, 0, 100),
)

proc drawColorSwatchWithSlot(
    slot: LayoutSlot,
    id: ItemId,
    color: Color,
    interactive: bool = true,
    disabled: bool = false,
): bool =
  alias(ui, g_uiState)

  if interactive and
      isHit(
        slot.previousBounds.x, slot.previousBounds.y, slot.previousBounds.w,
        slot.previousBounds.h,
      ):
    captureSimpleWidget(id, disabled)

  if interactive:
    let behavior = simpleWidgetBehavior(id, disabled)
    result = behavior.clicked

  addLayoutDrawLayer(ui.currentLayer, slot.nodeId, vg, bounds):
    let
      sw = 1.0
      (rx, ry, rw, rh) = snapToGrid(bounds.x, bounds.y, bounds.w, bounds.h, sw)
      cr = 5.0
      colorWidth = rw * 0.5

    vg.fillColor(color.withAlpha(1.0))
    vg.beginPath()
    vg.roundedRect(rx, ry, colorWidth, rh, cr, 0, 0, cr)
    vg.fill()

    vg.fillColor(color)
    vg.beginPath()
    vg.roundedRect(rx + colorWidth, ry, rw - colorWidth, rh, 0, cr, cr, 0)
    vg.fill()

    vg.strokeColor(gray(0.1))
    vg.strokeWidth(sw)
    vg.beginPath()
    vg.roundedRect(rx, ry, rw, rh, cr)
    vg.stroke()

proc drawColorSwatch(
    id: ItemId, x, y, w, h: float, color: Color, disabled: bool = false
): bool =
  let (x, y) = addDrawOffset(x, y)
  let slot = layoutSlot(id, rect(x, y, w, h))
  drawColorSwatchWithSlot(slot, id, color, disabled = disabled)

proc colorWheel(id: ItemId, x, y, w, h: float, hue, sat, val: var float) =
  alias(ui, g_uiState)
  alias(cs, ui.colorPickerState)

  let (x, y) = addDrawOffset(x, y)
  let slot = layoutSlot(id, rect(x, y, w, h))
  let hitBounds = slot.previousBounds

  func hueFromWheelAngle(a: float): float =
    let aa =
      if a > 0:
        a
      else:
        2 * PI + a
    (aa / (2 * PI) + 0.5) mod 1.0

  func edge(ax, ay, bx, by, px, py: float): float =
    (px - ax) * (by - ay) - (py - ay) * (bx - ax)

  proc wheelGeometry(
      bounds: Rect
  ): tuple[cx, cy, r0, r1, blackX, blackY, whiteX, whiteY, colorX, colorY: float] =
    result.cx = bounds.x + bounds.w * 0.5
    result.cy = bounds.y + bounds.h * 0.5
    result.r1 = min(bounds.w, bounds.h) * 0.5
    result.r0 = result.r1 - result.r1 * 0.20
    result.blackX = result.cx + result.r0 * cos(5 * PI / 6)
    result.blackY = result.cy + result.r0 * sin(5 * PI / 6)
    result.whiteX = result.cx + result.r0 * cos(PI / 6)
    result.whiteY = result.cy + result.r0 * sin(PI / 6)
    result.colorX = result.cx + result.r0 * cos(1.5 * PI)
    result.colorY = result.cy + result.r0 * sin(1.5 * PI)

  let geom = wheelGeometry(hitBounds)

  proc wheelAngleFromCursor(): float =
    arctan2(ui.my - geom.cy, ui.mx - geom.cx)

  proc cursorInHueRing(): bool =
    let distance = hypot(ui.mx - geom.cx, ui.my - geom.cy)
    distance >= geom.r0 and distance <= geom.r1

  proc triangleBarycentric(px, py: float): tuple[black, white, color: float] =
    let denom =
      edge(geom.blackX, geom.blackY, geom.whiteX, geom.whiteY, geom.colorX, geom.colorY)
    if abs(denom) < 0.000001:
      return (0.0, 0.0, 0.0)
    result.black =
      edge(geom.whiteX, geom.whiteY, geom.colorX, geom.colorY, px, py) / denom
    result.white =
      edge(geom.colorX, geom.colorY, geom.blackX, geom.blackY, px, py) / denom
    result.color =
      edge(geom.blackX, geom.blackY, geom.whiteX, geom.whiteY, px, py) / denom

  proc cursorInTriangle(): bool =
    let b = triangleBarycentric(ui.mx, ui.my)
    b.black >= 0 and b.white >= 0 and b.color >= 0

  proc triangleCursorValues(): tuple[sat, val: float] =
    var b = triangleBarycentric(ui.mx, ui.my)
    b.black = max(0.0, b.black)
    b.white = max(0.0, b.white)
    b.color = max(0.0, b.color)

    let total = b.black + b.white + b.color
    if total <= 0.000001:
      return (0.0, 0.0)
    b.black /= total
    b.white /= total
    b.color /= total

    result.val = clamp(b.white + b.color, 0.0, 1.0)
    result.sat =
      if result.val <= 0.000001:
        0.0
      else:
        clamp(b.color / result.val, 0.0, 1.0)

  if isHit(hitBounds.x, hitBounds.y, hitBounds.w, hitBounds.h):
    markHot(id)

  if cs.mouseMode == cmmNormal and isHot(id) and ui.mbLeftDown and hasNoActiveItem():
    if cursorInHueRing():
      hue = hueFromWheelAngle(wheelAngleFromCursor())
      cs.mouseMode = cmmDragWheel
      markActive(id)
      ui.focusCaptured = true
    elif cursorInTriangle():
      (sat, val) = triangleCursorValues()
      cs.mouseMode = cmmDragTriangle
      markActive(id)
      ui.focusCaptured = true
    else:
      cs.mouseMode = cmmLMBDown
      markActive(id)
  elif cs.mouseMode == cmmLMBDown:
    if not ui.mbLeftDown:
      cs.mouseMode = cmmNormal

  if cs.mouseMode == cmmDragWheel:
    if not ui.mbLeftDown:
      cs.mouseMode = cmmNormal
      ui.focusCaptured = false
    else:
      hue = hueFromWheelAngle(wheelAngleFromCursor())
  elif cs.mouseMode == cmmDragTriangle:
    if not ui.mbLeftDown:
      cs.mouseMode = cmmNormal
      ui.focusCaptured = false
    else:
      (sat, val) = triangleCursorValues()

  let
    drawHue = hue
    drawSat = sat
    drawVal = val

  addLayoutDrawLayer(ui.currentLayer, slot.nodeId, vg, bounds):
    let
      (cx, cy, r0, r1, x1, y1, x2, y2, x3, y3) = wheelGeometry(bounds)
      da = 0.5 / r1

    vg.strokeColor(black())
    vg.strokeWidth(1.0)
    vg.beginPath()
    vg.moveTo(x1, y1)
    vg.lineTo(x2, y2)
    vg.lineTo(x3, y3)
    vg.closePath()

    var paint = vg.linearGradient(x3, y3, x2, y2, hsla(drawHue, 1.0, 0.5, 1.0), white())
    vg.fillPaint(paint)
    vg.fill()

    paint = vg.linearGradient(
      x1, y1, x3 + (x2 - x3) * 0.5, y3 + (y2 - y3) * 0.5, black(), black(0)
    )
    vg.fillPaint(paint)
    vg.fill()

    let
      markerBlack = 1.0 - drawVal
      markerColor = drawVal * drawSat
      markerWhite = drawVal * (1.0 - drawSat)
      markerX = x1 * markerBlack + x2 * markerWhite + x3 * markerColor
      markerY = y1 * markerBlack + y2 * markerWhite + y3 * markerColor

    vg.strokeWidth(1.0)
    vg.beginPath()
    vg.circle(markerX, markerY, 5)
    vg.strokeColor(black(0.8))
    vg.stroke()
    vg.beginPath()
    vg.circle(markerX, markerY, 4)
    vg.strokeColor(white(0.8))
    vg.stroke()

    const Segments = 6
    for i in 0 ..< Segments:
      let
        a0 = float(i) / Segments * 2 * PI - da
        a1 = (float(i) + 1.0) / Segments * 2 * PI + da

      vg.beginPath()
      vg.arc(cx, cy, r0, a0, a1, pwCW)
      vg.arc(cx, cy, r1, a1, a0, pwCCW)
      vg.closePath()

      let
        r = r0 + r1
        ax = cx + cos(a0) * r * 0.5
        ay = cy + sin(a0) * r * 0.5
        bx = cx + cos(a1) * r * 0.5
        by = cy + sin(a1) * r * 0.5
        paint = vg.linearGradient(
          ax,
          ay,
          bx,
          by,
          hsla(0.5 + a0 / (2 * PI), 1.0, 0.50, 1.00),
          hsla(0.5 + a1 / (2 * PI), 1.0, 0.50, 1.00),
        )
      vg.fillPaint(paint)
      vg.fill()

    vg.save()
    vg.translate(cx, cy)
    vg.rotate(PI + drawHue * 2 * PI)
    let hueMarkerX = (r0 + r1) * 0.5
    vg.strokeWidth(1.0)
    vg.beginPath()
    vg.circle(hueMarkerX, 0, 5)
    vg.strokeColor(black(0.8))
    vg.stroke()
    vg.beginPath()
    vg.circle(hueMarkerX, 0, 4)
    vg.strokeColor(white(0.8))
    vg.stroke()
    vg.restore()

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
