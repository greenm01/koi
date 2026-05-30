import std/math
import std/options
import std/strutils
import std/tables

import koi/types
import koi/core
import koi/defaults
import koi/drawing
import koi/input
import koi/layout
import koi/rect
import koi/internal/algorithms
import koi/widgets/button
import koi/widgets/label
import koi/widgets/textfield
import koi/utils

type PropertyState = ref object of RootObj
  valueText: string

proc propertyState(id: ItemId): PropertyState =
  alias(ui, g_uiState)
  discard ui.itemState.hasKeyOrPut(id, PropertyState())
  cast[PropertyState](ui.itemState[id])

proc propertyLayoutSlots(
    id: ItemId, x, y, w, h: float, labelText: string, style: PropertyStyle
): tuple[
  propertySlot: LayoutSlot,
  labelSlot: LayoutSlot,
  decSlot: LayoutSlot,
  textSlot: LayoutSlot,
  incSlot: LayoutSlot,
] =
  let
    (sx, sy) = addDrawOffset(x, y)
    labelId = hashId($id & ":label")
    decId = hashId($id & ":dec")
    textId = hashId($id & ":text")
    incId = hashId($id & ":inc")
    labelW = min(style.labelWidth, max(w * 0.5, 0.0))
    buttonW = min(style.buttonWidth, max((w - labelW) * 0.5, 0.0))
    gap = max(style.gap, 0.0)
    textW = max(w - labelW - buttonW * 2 - gap * 4, 0.0)
    decX = sx + labelW + gap
    textX = decX + buttonW + gap
    incX = textX + textW + gap

  result.propertySlot = layoutContainerSlot(
    id,
    rect(sx, sy, w, h),
    direction = ldLeftToRight,
    childGap = gap,
    padding = padding(0, gap, 0, 0),
    alignCross = lcaStretch,
  )
  result.labelSlot = textLayoutChildSlot(
    result.propertySlot.nodeId,
    labelId,
    rect(sx, sy, labelW, h),
    labelText,
    style.label,
    fixed(labelW),
    fixed(h),
  )
  result.decSlot = layoutChildSlot(
    result.propertySlot.nodeId,
    decId,
    rect(decX, sy, buttonW, h),
    fixed(buttonW),
    fixed(h),
  )
  result.textSlot = layoutChildSlot(
    result.propertySlot.nodeId,
    textId,
    rect(textX, sy, textW, h),
    grow(min = 0.0),
    fixed(h),
  )
  result.incSlot = layoutChildSlot(
    result.propertySlot.nodeId,
    incId,
    rect(incX, sy, buttonW, h),
    fixed(buttonW),
    fixed(h),
  )

proc intProperty*(
    id: ItemId,
    x, y, w, h: float,
    labelText: string,
    minValue, maxValue, step: int,
    value_out: var int,
    tooltip: string = "",
    disabled: bool = false,
    style: PropertyStyle = borrowDefaultPropertyStyle(),
): bool =
  let
    decId = hashId($id & ":dec")
    textId = hashId($id & ":text")
    incId = hashId($id & ":inc")
    slots = propertyLayoutSlots(id, x, y, w, h, labelText, style)

  var value = value_out.clamp(minValue, maxValue)
  let oldValue = value
  var state = propertyState(id)

  if not isActive(textId):
    state.valueText = $value

  labelWithSlot(slots.labelSlot, hashId($id & ":label"), labelText, style = style.label)

  if buttonWithSlot(slots.decSlot, decId, "-", tooltip, disabled, style = style.button):
    value = propertyStepValue(value, minValue, maxValue, step, -1)
    state.valueText = $value

  let constraint =
    TextFieldConstraint(kind: tckInteger, minInt: minValue, maxInt: maxValue).some
  textFieldWithSlot(
    slots.textSlot,
    textId,
    state.valueText,
    tooltip = tooltip,
    disabled = disabled,
    constraint = constraint,
    style = style.textField,
  )

  try:
    value = state.valueText.parseInt().clamp(minValue, maxValue)
  except ValueError:
    discard

  if buttonWithSlot(slots.incSlot, incId, "+", tooltip, disabled, style = style.button):
    value = propertyStepValue(value, minValue, maxValue, step, 1)
    state.valueText = $value

  value_out = value
  result = value != oldValue

