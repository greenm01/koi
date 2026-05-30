# Style Types

type ShadowStyle* = ref object
  enabled*: bool
  cornerRadius*: float
  xOffset*: float
  yOffset*: float
  widthOffset*: float
  heightOffset*: float
  feather*: float
  color*: Color

type TooltipStyle* = ref object
  fontSize*: float
  fontFace*: string
  lineHeight*: float
  padX*: float
  padY*: float
  maxWidth*: float
  cornerRadius*: float
  backgroundColor*: Color
  textColor*: Color
  shadow*: ShadowStyle

type LabelStyle* = ref object
  fontSize*: float
  fontFace*: string
  vertAlignFactor*: float
  padHoriz*: float
  align*: HorizontalAlign
  multiLine*: bool
  lineHeight*: float
  color*: Color
  colorHover*: Color
  colorDown*: Color
  colorActive*: Color
  colorActiveHover*: Color
  colorDisabled*: Color

type PopupStyle* = ref object
  autoClose*: bool
  autoCloseBorder*: float
  backgroundCornerRadius*: float
  backgroundStrokeWidth*: float
  backgroundStrokeColor*: Color
  backgroundFillColor*: Color
  shadow*: ShadowStyle

type ButtonStyle* = ref object
  cornerRadius*: float
  strokeWidth*: float
  strokeColor*: Color
  strokeColorHover*: Color
  strokeColorDown*: Color
  strokeColorDisabled*: Color
  fillColor*: Color
  fillColorHover*: Color
  fillColorDown*: Color
  fillColorDisabled*: Color
  label*: LabelStyle

type SelectableStyle* = ref object
  cornerRadius*: float
  strokeWidth*: float
  strokeColor*: Color
  strokeColorHover*: Color
  strokeColorDown*: Color
  strokeColorActive*: Color
  strokeColorActiveHover*: Color
  strokeColorDisabled*: Color
  fillColor*: Color
  fillColorHover*: Color
  fillColorDown*: Color
  fillColorActive*: Color
  fillColorActiveHover*: Color
  fillColorDisabled*: Color
  label*: LabelStyle

type ToggleButtonStyle* = ref object
  cornerRadius*: float
  strokeWidth*: float
  strokeColor*: Color
  strokeColorHover*: Color
  strokeColorDown*: Color
  strokeColorActive*: Color
  strokeColorActiveHover*: Color
  strokeColorDisabled*: Color
  fillColor*: Color
  fillColorHover*: Color
  fillColorDown*: Color
  fillColorActive*: Color
  fillColorActiveHover*: Color
  fillColorDisabled*: Color
  label*: LabelStyle
  labelActive*: LabelStyle

type CheckBoxStyle* = ref object
  cornerRadius*: float
  strokeWidth*: float
  strokeColor*: Color
  strokeColorHover*: Color
  strokeColorDown*: Color
  strokeColorActive*: Color
  strokeColorActiveHover*: Color
  strokeColorDisabled*: Color
  fillColor*: Color
  fillColorHover*: Color
  fillColorDown*: Color
  fillColorActive*: Color
  fillColorActiveHover*: Color
  fillColorDisabled*: Color
  icon*: LabelStyle
  iconActive*: string
  iconInactive*: string

type
  RadioButtonsLayoutKind* = enum
    rblHoriz
    rblGridHoriz
    rblGridVert

  RadioButtonsLayout* = object
    case kind*: RadioButtonsLayoutKind
    of rblHoriz: discard
    of rblGridHoriz: itemsPerRow*: Natural
    of rblGridVert: itemsPerColumn*: Natural

type RadioButtonsStyle* = ref object
  buttonPadHoriz*: float
  buttonPadVert*: float
  buttonCornerRadius*: float
  buttonStrokeWidth*: float
  buttonStrokeColor*: Color
  buttonStrokeColorHover*: Color
  buttonStrokeColorDown*: Color
  buttonStrokeColorActive*: Color
  buttonStrokeColorActiveHover*: Color
  buttonFillColor*: Color
  buttonFillColorHover*: Color
  buttonFillColorDown*: Color
  buttonFillColorActive*: Color
  buttonFillColorActiveHover*: Color
  label*: LabelStyle

