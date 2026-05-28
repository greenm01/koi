import nanovg
import koi/deps/with
import koi/types
import koi/core

# Default styles and their accessors

# Label
var DefaultLabelStyle = LabelStyle(
  fontSize: 14.0,
  fontFace: "sans-bold",
  vertAlignFactor: 0.55,
  padHoriz: 0.0,
  align: haLeft,
  multiLine: false,
  lineHeight: 1.4,
  color: gray(0.7),
  colorHover: gray(0.7),
  colorDown: gray(0.7),
  colorActive: white(),
  colorActiveHover: white(),
  colorDisabled: gray(0.7, 0.5),
)

proc getDefaultLabelStyle*(): LabelStyle =
  DefaultLabelStyle.deepCopy

proc setDefaultLabelStyle*(style: LabelStyle) =
  DefaultLabelStyle = style.deepCopy

# Shadow
var DefaultShadowStyle = ShadowStyle(
  enabled: true,
  cornerRadius: 8.0,
  xOffset: 1.0,
  yOffset: 1.0,
  widthOffset: 0.0,
  heightOffset: 0.0,
  feather: 8.0,
  color: black(0.4),
)

proc getDefaultShadowStyle*(): ShadowStyle =
  DefaultShadowStyle.deepCopy

proc setDefaultShadowStyle*(style: ShadowStyle) =
  DefaultShadowStyle = style.deepCopy

# Popup
var DefaultPopupStyle = PopupStyle(
  autoClose: true,
  autoCloseBorder: 40,
  backgroundCornerRadius: 5,
  backgroundStrokeWidth: 0,
  backgroundStrokeColor: black(),
  backgroundFillColor: gray(0.1),
  shadow: getDefaultShadowStyle(),
)

proc getDefaultPopupStyle*(): PopupStyle =
  DefaultPopupStyle.deepCopy

proc setDefaultPopupStyle*(style: PopupStyle) =
  DefaultPopupStyle = style.deepCopy

# Button
var DefaultButtonStyle = ButtonStyle(
  cornerRadius: 5.0,
  strokeWidth: 0.0,
  strokeColor: black(),
  strokeColorHover: black(),
  strokeColorDown: black(),
  strokeColorDisabled: black(),
  fillColor: gray(0.6),
  fillColorHover: gray(0.7),
  fillColorDown: HighlightColor,
  fillColorDisabled: gray(0.6).withAlpha(0.5),
  label: getDefaultLabelStyle(),
)

with DefaultButtonStyle.label:
  align = haCenter
  padHoriz = 8.0
  color = gray(0.25)
  colorHover = gray(0.25)
  colorDown = gray(0.25)
  colorDisabled = gray(0.25).withAlpha(0.7)

proc getDefaultButtonStyle*(): ButtonStyle =
  DefaultButtonStyle.deepCopy

proc setDefaultButtonStyle*(style: ButtonStyle) =
  DefaultButtonStyle = style.deepCopy

# ToggleButton
var DefaultToggleButtonStyle = ToggleButtonStyle(
  cornerRadius: 5.0,
  strokeWidth: 0.0,
  strokeColor: black(),
  strokeColorHover: black(),
  strokeColorDown: black(),
  strokeColorActive: black(),
  strokeColorActiveHover: black(),
  strokeColorDisabled: black(),
  fillColor: gray(0.6),
  fillColorHover: gray(0.7),
  fillColorDown: gray(0.35),
  fillColorActive: gray(0.25),
  fillColorActiveHover: gray(0.27),
  fillColorDisabled: gray(0.6).withAlpha(0.5),
  label: getDefaultLabelStyle(),
  labelActive: getDefaultLabelStyle(),
)

with DefaultToggleButtonStyle.label:
  align = haCenter
  padHoriz = 8.0
  color = gray(0.25)
  colorHover = gray(0.25)
  colorDown = gray(0.25)
  colorDisabled = gray(0.25).withAlpha(0.7)

with DefaultToggleButtonStyle.labelActive:
  align = haCenter
  padHoriz = 8.0
  color = gray(1.00)
  colorHover = gray(1.00)
  colorDown = gray(1.00)
  colorDisabled = gray(1.00).withAlpha(0.7)

proc getDefaultToggleButtonStyle*(): ToggleButtonStyle =
  DefaultToggleButtonStyle.deepCopy

proc setDefaultToggleButtonStyle*(style: ToggleButtonStyle) =
  DefaultToggleButtonStyle = style.deepCopy

