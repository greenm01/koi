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

proc defaultLabelStyle*(): LabelStyle =
  DefaultLabelStyle.deepCopy

proc borrowDefaultLabelStyle*(): LabelStyle =
  DefaultLabelStyle

proc getDefaultLabelStyle*(): LabelStyle =
  defaultLabelStyle()

proc defaultLabelStyle*(style: LabelStyle) =
  DefaultLabelStyle = style.deepCopy

proc setDefaultLabelStyle*(style: LabelStyle) =
  defaultLabelStyle(style)

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

proc defaultShadowStyle*(): ShadowStyle =
  DefaultShadowStyle.deepCopy

proc borrowDefaultShadowStyle*(): ShadowStyle =
  DefaultShadowStyle

proc getDefaultShadowStyle*(): ShadowStyle =
  defaultShadowStyle()

proc defaultShadowStyle*(style: ShadowStyle) =
  DefaultShadowStyle = style.deepCopy

proc setDefaultShadowStyle*(style: ShadowStyle) =
  defaultShadowStyle(style)

# Popup
var DefaultPopupStyle = PopupStyle(
  autoClose: true,
  autoCloseBorder: 40,
  backgroundCornerRadius: 5,
  backgroundStrokeWidth: 0,
  backgroundStrokeColor: black(),
  backgroundFillColor: gray(0.1),
  shadow: defaultShadowStyle(),
)

proc defaultPopupStyle*(): PopupStyle =
  DefaultPopupStyle.deepCopy

proc borrowDefaultPopupStyle*(): PopupStyle =
  DefaultPopupStyle

proc getDefaultPopupStyle*(): PopupStyle =
  defaultPopupStyle()

proc defaultPopupStyle*(style: PopupStyle) =
  DefaultPopupStyle = style.deepCopy

proc setDefaultPopupStyle*(style: PopupStyle) =
  defaultPopupStyle(style)

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
  label: defaultLabelStyle(),
)

with DefaultButtonStyle.label:
  align = haCenter
  padHoriz = 8.0
  color = gray(0.25)
  colorHover = gray(0.25)
  colorDown = gray(0.25)
  colorDisabled = gray(0.25).withAlpha(0.7)

proc defaultButtonStyle*(): ButtonStyle =
  DefaultButtonStyle.deepCopy

proc borrowDefaultButtonStyle*(): ButtonStyle =
  DefaultButtonStyle

proc getDefaultButtonStyle*(): ButtonStyle =
  defaultButtonStyle()

proc defaultButtonStyle*(style: ButtonStyle) =
  DefaultButtonStyle = style.deepCopy

proc setDefaultButtonStyle*(style: ButtonStyle) =
  defaultButtonStyle(style)

# Selectable
var DefaultSelectableStyle = SelectableStyle(
  cornerRadius: 4.0,
  strokeWidth: 0.0,
  strokeColor: black(),
  strokeColorHover: black(),
  strokeColorDown: black(),
  strokeColorActive: black(),
  strokeColorActiveHover: black(),
  strokeColorDisabled: black(),
  fillColor: gray(0, 0),
  fillColorHover: gray(0.7),
  fillColorDown: HighlightLowColor,
  fillColorActive: HighlightColor,
  fillColorActiveHover: HighlightColor,
  fillColorDisabled: gray(0.23),
  label: defaultLabelStyle(),
)

with DefaultSelectableStyle.label:
  padHoriz = 8.0
  color = gray(0.7)
  colorHover = gray(0.25)
  colorDown = gray(0.25)
  colorActive = gray(0.25)
  colorActiveHover = gray(0.25)
  colorDisabled = gray(0.7, 0.5)

proc defaultSelectableStyle*(): SelectableStyle =
  DefaultSelectableStyle.deepCopy

proc borrowDefaultSelectableStyle*(): SelectableStyle =
  DefaultSelectableStyle

proc getDefaultSelectableStyle*(): SelectableStyle =
  defaultSelectableStyle()

proc defaultSelectableStyle*(style: SelectableStyle) =
  DefaultSelectableStyle = style.deepCopy

