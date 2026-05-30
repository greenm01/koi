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

proc setLabelFont(style: LabelStyle, fontFace: string, fontSize: float) =
  if style != nil:
    style.fontFace = fontFace
    style.fontSize = fontSize

proc setButtonFont(style: ButtonStyle, fontFace: string, fontSize: float) =
  if style != nil:
    setLabelFont(style.label, fontFace, fontSize)

proc setSelectableFont(style: SelectableStyle, fontFace: string, fontSize: float) =
  if style != nil:
    setLabelFont(style.label, fontFace, fontSize)

proc setTextFieldFont(style: TextFieldStyle, fontFace: string, fontSize: float) =
  if style != nil:
    style.textFontFace = fontFace
    style.textFontSize = fontSize

proc setShadowCornerRadius(style: ShadowStyle, radius: float) =
  if style != nil:
    style.cornerRadius = radius

proc setPopupCornerRadius(style: PopupStyle, radius: float) =
  if style != nil:
    style.backgroundCornerRadius = radius
    setShadowCornerRadius(style.shadow, radius)

proc setButtonCornerRadius(style: ButtonStyle, radius: float) =
  if style != nil:
    style.cornerRadius = radius

proc setSelectableCornerRadius(style: SelectableStyle, radius: float) =
  if style != nil:
    style.cornerRadius = radius

proc setTextFieldCornerRadius(style: TextFieldStyle, radius: float) =
  if style != nil:
    style.bgCornerRadius = radius

proc setScrollBarCornerRadius(style: ScrollBarStyle, radius: float) =
  if style != nil:
    style.trackCornerRadius = radius
    style.thumbCornerRadius = radius

proc setButtonAccent(style: ButtonStyle, accent: Color) =
  if style != nil:
    style.fillColorDown = accent

proc setSelectableAccent(style: SelectableStyle, accent, accentLow: Color) =
  if style != nil:
    style.fillColorDown = accentLow
    style.fillColorActive = accent
    style.fillColorActiveHover = accent

proc setScrollBarAccent(style: ScrollBarStyle, accent: Color) =
  if style != nil:
    style.thumbFillColorDown = accent

proc defaultFont*(): tuple[fontFace: string, fontSize: float] =
  (DefaultLabelStyle.fontFace, DefaultLabelStyle.fontSize)

proc getDefaultFont*(): tuple[fontFace: string, fontSize: float] =
  defaultFont()

proc setDefaultFont*(fontFace: string, fontSize: float) =
  doAssert fontFace.len > 0
  doAssert fontSize > 0

  setLabelFont(DefaultLabelStyle, fontFace, fontSize)

  DefaultTooltipStyle.fontFace = fontFace
  DefaultTooltipStyle.fontSize = fontSize

  setButtonFont(DefaultButtonStyle, fontFace, fontSize)
  setSelectableFont(DefaultSelectableStyle, fontFace, fontSize)
  setLabelFont(DefaultToggleButtonStyle.label, fontFace, fontSize)
  setLabelFont(DefaultToggleButtonStyle.labelActive, fontFace, fontSize)
  setLabelFont(DefaultCheckBoxStyle.icon, fontFace, fontSize)
  setLabelFont(DefaultRadioButtonsStyle.label, fontFace, fontSize)

  setLabelFont(DefaultDropDownStyle.label, fontFace, fontSize)
  setLabelFont(DefaultDropDownStyle.item, fontFace, fontSize)
  setTextFieldFont(DefaultTextFieldStyle, fontFace, fontSize)
  DefaultTextAreaStyle.textFontFace = fontFace
  DefaultTextAreaStyle.textFontSize = fontSize

  setLabelFont(DefaultSliderStyle.label, fontFace, fontSize)
  setLabelFont(DefaultSliderStyle.value, fontFace, fontSize)
  setLabelFont(DefaultProgressStyle.label, fontFace, fontSize)

  setLabelFont(DefaultPropertyStyle.label, fontFace, fontSize)
  setButtonFont(DefaultPropertyStyle.button, fontFace, fontSize)
  setTextFieldFont(DefaultPropertyStyle.textField, fontFace, fontSize)

  setButtonFont(DefaultMenuStyle.button, fontFace, fontSize)
  setSelectableFont(DefaultMenuStyle.item, fontFace, fontSize)

  setLabelFont(DefaultSectionHeaderStyle.label, fontFace, fontSize)
  setLabelFont(DefaultSubSectionHeaderStyle.label, fontFace, fontSize)
  setLabelFont(DefaultChartStyle.label, fontFace, fontSize)
  setLabelFont(DefaultTableStyle.headerLabel, fontFace, fontSize)
  setLabelFont(DefaultTableStyle.rowLabel, fontFace, fontSize)
  setButtonFont(DefaultColorComboStyle.button, fontFace, fontSize)
  setLabelFont(DefaultColorComboStyle.label, fontFace, fontSize)
  setLabelFont(DefaultGroupBoxStyle.titleLabel, fontFace, fontSize)

proc defaultFont*(fontFace: string, fontSize: float) =
  setDefaultFont(fontFace, fontSize)

