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