proc setDefaultSelectableStyle*(style: SelectableStyle) =
  defaultSelectableStyle(style)

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
  label: defaultLabelStyle(),
  labelActive: defaultLabelStyle(),
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

proc defaultToggleButtonStyle*(): ToggleButtonStyle =
  DefaultToggleButtonStyle.deepCopy

proc borrowDefaultToggleButtonStyle*(): ToggleButtonStyle =
  DefaultToggleButtonStyle

proc getDefaultToggleButtonStyle*(): ToggleButtonStyle =
  defaultToggleButtonStyle()

proc defaultToggleButtonStyle*(style: ToggleButtonStyle) =
  DefaultToggleButtonStyle = style.deepCopy

proc setDefaultToggleButtonStyle*(style: ToggleButtonStyle) =
  defaultToggleButtonStyle(style)

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
  icon: defaultLabelStyle(),
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

proc defaultCheckBoxStyle*(): CheckBoxStyle =
  DefaultCheckBoxStyle.deepCopy

proc borrowDefaultCheckBoxStyle*(): CheckBoxStyle =
  DefaultCheckBoxStyle

proc getDefaultCheckBoxStyle*(): CheckBoxStyle =
  defaultCheckBoxStyle()

proc defaultCheckBoxStyle*(style: CheckBoxStyle) =
  DefaultCheckBoxStyle = style.deepCopy

proc setDefaultCheckBoxStyle*(style: CheckBoxStyle) =
  defaultCheckBoxStyle(style)

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
  label: defaultLabelStyle(),
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

proc defaultRadioButtonsStyle*(): RadioButtonsStyle =
  DefaultRadioButtonsStyle.deepCopy

proc borrowDefaultRadioButtonsStyle*(): RadioButtonsStyle =
  DefaultRadioButtonsStyle

proc getDefaultRadioButtonsStyle*(): RadioButtonsStyle =
  defaultRadioButtonsStyle()

proc defaultRadioButtonsStyle*(style: RadioButtonsStyle) =
  DefaultRadioButtonsStyle = style.deepCopy

proc setDefaultRadioButtonsStyle*(style: RadioButtonsStyle) =
  defaultRadioButtonsStyle(style)

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

proc defaultScrollBarStyle*(): ScrollBarStyle =
  DefaultScrollBarStyle.deepCopy

proc borrowDefaultScrollBarStyle*(): ScrollBarStyle =
  DefaultScrollBarStyle

proc getDefaultScrollBarStyle*(): ScrollBarStyle =
  defaultScrollBarStyle()

proc defaultScrollBarStyle*(style: ScrollBarStyle) =
  DefaultScrollBarStyle = style.deepCopy

proc setDefaultScrollBarStyle*(style: ScrollBarStyle) =
  defaultScrollBarStyle(style)

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
  label: defaultLabelStyle(),
  itemListAlign: haCenter,
  itemListPadHoriz: 7.0,
  itemListPadVert: 7.0,
  itemListCornerRadius: 5.0,
  itemListStrokeWidth: 0.0,
  itemListStrokeColor: black(),
  itemListFillColor: gray(0.25),
  item: defaultLabelStyle(),
  itemBackgroundColorHover: HighlightColor,
  shadow: defaultShadowStyle(),
  scrollBarWidth: 12.0,
)

with DefaultDropDownStyle:
  scrollBarStyle = defaultScrollBarStyle()
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

proc defaultDropDownStyle*(): DropDownStyle =
  DefaultDropDownStyle.deepCopy

proc borrowDefaultDropDownStyle*(): DropDownStyle =
  DefaultDropDownStyle

proc getDefaultDropDownStyle*(): DropDownStyle =
  defaultDropDownStyle()

proc defaultDropDownStyle*(style: DropDownStyle) =
  DefaultDropDownStyle = style.deepCopy

proc setDefaultDropDownStyle*(style: DropDownStyle) =
  defaultDropDownStyle(style)

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

proc defaultTextFieldStyle*(): TextFieldStyle =
  DefaultTextFieldStyle.deepCopy

proc borrowDefaultTextFieldStyle*(): TextFieldStyle =
  DefaultTextFieldStyle

