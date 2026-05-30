import koi/backends/wayland
import koi/types

{.push warning[HoleEnumConv]: off.}

proc waylandMods*(mods: uint32): set[ModifierKey] =
  if (mods and koiWaylandModShift) != 0:
    result.incl(mkShift)
  if (mods and koiWaylandModCtrl) != 0:
    result.incl(mkCtrl)
  if (mods and koiWaylandModAlt) != 0:
    result.incl(mkAlt)
  if (mods and koiWaylandModSuper) != 0:
    result.incl(mkSuper)

proc waylandMouseButton*(button: uint32): MouseButton =
  case button
  of 0x110, 0: mbLeft
  of 0x111, 1: mbRight
  of 0x112, 2: mbMiddle
  of 0x113, 3: mb4
  of 0x114, 4: mb5
  else: mbLeft

proc waylandKeycode*(keycode: uint32): Key =
  case keycode
  of 1:
    keyEscape
  of 2 .. 10:
    Key(uint32(key1) + (keycode - 2))
  of 11:
    key0
  of 12:
    keyMinus
  of 13:
    keyEqual
  of 14:
    keyBackspace
  of 15:
    keyTab
  of 16 .. 25:
    const row = [keyQ, keyW, keyE, keyR, keyT, keyY, keyU, keyI, keyO, keyP]
    row[keycode - 16]
  of 26:
    keyLeftBracket
  of 27:
    keyRightBracket
  of 28:
    keyEnter
  of 29:
    keyLeftControl
  of 30 .. 38:
    const row = [keyA, keyS, keyD, keyF, keyG, keyH, keyJ, keyK, keyL]
    row[keycode - 30]
  of 39:
    keySemicolon
  of 40:
    keyApostrophe
  of 41:
    keyGraveAccent
  of 42:
    keyLeftShift
  of 43:
    keyBackslash
  of 44 .. 50:
    const row = [keyZ, keyX, keyC, keyV, keyB, keyN, keyM]
    row[keycode - 44]
  of 51:
    keyComma
  of 52:
    keyPeriod
  of 53:
    keySlash
  of 54:
    keyRightShift
  of 55:
    keyKpMultiply
  of 56:
    keyLeftAlt
  of 57:
    keySpace
  of 58:
    keyCapsLock
  of 59 .. 68:
    Key(uint32(keyF1) + (keycode - 59))
  of 69:
    keyNumLock
  of 70:
    keyScrollLock
  of 71:
    keyKp7
  of 72:
    keyKp8
  of 73:
    keyKp9
  of 74:
    keyKpSubtract
  of 75:
    keyKp4
  of 76:
    keyKp5
  of 77:
    keyKp6
  of 78:
    keyKpAdd
  of 79:
    keyKp1
  of 80:
    keyKp2
  of 81:
    keyKp3
  of 82:
    keyKp0
  of 83:
    keyKpDecimal
  of 87:
    keyF11
  of 88:
    keyF12
  of 96:
    keyKpEnter
  of 97:
    keyRightControl
  of 98:
    keyKpDivide
  of 99:
    keyPrintScreen
  of 100:
    keyRightAlt
  of 102:
    keyHome
  of 103:
    keyUp
  of 104:
    keyPageUp
  of 105:
    keyLeft
  of 106:
    keyRight
  of 107:
    keyEnd
  of 108:
    keyDown
  of 109:
    keyPageDown
  of 110:
    keyInsert
  of 111:
    keyDelete
  of 117:
    keyKpEqual
  of 119:
    keyPause
  of 125:
    keyLeftSuper
  of 126:
    keyRightSuper
  of 127:
    keyMenu
  else:
    keyUnknown

proc waylandKeySym*(sym: uint32): Key =
  if sym >= uint32(ord('a')) and sym <= uint32(ord('z')):
    return Key(sym - 32)
  if sym >= uint32(ord('A')) and sym <= uint32(ord('Z')):
    return Key(sym)
  if sym >= uint32(ord('0')) and sym <= uint32(ord('9')):
    return Key(sym)
  case sym
  of 0x20:
    keySpace
  of 0x27:
    keyApostrophe
  of 0x2c:
    keyComma
  of 0x2d:
    keyMinus
  of 0x2e:
    keyPeriod
  of 0x2f:
    keySlash
  of 0x3b:
    keySemicolon
  of 0x3d:
    keyEqual
  of 0x5b:
    keyLeftBracket
  of 0x5c:
    keyBackslash
  of 0x5d:
    keyRightBracket
  of 0x60:
    keyGraveAccent
  of 0xff1b:
    keyEscape
  of 0xff0d:
    keyEnter
  of 0xff09:
    keyTab
  of 0xff08:
    keyBackspace
  of 0xff63:
    keyInsert
  of 0xffff:
    keyDelete
  of 0xff53:
    keyRight
  of 0xff51:
    keyLeft
  of 0xff54:
    keyDown
  of 0xff52:
    keyUp
  of 0xff55:
    keyPageUp
  of 0xff56:
    keyPageDown
  of 0xff50:
    keyHome
  of 0xff57:
    keyEnd
  of 0xffe5:
    keyCapsLock
  of 0xff7f:
    keyNumLock
  of 0xff61:
    keyPrintScreen
  of 0xff13:
    keyPause
  of 0xffbe .. 0xffd6:
    Key(uint32(keyF1) + (sym - 0xffbe))
  of 0xffb0 .. 0xffb9:
    Key(uint32(keyKp0) + (sym - 0xffb0))
  of 0xffae:
    keyKpDecimal
  of 0xffaf:
    keyKpDivide
  of 0xffaa:
    keyKpMultiply
  of 0xffad:
    keyKpSubtract
  of 0xffab:
    keyKpAdd
  of 0xff8d:
    keyKpEnter
  of 0xffbd:
    keyKpEqual
  of 0xffe1:
    keyLeftShift
  of 0xffe2:
    keyRightShift
  of 0xffe3:
    keyLeftControl
  of 0xffe4:
    keyRightControl
  of 0xffe9:
    keyLeftAlt
  of 0xffea:
    keyRightAlt
  of 0xffeb:
    keyLeftSuper
  of 0xffec:
    keyRightSuper
  else:
    keyUnknown

proc waylandKey*(keycode: uint32): Key =
  waylandKeycode(keycode)

{.pop.}
