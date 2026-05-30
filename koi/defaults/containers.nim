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