# CheckBox
var DefaultCheckBoxStyle = CheckBoxStyle(
  cornerRadius: 5.0,
  strokeWidth: 0.0,
  strokeColor: black(),
  strokeColorHover: black(),
  strokeColorDown: black(),
  strokeColorActive: black(),
  strokeColorActiveHover: black(),
  strokeColorDisabled: black(),
  fillColor: gray(0.6),
  fillColorHover: gray(0.7),
  fillColorDown: gray(0.5),
  fillColorActive: gray(0.6),
  fillColorActiveHover: gray(0.7),
  fillColorDisabled: gray(0.23),
  icon: getDefaultLabelStyle(),
  iconActive: "",
  iconInactive: "",
)

with DefaultCheckBoxStyle.icon:
  align = haCenter
  color = gray(0.25)
  colorHover = gray(0.25)
  colorDown = gray(0.25)
  colorActive = gray(0.25)
  colorActiveHover = gray(0.25)

proc getDefaultCheckBoxStyle*(): CheckBoxStyle =
  DefaultCheckBoxStyle.deepCopy

proc setDefaultCheckBoxStyle*(style: CheckBoxStyle) =
  DefaultCheckBoxStyle = style.deepCopy

# RadioButtons
var DefaultRadioButtonsStyle = RadioButtonsStyle(
  buttonPadHoriz: 3.0,
  buttonPadVert: 3.0,
  buttonCornerRadius: 5.0,
  buttonStrokeWidth: 0.0,
  buttonStrokeColor: black(),
  buttonStrokeColorHover: black(),
  buttonStrokeColorDown: black(),
  buttonStrokeColorActive: black(),
  buttonStrokeColorActiveHover: black(),
  buttonFillColor: gray(0.6),
  buttonFillColorHover: gray(0.7),
  buttonFillColorDown: HighlightLowColor,
  buttonFillColorActive: HighlightColor,
  buttonFillColorActiveHover: HighlightColor,
  label: getDefaultLabelStyle(),
)

with DefaultRadioButtonsStyle.label:
  align = haCenter
  padHoriz = 8.0
  color = gray(0.25)
  colorHover = gray(0.25)
  colorDown = gray(0.25)
  colorActive = gray(0.25)
  colorActiveHover = gray(0.25)
  colorDisabled = gray(0.7)

proc getDefaultRadioButtonsStyle*(): RadioButtonsStyle =
  DefaultRadioButtonsStyle.deepCopy

proc setDefaultRadioButtonsStyle*(style: RadioButtonsStyle) =
  DefaultRadioButtonsStyle = style.deepCopy

# ScrollBar
var DefaultScrollBarStyle = ScrollBarStyle(
  trackCornerRadius: 5.0,
  trackStrokeWidth: 0.0,
  trackStrokeColor: black(),
  trackStrokeColorHover: black(),
  trackStrokeColorDown: black(),
  trackFillColor: gray(0.6),
  trackFillColorHover: gray(0.7),
  trackFillColorDown: gray(0.6),
  thumbCornerRadius: 5.0,
  thumbPad: 3.0,
  thumbMinSize: 10.0,
  thumbStrokeWidth: 0.0,
  thumbStrokeColor: black(),
  thumbStrokeColorHover: black(),
  thumbStrokeColorDown: black(),
  thumbFillColor: gray(0.25),
  thumbFillColorHover: gray(0.35),
  thumbFillColorDown: HighlightColor,
  autoFade: false,
  autoFadeStartAlpha: 0.5,
  autoFadeEndAlpha: 1.0,
  autoFadeDistance: 60.0,
)

proc getDefaultScrollBarStyle*(): ScrollBarStyle =
  DefaultScrollBarStyle.deepCopy

proc setDefaultScrollBarStyle*(style: ScrollBarStyle) =
  DefaultScrollBarStyle = style.deepCopy

# DropDown
var DefaultDropDownStyle = DropDownStyle(
  buttonCornerRadius: 5.0,
  buttonStrokeWidth: 0.0,
  buttonStrokeColor: black(),
  buttonStrokeColorHover: black(),
  buttonStrokeColorDown: black(),
  buttonStrokeColorDisabled: black(),
  buttonFillColor: gray(0.6),
  buttonFillColorHover: gray(0.7),
  buttonFillColorDown: gray(0.6),
  buttonFillColorDisabled: gray(0.23),
  label: getDefaultLabelStyle(),
  itemListAlign: haCenter,
  itemListPadHoriz: 7.0,
  itemListPadVert: 7.0,
  itemListCornerRadius: 5.0,
  itemListStrokeWidth: 0.0,
  itemListStrokeColor: black(),
  itemListFillColor: gray(0.25),
  item: getDefaultLabelStyle(),
  itemBackgroundColorHover: HighlightColor,
  shadow: getDefaultShadowStyle(),
  scrollBarWidth: 12.0,
)

