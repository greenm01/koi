import std/math

import koi/utils

func dropDownHoverItem*(
    mouseY, itemListY, itemListPadVert, itemHeight: float,
    displayStartItem, maxDisplayItems, itemCount: Natural,
): int =
  if itemHeight <= 0 or itemCount == 0 or maxDisplayItems == 0:
    return -1

  let itemY = mouseY - itemListY - itemListPadVert
  if itemY < 0:
    return -1

  let visibleIndex = floor(itemY / itemHeight).int
  if visibleIndex < 0 or visibleIndex >= maxDisplayItems.int:
    return -1

  let itemIndex = displayStartItem.int + visibleIndex
  if itemIndex < itemCount.int: itemIndex else: -1

func scrollBarRange*(startVal, endVal: float): float =
  abs(startVal - endVal)

func effectiveScrollBarThumbSize*(thumbSize, startVal, endVal: float): float =
  let valueRange = scrollBarRange(startVal, endVal)
  if valueRange <= 0:
    0.0
  elif thumbSize <= 0 or thumbSize > valueRange:
    0.000001
  else:
    thumbSize

func scrollBarThumbLength*(
    trackLength, thumbPad, thumbMinSize, thumbSize, startVal, endVal: float
): float =
  let usableLength = max(trackLength - thumbPad * 2, 0.0)
  if usableLength <= 0:
    return 0.0

  let valueRange = scrollBarRange(startVal, endVal)
  if valueRange <= 0:
    return usableLength

  let effectiveThumbSize = effectiveScrollBarThumbSize(thumbSize, startVal, endVal)
  let calculatedLength = usableLength / (valueRange / effectiveThumbSize)
  max(calculatedLength, min(thumbMinSize, usableLength))

func scrollBarThumbFromValue*(
    value, startVal, endVal, thumbMin, thumbMax: float
): float =
  if startVal == endVal or thumbMin == thumbMax:
    thumbMin
  else:
    lerp(thumbMin, thumbMax, invLerp(startVal, endVal, value))

func scrollBarValueFromThumb*(
    thumbPos, thumbMin, thumbMax, startVal, endVal: float
): float =
  if startVal == endVal or thumbMin == thumbMax:
    startVal
  else:
    lerp(startVal, endVal, invLerp(thumbMin, thumbMax, thumbPos))

func scrollBarTrackClickValue*(
    value, startVal, endVal, clickDir, clickStep: float
): float =
  let step =
    if clickStep < 0:
      scrollBarRange(startVal, endVal) * 0.1
    else:
      clickStep

  let (s, e) =
    if startVal < endVal:
      (startVal, endVal)
    else:
      (endVal, startVal)
  clamp(value + clickDir * step, s, e)
