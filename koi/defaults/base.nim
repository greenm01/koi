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

# Tooltip
var DefaultTooltipStyle = TooltipStyle(
  fontSize: 14.0,
  fontFace: "sans-bold",
  lineHeight: 1.4,
  padX: 10.0,
  padY: 10.0,
  maxWidth: 300.0,
  cornerRadius: 5.0,
  backgroundColor: gray(0.1, 0.88),
  textColor: white(0.9),
  shadow: defaultShadowStyle(),
)

proc defaultTooltipStyle*(): TooltipStyle =
  DefaultTooltipStyle.deepCopy

proc borrowDefaultTooltipStyle*(): TooltipStyle =
  DefaultTooltipStyle

proc getDefaultTooltipStyle*(): TooltipStyle =
  defaultTooltipStyle()

proc defaultTooltipStyle*(style: TooltipStyle) =
  DefaultTooltipStyle = style.deepCopy

proc setDefaultTooltipStyle*(style: TooltipStyle) =
  defaultTooltipStyle(style)

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