proc defaultCornerRadius*(): float =
  DefaultButtonStyle.cornerRadius

proc getDefaultCornerRadius*(): float =
  defaultCornerRadius()

proc setDefaultCornerRadius*(radius: float) =
  doAssert radius >= 0

  setShadowCornerRadius(DefaultShadowStyle, radius)
  setShadowCornerRadius(DefaultTooltipStyle.shadow, radius)
  DefaultTooltipStyle.cornerRadius = radius
  setPopupCornerRadius(DefaultPopupStyle, radius)

  setButtonCornerRadius(DefaultButtonStyle, radius)
  setSelectableCornerRadius(DefaultSelectableStyle, radius)
  DefaultToggleButtonStyle.cornerRadius = radius
  DefaultCheckBoxStyle.cornerRadius = radius
  DefaultRadioButtonsStyle.buttonCornerRadius = radius
  setScrollBarCornerRadius(DefaultScrollBarStyle, radius)

  DefaultDropDownStyle.buttonCornerRadius = radius
  DefaultDropDownStyle.itemListCornerRadius = radius
  setShadowCornerRadius(DefaultDropDownStyle.shadow, radius)
  setScrollBarCornerRadius(DefaultDropDownStyle.scrollBarStyle, radius)

  setTextFieldCornerRadius(DefaultTextFieldStyle, radius)
  DefaultTextAreaStyle.bgCornerRadius = radius
  setScrollBarCornerRadius(DefaultTextAreaStyle.scrollBarStyleNormal, radius)
  setScrollBarCornerRadius(DefaultTextAreaStyle.scrollBarStyleEdit, radius)

  DefaultSliderStyle.trackCornerRadius = radius
  DefaultSliderStyle.valueCornerRadius = radius
  DefaultProgressStyle.cornerRadius = radius
  setButtonCornerRadius(DefaultPropertyStyle.button, radius)
  setTextFieldCornerRadius(DefaultPropertyStyle.textField, radius)

  setButtonCornerRadius(DefaultMenuStyle.button, radius)
  setSelectableCornerRadius(DefaultMenuStyle.item, radius)
  setPopupCornerRadius(DefaultMenuStyle.popup, radius)

  DefaultGroupBoxStyle.cornerRadius = radius
  setScrollBarCornerRadius(DefaultScrollViewStyle.scrollBarStyle, radius)
  DefaultDialogStyle.cornerRadius = radius
  setShadowCornerRadius(DefaultDialogStyle.shadow, radius)

proc defaultCornerRadius*(radius: float) =
  setDefaultCornerRadius(radius)

proc defaultAccentColors*(): tuple[accent: Color, accentLow: Color] =
  (DefaultProgressStyle.valueColor, DefaultChartStyle.columnColor)

proc getDefaultAccentColors*(): tuple[accent: Color, accentLow: Color] =
  defaultAccentColors()

proc setDefaultAccentColors*(accent, accentLow: Color) =
  setButtonAccent(DefaultButtonStyle, accent)

  setSelectableAccent(DefaultSelectableStyle, accent, accentLow)
  DefaultToggleButtonStyle.fillColorDown = accentLow
  DefaultCheckBoxStyle.fillColorDown = accentLow
  DefaultRadioButtonsStyle.buttonFillColorDown = accentLow
  DefaultRadioButtonsStyle.buttonFillColorActive = accent
  DefaultRadioButtonsStyle.buttonFillColorActiveHover = accent
  setScrollBarAccent(DefaultScrollBarStyle, accent)

  DefaultDropDownStyle.itemBackgroundColorHover = accent
  setScrollBarAccent(DefaultDropDownStyle.scrollBarStyle, accent)

  DefaultTextFieldStyle.cursorColor = accent
  DefaultTextFieldStyle.selectionColor = accentLow.withAlpha(0.4)
  DefaultTextAreaStyle.cursorColor = accent
  DefaultTextAreaStyle.selectionColor = accentLow.withAlpha(0.4)
  setScrollBarAccent(DefaultTextAreaStyle.scrollBarStyleNormal, accent)
  setScrollBarAccent(DefaultTextAreaStyle.scrollBarStyleEdit, accent)

  DefaultProgressStyle.valueColor = accent
  setButtonAccent(DefaultPropertyStyle.button, accent)
  DefaultPropertyStyle.textField.cursorColor = accent
  DefaultPropertyStyle.textField.selectionColor = accentLow.withAlpha(0.4)

  DefaultMenuStyle.button.fillColorDown = accentLow
  DefaultMenuStyle.item.fillColorHover = accent
  DefaultMenuStyle.item.fillColorDown = accentLow
  setSelectableAccent(DefaultMenuStyle.item, accent, accentLow)

  DefaultChartStyle.lineColor = accent
  DefaultChartStyle.columnColor = accentLow
  setButtonAccent(DefaultColorComboStyle.button, accent)
  setScrollBarAccent(DefaultScrollViewStyle.scrollBarStyle, accent)

proc defaultAccentColors*(accent, accentLow: Color) =
  setDefaultAccentColors(accent, accentLow)