with DefaultDropDownStyle:
  scrollBarStyle = getDefaultScrollBarStyle()
  with scrollBarStyle:
    trackCornerRadius = 3.0
    trackFillColor = black().withAlpha(0)
    trackFillColorHover = black().withAlpha(0)
    trackFillColorDown = black().withAlpha(0)
    thumbCornerRadius = 3.0
    thumbFillColor = white().withAlpha(0.4)
    thumbFillColorHover = white().withAlpha(0.43)
    thumbFillColorDown = white().withAlpha(0.35)

with DefaultDropDownStyle:
  label.padHoriz = 8.0
  label.color = gray(0.25)
  label.colorHover = gray(0.25)
  label.colorDown = gray(0.25) # TODO

  item.padHoriz = 0.0
  item.color = gray(0.7)
  item.colorHover = gray(0.25)

proc getDefaultDropDownStyle*(): DropDownStyle =
  DefaultDropDownStyle.deepCopy

proc setDefaultDropDownStyle*(style: DropDownStyle) =
  DefaultDropDownStyle = style.deepCopy

# TextField
var DefaultTextFieldStyle = TextFieldStyle(
  bgCornerRadius: 5.0,
  bgStrokeWidth: 0.0, # TODO
  bgStrokeColor: black(),
  bgStrokeColorHover: black(),
  bgStrokeColorActive: black(),
  bgStrokeColorDisabled: black(),
  bgFillColor: gray(0.6),
  bgFillColorHover: gray(0.7),
  bgFillColorActive: gray(0.25),
  bgFillColorDisabled: gray(0.23),

  # TODO use labelstyle?
  textPadHoriz: 8.0,
  textPadVert: 2.0,
  textFontSize: 14.0,
  textFontFace: "sans-bold",
  textColor: gray(0.25),
  textColorHover: gray(0.25), # TODO
  textColorActive: gray(0.7),
  textColorDisabled: gray(0.7, 0.5),
  cursorColor: rgb(255, 190, 0),
  cursorWidth: 1.0,
  selectionColor: rgba(200, 130, 0, 100),
)

proc getDefaultTextFieldStyle*(): TextFieldStyle =
  DefaultTextFieldStyle.deepCopy

proc setDefaultTextFieldStyle*(style: TextFieldStyle) =
  DefaultTextFieldStyle = style.deepCopy

# TextArea
var DefaultTextAreaStyle = TextAreaStyle(
  bgCornerRadius: 5.0,
  bgStrokeWidth: 0.0,
  bgStrokeColor: black(),
  bgStrokeColorHover: black(),
  bgStrokeColorActive: black(),
  bgStrokeColorDisabled: black(),
  bgFillColor: gray(0.6),
  bgFillColorHover: gray(0.7),
  bgFillColorActive: gray(0.25),
  bgFillColorDisabled: gray(0.23),

  # TODO use labelStyle?
  textPadHoriz: 8.0,
  textPadVert: 2.0,
  textFontSize: 14.0,
  textFontFace: "sans-bold",
  textLineHeight: 1.4,
  textColor: gray(0.25),
  textColorHover: gray(0.25),
  textColorActive: gray(0.7),
  textColorDisabled: gray(0.7, 0.5),
  cursorColor: rgb(255, 190, 0),
  cursorWidth: 1.0,
  selectionColor: rgba(200, 130, 0, 100),
  scrollBarWidth: 12.0,
)

with DefaultTextAreaStyle:
  scrollBarStyleNormal = getDefaultScrollBarStyle()
  with scrollBarStyleNormal:
    trackCornerRadius = 3.0
    trackFillColor = gray(0, 0)
    trackFillColorHover = gray(0, 0)
    trackFillColorDown = gray(0, 0)
    thumbCornerRadius = 3.0
    thumbFillColor = gray(0, 0.4)
    thumbFillColorHover = gray(0, 0.43)
    thumbFillColorDown = gray(0, 0.35)

  scrollBarStyleEdit = scrollBarStyleNormal.deepCopy
  with scrollBarStyleEdit:
    thumbFillColor = white().withAlpha(0.4)
    thumbFillColorHover = white().withAlpha(0.43)
    thumbFillColorDown = white().withAlpha(0.35)

proc getDefaultTextAreaStyle*(): TextAreaStyle =
  DefaultTextAreaStyle.deepCopy

proc setDefaultTextAreaStyle*(style: TextAreaStyle) =
  DefaultTextAreaStyle = style.deepCopy

# Slider
var DefaultSliderStyle = SliderStyle(
  trackCornerRadius: 10.0,
  trackPad: 3.0,
  trackStrokeWidth: 0.0,
  trackStrokeColor: black(),
  trackStrokeColorHover: black(),
  trackStrokeColorDown: black(),
  trackFillColor: gray(0.6),
  trackFillColorHover: gray(0.7),
  trackFillColorDown: gray(0.6),
  valuePrecision: 3,
  valueSuffix: "",
  valueCornerRadius: 8.0,
  sliderColor: gray(0.25),
  sliderColorHover: gray(0.25),
  sliderColorDown: gray(0.25),
  label: getDefaultLabelStyle(),
  value: getDefaultLabelStyle(),
  cursorFollowsValue: true,
)