proc getDefaultTextFieldStyle*(): TextFieldStyle =
  defaultTextFieldStyle()

proc defaultTextFieldStyle*(style: TextFieldStyle) =
  DefaultTextFieldStyle = style.deepCopy

proc setDefaultTextFieldStyle*(style: TextFieldStyle) =
  defaultTextFieldStyle(style)

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
  scrollBarStyleNormal = defaultScrollBarStyle()
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

proc defaultTextAreaStyle*(): TextAreaStyle =
  DefaultTextAreaStyle.deepCopy

proc borrowDefaultTextAreaStyle*(): TextAreaStyle =
  DefaultTextAreaStyle

proc getDefaultTextAreaStyle*(): TextAreaStyle =
  defaultTextAreaStyle()

proc defaultTextAreaStyle*(style: TextAreaStyle) =
  DefaultTextAreaStyle = style.deepCopy

proc setDefaultTextAreaStyle*(style: TextAreaStyle) =
  defaultTextAreaStyle(style)

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
  label: defaultLabelStyle(),
  value: defaultLabelStyle(),
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

proc defaultSliderStyle*(): SliderStyle =
  DefaultSliderStyle.deepCopy

proc borrowDefaultSliderStyle*(): SliderStyle =
  DefaultSliderStyle

proc getDefaultSliderStyle*(): SliderStyle =
  defaultSliderStyle()

proc defaultSliderStyle*(style: SliderStyle) =
  DefaultSliderStyle = style.deepCopy

proc setDefaultSliderStyle*(style: SliderStyle) =
  defaultSliderStyle(style)

# Progress
var DefaultProgressStyle = ProgressStyle(
  cornerRadius: 5.0,
  strokeWidth: 0.0,
  strokeColor: black(),
  fillColor: gray(0.6),
  valueColor: HighlightColor,
  label: defaultLabelStyle(),
)

with DefaultProgressStyle.label:
  align = haCenter
  padHoriz = 8.0
  color = gray(0.25)

proc defaultProgressStyle*(): ProgressStyle =
  DefaultProgressStyle.deepCopy

proc borrowDefaultProgressStyle*(): ProgressStyle =
  DefaultProgressStyle

proc getDefaultProgressStyle*(): ProgressStyle =
  defaultProgressStyle()

proc defaultProgressStyle*(style: ProgressStyle) =
  DefaultProgressStyle = style.deepCopy

proc setDefaultProgressStyle*(style: ProgressStyle) =
  defaultProgressStyle(style)

# Property
var DefaultPropertyStyle = PropertyStyle(
  labelWidth: 110.0,
  buttonWidth: 24.0,
  gap: 4.0,
  valuePrecision: 3,
  label: defaultLabelStyle(),
  button: defaultButtonStyle(),
  textField: defaultTextFieldStyle(),
)

with DefaultPropertyStyle.label:
  padHoriz = 0.0
  color = gray(0.8)

proc defaultPropertyStyle*(): PropertyStyle =
  DefaultPropertyStyle.deepCopy

proc borrowDefaultPropertyStyle*(): PropertyStyle =
  DefaultPropertyStyle

proc getDefaultPropertyStyle*(): PropertyStyle =
  defaultPropertyStyle()

proc defaultPropertyStyle*(style: PropertyStyle) =
  DefaultPropertyStyle = style.deepCopy

proc setDefaultPropertyStyle*(style: PropertyStyle) =
  defaultPropertyStyle(style)

# Menu
var DefaultMenuStyle = MenuStyle(
  menuBarHeight: 24.0,
  menuButtonWidth: 86.0,
  menuItemHeight: 22.0,
  popupWidth: 180.0,
  popupPad: 4.0,
  barFillColor: gray(0.18),
  button: defaultButtonStyle(),
  item: defaultSelectableStyle(),
  popup: defaultPopupStyle(),
)

with DefaultMenuStyle.button:
  cornerRadius = 0.0
  fillColor = gray(0, 0)
  fillColorHover = gray(0.32)
  fillColorDown = HighlightLowColor
  label.color = gray(0.85)
  label.colorHover = white()
  label.colorDown = gray(0.25)

