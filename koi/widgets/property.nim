import std/math
import std/options
import std/strutils
import std/tables

import koi/types
import koi/core
import koi/defaults
import koi/input
import koi/layout
import koi/internal/algorithms
import koi/widgets/button
import koi/widgets/label
import koi/widgets/textfield
import koi/utils

type PropertyState = ref object of RootObj
  valueText: string

func formatPropertyValue(value: float, precision: Natural): string =
  value.formatFloat(ffDecimal, precision)

proc propertyState(id: ItemId): PropertyState =
  alias(ui, g_uiState)
  discard ui.itemState.hasKeyOrPut(id, PropertyState())
  cast[PropertyState](ui.itemState[id])

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
    labelW = min(style.labelWidth, max(w * 0.5, 0.0))
    buttonW = min(style.buttonWidth, max((w - labelW) * 0.5, 0.0))
    gap = style.gap
    textX = x + labelW + buttonW + gap * 2
    textW = max(w - labelW - buttonW * 2 - gap * 4, 0.0)
    decX = x + labelW + gap
    incX = textX + textW + gap

  var value = value_out.clamp(minValue, maxValue)
  let oldValue = value
  var state = propertyState(id)

  if not isActive(textId):
    state.valueText = $value

  label(x, y, labelW, h, labelText, style = style.label)

  if button(decId, decX, y, buttonW, h, "-", tooltip, disabled, style = style.button):
    value = propertyStepValue(value, minValue, maxValue, step, -1)
    state.valueText = $value

  let constraint =
    TextFieldConstraint(kind: tckInteger, minInt: minValue, maxInt: maxValue).some
  textField(
    textId,
    textX,
    y,
    textW,
    h,
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

  if button(incId, incX, y, buttonW, h, "+", tooltip, disabled, style = style.button):
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
    labelW = min(style.labelWidth, max(w * 0.5, 0.0))
    buttonW = min(style.buttonWidth, max((w - labelW) * 0.5, 0.0))
    gap = style.gap
    textX = x + labelW + buttonW + gap * 2
    textW = max(w - labelW - buttonW * 2 - gap * 4, 0.0)
    decX = x + labelW + gap
    incX = textX + textW + gap

  var value = value_out.clamp(minValue, maxValue)
  let oldValue = value
  var state = propertyState(id)

  if not isActive(textId):
    state.valueText = value.formatPropertyValue(style.valuePrecision)

  label(x, y, labelW, h, labelText, style = style.label)

  if button(decId, decX, y, buttonW, h, "-", tooltip, disabled, style = style.button):
    value = propertyStepValue(value, minValue, maxValue, step, -1)
    state.valueText = value.formatPropertyValue(style.valuePrecision)

  textField(
    textId,
    textX,
    y,
    textW,
    h,
    state.valueText,
    tooltip = tooltip,
    disabled = disabled,
    style = style.textField,
  )

  try:
    value = state.valueText.parseFloat().clamp(minValue, maxValue)
  except ValueError:
    discard

  if button(incId, incX, y, buttonW, h, "+", tooltip, disabled, style = style.button):
    value = propertyStepValue(value, minValue, maxValue, step, 1)
    state.valueText = value.formatPropertyValue(style.valuePrecision)

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