type ScrollBarStyle* = ref object
  trackCornerRadius*: float
  trackStrokeWidth*: float
  trackStrokeColor*: Color
  trackStrokeColorHover*: Color
  trackStrokeColorDown*: Color
  trackFillColor*: Color
  trackFillColorHover*: Color
  trackFillColorDown*: Color
  thumbCornerRadius*: float
  thumbPad*: float
  thumbMinSize*: float
  thumbStrokeWidth*: float
  thumbStrokeColor*: Color
  thumbStrokeColorHover*: Color
  thumbStrokeColorDown*: Color
  thumbFillColor*: Color
  thumbFillColorHover*: Color
  thumbFillColorDown*: Color
  autoFade*: bool
  autoFadeStartAlpha*: float
  autoFadeEndAlpha*: float
  autoFadeDistance*: float

type DropDownStyle* = ref object
  buttonCornerRadius*: float
  buttonStrokeWidth*: float
  buttonStrokeColor*: Color
  buttonStrokeColorHover*: Color
  buttonStrokeColorDown*: Color
  buttonStrokeColorDisabled*: Color
  buttonFillColor*: Color
  buttonFillColorHover*: Color
  buttonFillColorDown*: Color
  buttonFillColorDisabled*: Color
  label*: LabelStyle
  itemListAlign*: HorizontalAlign
  itemListPadHoriz*: float
  itemListPadVert*: float
  itemListCornerRadius*: float
  itemListStrokeWidth*: float
  itemListStrokeColor*: Color
  itemListFillColor*: Color
  item*: LabelStyle
  itemBackgroundColorHover*: Color
  shadow*: ShadowStyle
  scrollBarWidth*: float
  scrollBarStyle*: ScrollBarStyle

type
  TextFieldFilterKind* = enum
    tffAny
    tffInteger
    tffFloat
    tffHex
    tffBinary

  TextFieldConstraintKind* = enum
    tckString
    tckInteger

  TextFieldConstraint* = object
    case kind*: TextFieldConstraintKind
    of tckString:
      minLen*: Natural
      maxLen*: Option[Natural]
    of tckInteger:
      minInt*, maxInt*: int

type TextFieldStyle* = ref object
  bgCornerRadius*: float
  bgStrokeWidth*: float
  bgStrokeColor*: Color
  bgStrokeColorHover*: Color
  bgStrokeColorActive*: Color
  bgStrokeColorDisabled*: Color
  bgFillColor*: Color
  bgFillColorHover*: Color
  bgFillColorActive*: Color
  bgFillColorDisabled*: Color
  textPadHoriz*: float
  textPadVert*: float
  textFontSize*: float
  textFontFace*: string
  textColor*: Color
  textColorHover*: Color
  textColorActive*: Color
  textColorDisabled*: Color
  cursorWidth*: float
  cursorColor*: Color
  selectionColor*: Color

type TextAreaConstraint* = object
  maxLen*: Option[Natural]

type TextAreaStyle* = object
  bgCornerRadius*: float
  bgStrokeWidth*: float
  bgStrokeColor*: Color
  bgStrokeColorHover*: Color
  bgStrokeColorActive*: Color
  bgStrokeColorDisabled*: Color
  bgFillColor*: Color
  bgFillColorHover*: Color
  bgFillColorActive*: Color
  bgFillColorDisabled*: Color
  textPadHoriz*: float
  textPadVert*: float
  textFontSize*: float
  textFontFace*: string
  textLineHeight*: float
  textColor*: Color
  textColorHover*: Color
  textColorActive*: Color
  textColorDisabled*: Color
  cursorWidth*: float
  cursorColor*: Color
  selectionColor*: Color
  scrollBarWidth*: float
  scrollBarStyleNormal*: ScrollBarStyle
  scrollBarStyleEdit*: ScrollBarStyle

