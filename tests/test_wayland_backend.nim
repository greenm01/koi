import std/unittest

import koi/backends/wayland_keys
import koi/types

suite "native Wayland input mapping":
  test "modifier bitfield maps to Koi modifiers":
    check waylandMods(0) == {}
    check waylandMods(0b1111'u32) == {mkShift, mkCtrl, mkAlt, mkSuper}

  test "mouse buttons map Wayland and fallback button ids":
    check waylandMouseButton(0x110) == mbLeft
    check waylandMouseButton(0x111) == mbRight
    check waylandMouseButton(0x112) == mbMiddle
    check waylandMouseButton(3) == mb4

  test "physical keycodes map letters digits controls function and keypad keys":
    check waylandKeycode(30) == keyA
    check waylandKeycode(44) == keyZ
    check waylandKeycode(2) == key1
    check waylandKeycode(1) == keyEscape
    check waylandKeycode(42) == keyLeftShift
    check waylandKeycode(53) == keySlash
    check waylandKeycode(103) == keyUp
    check waylandKeycode(88) == keyF12
    check waylandKeycode(76) == keyKp5
    check waylandKeycode(96) == keyKpEnter
    check waylandKeycode(0) == keyUnknown

  test "legacy keysym mapper remains available for direct ABI callers":
    check waylandKeySym(uint32(ord('a'))) == keyA
    check waylandKeySym(0xff52) == keyUp
    check waylandKeySym(0xffc9) == keyF12