with DefaultMenuStyle.item:
  cornerRadius = 3.0
  fillColor = gray(0, 0)
  fillColorHover = HighlightColor
  fillColorDown = HighlightLowColor
  label.align = haLeft
  label.color = gray(0.85)
  label.colorHover = gray(0.25)
  label.colorDown = gray(0.25)

proc defaultMenuStyle*(): MenuStyle =
  DefaultMenuStyle.deepCopy

proc borrowDefaultMenuStyle*(): MenuStyle =
  DefaultMenuStyle

proc getDefaultMenuStyle*(): MenuStyle =
  defaultMenuStyle()

proc defaultMenuStyle*(style: MenuStyle) =
  DefaultMenuStyle = style.deepCopy

proc setDefaultMenuStyle*(style: MenuStyle) =
  defaultMenuStyle(style)

# SectionHeader
var DefaultSectionHeaderStyle = SectionHeaderStyle(
  label: defaultLabelStyle(),
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

proc defaultSectionHeaderStyle*(): SectionHeaderStyle =
  DefaultSectionHeaderStyle.deepCopy

proc borrowDefaultSectionHeaderStyle*(): SectionHeaderStyle =
  DefaultSectionHeaderStyle

proc getDefaultSectionHeaderStyle*(): SectionHeaderStyle =
  defaultSectionHeaderStyle()

proc defaultSectionHeaderStyle*(style: SectionHeaderStyle) =
  DefaultSectionHeaderStyle = style.deepCopy

proc setDefaultSectionHeaderStyle*(style: SectionHeaderStyle) =
  defaultSectionHeaderStyle(style)

# SubSectionHeader
var DefaultSubSectionHeaderStyle = SectionHeaderStyle(
  label: defaultLabelStyle(),
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

proc defaultSubSectionHeaderStyle*(): SectionHeaderStyle =
  DefaultSubSectionHeaderStyle.deepCopy

proc borrowDefaultSubSectionHeaderStyle*(): SectionHeaderStyle =
  DefaultSubSectionHeaderStyle

proc getDefaultSubSectionHeaderStyle*(): SectionHeaderStyle =
  defaultSubSectionHeaderStyle()

proc defaultSubSectionHeaderStyle*(style: SectionHeaderStyle) =
  DefaultSubSectionHeaderStyle = style.deepCopy

proc setDefaultSubSectionHeaderStyle*(style: SectionHeaderStyle) =
  defaultSubSectionHeaderStyle(style)

# Chart
var DefaultChartStyle = ChartStyle(
  backgroundColor: gray(0.12),
  strokeColor: gray(0.32),
  lineColor: HighlightColor,
  columnColor: HighlightLowColor,
  zeroLineColor: gray(0.45),
  strokeWidth: 1.0,
  lineWidth: 2.0,
  columnGap: 2.0,
  label: defaultLabelStyle(),
)

with DefaultChartStyle.label:
  align = haCenter
  color = gray(0.8)

proc defaultChartStyle*(): ChartStyle =
  DefaultChartStyle.deepCopy

proc borrowDefaultChartStyle*(): ChartStyle =
  DefaultChartStyle

proc getDefaultChartStyle*(): ChartStyle =
  defaultChartStyle()

proc defaultChartStyle*(style: ChartStyle) =
  DefaultChartStyle = style.deepCopy

proc setDefaultChartStyle*(style: ChartStyle) =
  defaultChartStyle(style)

# Table
var DefaultTableStyle = TableStyle(
  headerHeight: 24.0,
  rowHeight: 22.0,
  headerFillColor: gray(0.22),
  rowFillColor: gray(0.14),
  rowAltFillColor: gray(0.17),
  rowHoverFillColor: gray(0.25),
  strokeColor: gray(0.32),
  strokeWidth: 1.0,
  headerLabel: defaultLabelStyle(),
  rowLabel: defaultLabelStyle(),
)

with DefaultTableStyle.headerLabel:
  align = haLeft
  padHoriz = 6.0
  color = gray(0.9)

with DefaultTableStyle.rowLabel:
  align = haLeft
  padHoriz = 6.0
  color = gray(0.82)

proc defaultTableStyle*(): TableStyle =
  DefaultTableStyle.deepCopy

proc borrowDefaultTableStyle*(): TableStyle =
  DefaultTableStyle

proc getDefaultTableStyle*(): TableStyle =
  defaultTableStyle()

proc defaultTableStyle*(style: TableStyle) =
  DefaultTableStyle = style.deepCopy

proc setDefaultTableStyle*(style: TableStyle) =
  defaultTableStyle(style)

# ColorCombo
var DefaultColorComboStyle = ColorComboStyle(
  popupWidth: 176.0,
  popupHeight: 88.0,
  popupPad: 6.0,
  swatchSize: 22.0,
  swatchGap: 4.0,
  button: defaultButtonStyle(),
  popup: defaultPopupStyle(),
  label: defaultLabelStyle(),
)

with DefaultColorComboStyle.label:
  align = haLeft
  padHoriz = 6.0
  color = gray(0.9)

proc defaultColorComboStyle*(): ColorComboStyle =
  DefaultColorComboStyle.deepCopy

proc borrowDefaultColorComboStyle*(): ColorComboStyle =
  DefaultColorComboStyle

proc getDefaultColorComboStyle*(): ColorComboStyle =
  defaultColorComboStyle()

proc defaultColorComboStyle*(style: ColorComboStyle) =
  DefaultColorComboStyle = style.deepCopy

proc setDefaultColorComboStyle*(style: ColorComboStyle) =
  defaultColorComboStyle(style)

# GroupBox
var DefaultGroupBoxStyle = GroupBoxStyle(
  titleHeight: 24.0,
  pad: 6.0,
  cornerRadius: 5.0,
  strokeWidth: 1.0,
  strokeColor: gray(0.32),
  fillColor: gray(0.12),
  titleFillColor: gray(0.18),
  titleLabel: defaultLabelStyle(),
)

with DefaultGroupBoxStyle.titleLabel:
  align = haLeft
  padHoriz = 8.0
  color = gray(0.9)

proc defaultGroupBoxStyle*(): GroupBoxStyle =
  DefaultGroupBoxStyle.deepCopy

proc borrowDefaultGroupBoxStyle*(): GroupBoxStyle =
  DefaultGroupBoxStyle

proc getDefaultGroupBoxStyle*(): GroupBoxStyle =
  defaultGroupBoxStyle()

proc defaultGroupBoxStyle*(style: GroupBoxStyle) =
  DefaultGroupBoxStyle = style.deepCopy

proc setDefaultGroupBoxStyle*(style: GroupBoxStyle) =
  defaultGroupBoxStyle(style)

# ScrollView
var DefaultScrollViewStyle = ScrollViewStyle(
  vertScrollBarWidth: 12.0,
  horizScrollBarHeight: 12.0,
  scrollWheelSensitivity: if defined(macosx): 10.0 else: 40.0,
)

DefaultScrollViewStyle.scrollBarStyle = defaultScrollBarStyle()

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

proc defaultScrollViewStyle*(): ScrollViewStyle =
  DefaultScrollViewStyle.deepCopy

proc borrowDefaultScrollViewStyle*(): ScrollViewStyle =
  DefaultScrollViewStyle

proc getDefaultScrollViewStyle*(): ScrollViewStyle =
  defaultScrollViewStyle()

proc defaultScrollViewStyle*(style: ScrollViewStyle) =
  DefaultScrollViewStyle = style.deepCopy

proc setDefaultScrollViewStyle*(style: ScrollViewStyle) =
  defaultScrollViewStyle(style)

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

proc defaultDialogStyle*(): DialogStyle =
  DefaultDialogStyle.deepCopy

proc borrowDefaultDialogStyle*(): DialogStyle =
  DefaultDialogStyle

proc getDefaultDialogStyle*(): DialogStyle =
  defaultDialogStyle()

proc defaultDialogStyle*(style: DialogStyle) =
  DefaultDialogStyle = style.deepCopy

proc setDefaultDialogStyle*(style: DialogStyle) =
  defaultDialogStyle(style)

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
