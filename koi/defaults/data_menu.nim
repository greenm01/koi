# Progress
var DefaultProgressStyle = ProgressStyle(
  cornerRadius: 5.0,
  strokeWidth: 0.0,
  strokeColor: black(),
  strokeColorDisabled: gray(0.45),
  fillColor: gray(0.6),
  fillColorDisabled: gray(0.5, 0.5),
  valueColor: HighlightColor,
  valueColorDisabled: gray(0.65, 0.65),
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
  presetColors:
    @[
      gray(0.0),
      gray(1.0),
      rgb(0.88, 0.18, 0.16),
      rgb(0.95, 0.63, 0.12),
      rgb(0.95, 0.86, 0.20),
      rgb(0.18, 0.62, 0.24),
      rgb(0.16, 0.45, 0.82),
      rgb(0.55, 0.22, 0.78),
      gray(0.0, 0.0),
    ],
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
