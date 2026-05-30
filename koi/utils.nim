import std/strutils

template alias*(newName: untyped, call: untyped) =
  template newName(): untyped =
    call

proc enumToSeq*[E: enum](): seq[string] =
  for e in E.low .. E.high:
    result.add($e)

template `++`*[A](a: ptr A, offset: int): ptr A =
  cast[ptr A](cast[int](a) + offset)

func lerp*(a, b, t: SomeFloat): SomeFloat =
  a + (b - a) * t

func invLerp*(a, b, v: SomeFloat): SomeFloat =
  (v - a) / (b - a)

func remap*(inMin, inMax, outMin, outMax, v: SomeFloat): SomeFloat =
  let t = invLerp(inMin, inMax, v)
  lerp(outMin, outMax, t)

func trimNumberText*(text: string): string =
  let dot = text.find('.')
  if dot < 0:
    return text

  var last = text.high
  while last > dot and text[last] == '0':
    dec last
  if last == dot:
    dec last

  result =
    if last >= 0:
      text[0 .. last]
    else:
      "0"
  if result == "-0":
    result = "0"

func formatNumberText*(value: float, precision: Natural): string =
  trimNumberText(value.formatFloat(ffDecimal, precision))
