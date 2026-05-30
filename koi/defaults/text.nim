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
  commitOnPress: false,
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
