template alias*(newName: untyped, call: untyped) =
  template newName(): untyped = call

proc enumToSeq*[E: enum](): seq[string] =
  for e in E.low..E.high:
    result.add($e)

template `++`*[A](a: ptr A, offset: int): ptr A =
  cast[ptr A](cast[int](a) + offset)

func lerp*(a, b, t: SomeFloat): SomeFloat =
  a + (b-a)*t

func invLerp*(a, b, v: SomeFloat): SomeFloat =
  (v-a) / (b-a)

func remap*(inMin, inMax, outMin, outMax, v: SomeFloat): SomeFloat =
  let t = invLerp(inMin, inMax, v)
  lerp(outMin, outMax, t)