type SliderStyle* = ref object
  trackCornerRadius*: float
  trackPad*: float
  trackStrokeWidth*: float
  trackStrokeColor*: Color
  trackStrokeColorHover*: Color
  trackStrokeColorDown*: Color
  trackFillColor*: Color
  trackFillColorHover*: Color
  trackFillColorDown*: Color
  valuePrecision*: Natural
  valueSuffix*: string
  valueCornerRadius*: float
  sliderColor*: Color
  sliderColorHover*: Color
  sliderColorDown*: Color
  label*: LabelStyle
  value*: LabelStyle
  cursorFollowsValue*: bool
  commitOnPress*: bool

type ProgressStyle* = ref object
  cornerRadius*: float
  strokeWidth*: float
  strokeColor*: Color
  strokeColorDisabled*: Color
  fillColor*: Color
  fillColorDisabled*: Color
  valueColor*: Color
  valueColorDisabled*: Color
  label*: LabelStyle

type PropertyStyle* = ref object
  labelWidth*: float
  buttonWidth*: float
  gap*: float
  valuePrecision*: Natural
  label*: LabelStyle
  button*: ButtonStyle
  textField*: TextFieldStyle

type MenuStyle* = ref object
  menuBarHeight*: float
  menuButtonWidth*: float
  menuItemHeight*: float
  popupWidth*: float
  popupPad*: float
  barFillColor*: Color
  button*: ButtonStyle
  item*: SelectableStyle
  popup*: PopupStyle

type ChartKind* = enum
  ckLine
  ckColumns

type ChartSeries* = object
  label*: string
  values*: seq[float]
  kind*: ChartKind
  color*: Color

type ChartStyle* = ref object
  backgroundColor*: Color
  strokeColor*: Color
  lineColor*: Color
  columnColor*: Color
  zeroLineColor*: Color
  strokeWidth*: float
  lineWidth*: float
  columnGap*: float
  label*: LabelStyle

type TableSortDirection* = enum
  tsdNone
  tsdAsc
  tsdDesc

type TableSortState* = object
  column*: int
  direction*: TableSortDirection

type TableColumn* = object
  label*: string
  width*: float

type TableStyle* = ref object
  headerHeight*: float
  rowHeight*: float
  headerFillColor*: Color
  rowFillColor*: Color
  rowAltFillColor*: Color
  rowHoverFillColor*: Color
  strokeColor*: Color
  strokeWidth*: float
  headerLabel*: LabelStyle
  rowLabel*: LabelStyle

type ColorComboStyle* = ref object
  popupWidth*: float
  popupHeight*: float
  popupPad*: float
  swatchSize*: float
  swatchGap*: float
  presetColors*: seq[Color]
  button*: ButtonStyle
  popup*: PopupStyle
  label*: LabelStyle

type GroupBoxStyle* = ref object
  titleHeight*: float
  pad*: float
  cornerRadius*: float
  strokeWidth*: float
  strokeColor*: Color
  fillColor*: Color
  titleFillColor*: Color
  titleLabel*: LabelStyle

type SectionHeaderStyle* = ref object
  label*: LabelStyle
  labelLeftPad*: float
  height*: float
  hitRightPad*: float
  backgroundColor*: Color
  separatorColor*: Color
  triangleSize*: float
  triangleLeftPad*: float
  triangleColor*: Color

type ScrollViewStyle* = ref object
  vertScrollBarWidth*: float
  horizScrollBarHeight*: float
  scrollBarStyle*: ScrollBarStyle
  scrollWheelSensitivity*: float

type DialogStyle* = ref object
  cornerRadius*: float
  backgroundColor*: Color
  drawTitleBar*: bool
  titleBarBgColor*: Color
  titleBarTextColor*: Color
  outerBorderColor*: Color
  innerBorderColor*: Color
  outerBorderWidth*: float
  innerBorderWidth*: float
  shadow*: ShadowStyle
