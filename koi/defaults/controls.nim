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