proc floatProperty*(
    id: ItemId,
    x, y, w, h: float,
    labelText: string,
    minValue, maxValue, step: float,
    value_out: var float,
    tooltip: string = "",
    disabled: bool = false,
    style: PropertyStyle = borrowDefaultPropertyStyle(),
): bool =
  let
    decId = hashId($id & ":dec")
    textId = hashId($id & ":text")
    incId = hashId($id & ":inc")
    slots = propertyLayoutSlots(id, x, y, w, h, labelText, style)

  var value = value_out.clamp(minValue, maxValue)
  let oldValue = value
  var state = propertyState(id)

  if not isActive(textId):
    state.valueText = value.formatNumberText(style.valuePrecision)

  labelWithSlot(slots.labelSlot, hashId($id & ":label"), labelText, style = style.label)

  if buttonWithSlot(slots.decSlot, decId, "-", tooltip, disabled, style = style.button):
    value = propertyStepValue(value, minValue, maxValue, step, -1)
    state.valueText = value.formatNumberText(style.valuePrecision)

  textFieldWithSlot(
    slots.textSlot,
    textId,
    state.valueText,
    tooltip = tooltip,
    disabled = disabled,
    style = style.textField,
  )

  try:
    value = state.valueText.parseFloat().clamp(minValue, maxValue)
  except ValueError:
    discard

  if buttonWithSlot(slots.incSlot, incId, "+", tooltip, disabled, style = style.button):
    value = propertyStepValue(value, minValue, maxValue, step, 1)
    state.valueText = value.formatNumberText(style.valuePrecision)

  value_out = value
  result = abs(value - oldValue) > 0.0

template intProperty*(
    x, y, w, h: float,
    labelText: string,
    minValue, maxValue, step: int,
    value: var int,
    tooltip: string = "",
    disabled: bool = false,
    style: PropertyStyle = borrowDefaultPropertyStyle(),
): bool =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line, labelText)
  intProperty(
    id, x, y, w, h, labelText, minValue, maxValue, step, value, tooltip, disabled, style
  )

template intProperty*(
    labelText: string,
    minValue, maxValue, step: int,
    value: var int,
    tooltip: string = "",
    disabled: bool = false,
    style: PropertyStyle = borrowDefaultPropertyStyle(),
): bool =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line, labelText)

  autoLayoutPre()
  let res = intProperty(
    id,
    g_uiState.autoLayoutState.x,
    autoLayoutNextY(),
    autoLayoutNextItemWidth(),
    autoLayoutNextItemHeight(),
    labelText,
    minValue,
    maxValue,
    step,
    value,
    tooltip,
    disabled,
    style,
  )
  autoLayoutPost()
  res

template floatProperty*(
    x, y, w, h: float,
    labelText: string,
    minValue, maxValue, step: float,
    value: var float,
    tooltip: string = "",
    disabled: bool = false,
    style: PropertyStyle = borrowDefaultPropertyStyle(),
): bool =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line, labelText)
  floatProperty(
    id, x, y, w, h, labelText, minValue, maxValue, step, value, tooltip, disabled, style
  )

template floatProperty*(
    labelText: string,
    minValue, maxValue, step: float,
    value: var float,
    tooltip: string = "",
    disabled: bool = false,
    style: PropertyStyle = borrowDefaultPropertyStyle(),
): bool =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line, labelText)

  autoLayoutPre()
  let res = floatProperty(
    id,
    g_uiState.autoLayoutState.x,
    autoLayoutNextY(),
    autoLayoutNextItemWidth(),
    autoLayoutNextItemHeight(),
    labelText,
    minValue,
    maxValue,
    step,
    value,
    tooltip,
    disabled,
    style,
  )
  autoLayoutPost()
  res