with DefaultSliderStyle:
  label.padHoriz = 8.0
  label.align = haLeft
  label.color = white()
  label.colorHover = white()
  label.colorDown = white()

  label.padHoriz = 8.0
  value.align = haCenter
  value.color = white()
  value.colorHover = white()
  value.colorDown = white()

proc getDefaultSliderStyle*(): SliderStyle =
  DefaultSliderStyle.deepCopy

proc setDefaultSliderStyle*(style: SliderStyle) =
  DefaultSliderStyle = style.deepCopy

# SectionHeader
var DefaultSectionHeaderStyle = SectionHeaderStyle(
  label: getDefaultLabelStyle(),
  labelLeftPad: 28.0,
  height: 32.0,
  hitRightPad: 13.0,
  backgroundColor: gray(0.15),
  separatorColor: gray(0.3),
  triangleSize: 4.0,
  triangleLeftPad: 11.0,
  triangleColor: gray(0.65),
)

with DefaultSectionHeaderStyle.label:
  color = gray(0.8)

proc getDefaultSectionHeaderStyle*(): SectionHeaderStyle =
  DefaultSectionHeaderStyle.deepCopy

proc setDefaultSectionHeaderStyle*(style: SectionHeaderStyle) =
  DefaultSectionHeaderStyle = style.deepCopy

# SubSectionHeader
var DefaultSubSectionHeaderStyle = SectionHeaderStyle(
  label: getDefaultLabelStyle(),
  labelLeftPad: 38.0,
  height: 25.0,
  hitRightPad: 13.0,
  backgroundColor: gray(0.25),
  separatorColor: gray(0.3),
  triangleSize: 3.0,
  triangleLeftPad: 21.0,
  triangleColor: white(),
)

with DefaultSubSectionHeaderStyle.label:
  color = gray(0.9)

proc getDefaultSubSectionHeaderStyle*(): SectionHeaderStyle =
  DefaultSubSectionHeaderStyle.deepCopy

proc setDefaultSubSectionHeaderStyle*(style: SectionHeaderStyle) =
  DefaultSubSectionHeaderStyle = style.deepCopy

# ScrollView
var DefaultScrollViewStyle = ScrollViewStyle(
  vertScrollBarWidth: 12.0, scrollWheelSensitivity: if defined(macosx): 10.0 else: 40.0
)

DefaultScrollViewStyle.scrollBarStyle = getDefaultScrollBarStyle()

with DefaultScrollViewStyle.scrollBarStyle:
  trackCornerRadius = 6.0
  trackFillColor = gray(0, 0)
  trackFillColorHover = gray(0, 0.15)
  trackFillColorDown = gray(0, 0.15)
  thumbCornerRadius = 3.0
  thumbFillColor = gray(0.52)
  thumbFillColorHover = gray(0.55)
  thumbFillColorDown = gray(0.50)
  autoFade = true
  autoFadeStartAlpha = 0.3
  autoFadeEndAlpha = 1.0
  autoFadeDistance = 60.0

proc getDefaultScrollViewStyle*(): ScrollViewStyle =
  DefaultScrollViewStyle.deepCopy

proc setDefaultScrollViewStyle*(style: ScrollViewStyle) =
  DefaultScrollViewStyle = style.deepCopy

# Dialog
var DefaultDialogStyle = DialogStyle(
  cornerRadius: 7.0,
  backgroundColor: gray(0.2),
  drawTitleBar: true,
  titleBarBgColor: gray(0.05),
  titleBarTextColor: gray(0.85),
  outerBorderColor: black(),
  innerBorderColor: white(),
  outerBorderWidth: 0.0,
  innerBorderWidth: 0.0,
)

DefaultDialogStyle.shadow = ShadowStyle(
  enabled: true,
  cornerRadius: 12.0,
  xOffset: 2.0,
  yOffset: 3.0,
  widthOffset: 0.0,
  heightOffset: 0.0,
  feather: 25.0,
  color: black(0.4),
)

proc getDefaultDialogStyle*(): DialogStyle =
  DefaultDialogStyle.deepCopy

proc setDefaultDialogStyle*(style: DialogStyle) =
  DefaultDialogStyle = style.deepCopy

# AutoLayout
const DefaultAutoLayoutParams* = AutoLayoutParams(
  itemsPerRow: 2,
  rowWidth: 320.0,
  labelWidth: 175.0,
  sectionPad: 12.0,
  leftPad: 13.0,
  rightPad: 4.0,
  rowPad: 5.0,
  rowGroupPad: 16.0,
  defaultRowHeight: 21.0,
  defaultItemHeight: 21.0,
)
