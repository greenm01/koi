let g_textFieldEditShortcuts_WinLinux = {
  tesCursorOneCharLeft: @[mkKeyShortcut(keyLeft), mkKeyShortcut(keyKp4, {})],
  tesCursorOneCharRight: @[mkKeyShortcut(keyRight, {}), mkKeyShortcut(keyKp6, {})],
  tesCursorToPreviousWord:
    @[
      mkKeyShortcut(keyLeft, {mkCtrl}),
      mkKeyShortcut(keyKp4, {mkCtrl}),
      mkKeyShortcut(keySlash, {mkCtrl}),
    ],
  tesCursorToNextWord:
    @[mkKeyShortcut(keyRight, {mkCtrl}), mkKeyShortcut(keyKp6, {mkCtrl})],
  tesCursorToLineStart: @[mkKeyShortcut(keyHome, {}), mkKeyShortcut(keyKp7, {})],
  tesCursorToLineEnd: @[mkKeyShortcut(keyEnd, {}), mkKeyShortcut(keyKp1, {})],
  tesCursorToDocumentStart:
    @[mkKeyShortcut(keyHome, {mkCtrl}), mkKeyShortcut(keyKp7, {mkCtrl})],
  tesCursorToDocumentEnd:
    @[mkKeyShortcut(keyEnd, {mkCtrl}), mkKeyShortcut(keyKp1, {mkCtrl})],
  tesCursorToPreviousLine: @[mkKeyShortcut(keyUp, {}), mkKeyShortcut(keyKp8, {})],
  tesCursorToNextLine: @[mkKeyShortcut(keyDown, {}), mkKeyShortcut(keyKp2, {})],
  tesCursorPageUp: @[mkKeyShortcut(keyPageUp, {}), mkKeyShortcut(keyKp9, {})],
  tesCursorPageDown: @[mkKeyShortcut(keyPageDown, {}), mkKeyShortcut(keyKp3, {})],
  tesSelectionAll: @[mkKeyShortcut(keyA, {mkCtrl})],
  tesSelectionOneCharLeft:
    @[mkKeyShortcut(keyLeft, {mkShift}), mkKeyShortcut(keyKp4, {mkShift})],
  tesSelectionOneCharRight:
    @[mkKeyShortcut(keyRight, {mkShift}), mkKeyShortcut(keyKp6, {mkShift})],
  tesSelectionToPreviousWord:
    @[
      mkKeyShortcut(keyLeft, {mkCtrl, mkShift}),
      mkKeyShortcut(keyKp4, {mkCtrl, mkShift}),
    ],
  tesSelectionToNextWord:
    @[
      mkKeyShortcut(keyRight, {mkCtrl, mkShift}),
      mkKeyShortcut(keyKp6, {mkCtrl, mkShift}),
    ],
  tesSelectionToLineStart:
    @[mkKeyShortcut(keyHome, {mkShift}), mkKeyShortcut(keyKp7, {mkShift})],
  tesSelectionToLineEnd:
    @[mkKeyShortcut(keyEnd, {mkShift}), mkKeyShortcut(keyKp1, {mkShift})],
  tesSelectionToDocumentStart:
    @[
      mkKeyShortcut(keyHome, {mkCtrl, mkShift}),
      mkKeyShortcut(keyKp7, {mkCtrl, mkShift}),
    ],
  tesSelectionToDocumentEnd:
    @[
      mkKeyShortcut(keyEnd, {mkCtrl, mkShift}), mkKeyShortcut(keyKp1, {mkCtrl, mkShift})
    ],
  tesSelectionToPreviousLine:
    @[mkKeyShortcut(keyUp, {mkShift}), mkKeyShortcut(keyKp8, {mkShift})],
  tesSelectionToNextLine:
    @[mkKeyShortcut(keyDown, {mkShift}), mkKeyShortcut(keyKp2, {mkShift})],
  tesSelectionPageUp:
    @[mkKeyShortcut(keyPageUp, {mkShift}), mkKeyShortcut(keyKp9, {mkShift})],
  tesSelectionPageDown:
    @[mkKeyShortcut(keyPageDown, {mkShift}), mkKeyShortcut(keyKp3, {mkShift})],
  tesDeleteOneCharLeft: @[mkKeyShortcut(keyBackspace, {})],
  tesDeleteOneCharRight:
    @[mkKeyShortcut(keyDelete, {}), mkKeyShortcut(keyKpDecimal, {})],
  tesDeleteWordToLeft: @[mkKeyShortcut(keyBackspace, {mkCtrl})],
  tesDeleteWordToRight:
    @[mkKeyShortcut(keyDelete, {mkCtrl}), mkKeyShortcut(keykpDecimal, {mkCtrl})],
  tesDeleteToLineStart: @[mkKeyShortcut(keyBackspace, {mkCtrl, mkShift})],
  tesDeleteToLineEnd:
    @[
      mkKeyShortcut(keyDelete, {mkCtrl, mkShift}),
      mkKeyShortcut(keykpDecimal, {mkCtrl, mkShift}),
    ],
  tesCutText: @[mkKeyShortcut(keyX, {mkCtrl})],
  tesCopyText: @[mkKeyShortcut(keyC, {mkCtrl})],
  tesPasteText: @[mkKeyShortcut(keyV, {mkCtrl})],
  tesInsertNewline:
    @[mkKeyShortcut(keyEnter, {mkShift}), mkKeyShortcut(keyKpEnter, {mkShift})],
  tesPrevTextField: @[mkKeyShortcut(keyTab, {mkShift})],
  tesNextTextField: @[mkKeyShortcut(keyTab, {})],
  tesAccept: @[mkKeyShortcut(keyEnter, {}), mkKeyShortcut(keyKpEnter, {})],
  tesCancel: @[mkKeyShortcut(keyEscape, {}), mkKeyShortcut(keyLeftBracket, {mkCtrl})],
}.toTable

# Shortcut definitions - Mac
let g_textFieldEditShortcuts_Mac = {
  tesCursorOneCharLeft:
    @[
      mkKeyShortcut(keyLeft, {}),
      mkKeyShortcut(keyKp4, {}),
      mkKeyShortcut(keyB, {mkCtrl}),
    ],
  tesCursorOneCharRight:
    @[
      mkKeyShortcut(keyRight, {}),
      mkKeyShortcut(keyKp6, {}),
      mkKeyShortcut(keyF, {mkCtrl}),
    ],
  tesCursorToPreviousWord: @[mkKeyShortcut(keyLeft, {mkAlt})],
  tesCursorToNextWord: @[mkKeyShortcut(keyRight, {mkAlt})],
  tesCursorToLineStart:
    @[mkKeyShortcut(keyLeft, {mkSuper}), mkKeyShortcut(keyKp4, {mkSuper})],
  tesCursorToLineEnd:
    @[mkKeyShortcut(keyRight, {mkSuper}), mkKeyShortcut(keyKp6, {mkSuper})],
  tesCursorToDocumentStart:
    @[mkKeyShortcut(keyUp, {mkSuper}), mkKeyShortcut(keyKp8, {mkSuper})],
  tesCursorToDocumentEnd:
    @[mkKeyShortcut(keyDown, {mkSuper}), mkKeyShortcut(keyKp2, {mkSuper})],
  tesCursorToPreviousLine:
    @[
      mkKeyShortcut(keyUp, {}), mkKeyShortcut(keyKp8, {}), mkKeyShortcut(keyP, {mkCtrl})
    ],
  tesCursorToNextLine:
    @[
      mkKeyShortcut(keyDown, {}),
      mkKeyShortcut(keyKp2, {}),
      mkKeyShortcut(keyN, {mkCtrl}),
    ],
  tesCursorPageUp: @[mkKeyShortcut(keyPageUp, {}), mkKeyShortcut(keyKp9, {})],
  tesCursorPageDown: @[mkKeyShortcut(keyPageDown, {}), mkKeyShortcut(keyKp3, {})],
  tesSelectionAll: @[mkKeyShortcut(keyA, {mkSuper})],
  tesSelectionOneCharLeft:
    @[mkKeyShortcut(keyLeft, {mkShift}), mkKeyShortcut(keyKp4, {mkShift})],
  tesSelectionOneCharRight:
    @[mkKeyShortcut(keyRight, {mkShift}), mkKeyShortcut(keyKp6, {mkShift})],
  tesSelectionToPreviousWord:
    @[
      mkKeyShortcut(keyLeft, {mkSuper, mkShift}),
      mkKeyShortcut(keyKp4, {mkSuper, mkShift}),
    ],
  tesSelectionToNextWord:
    @[
      mkKeyShortcut(keyRight, {mkSuper, mkShift}),
      mkKeyShortcut(keyKp6, {mkSuper, mkShift}),
    ],
  tesDeleteOneCharLeft:
    @[mkKeyShortcut(keyBackspace, {}), mkKeyShortcut(keyH, {mkCtrl})],
  tesDeleteOneCharRight: @[mkKeyShortcut(keyDelete, {}), mkKeyShortcut(keyD, {mkCtrl})],
  tesDeleteWordToLeft: @[mkKeyShortcut(keyBackspace, {mkAlt})],
  tesDeleteWordToRight: @[mkKeyShortcut(keyDelete, {mkAlt})],
  tesDeleteToLineStart: @[mkKeyShortcut(keyBackspace, {mkSuper})],
  tesDeleteToLineEnd:
    @[mkKeyShortcut(keyDelete, {mkAlt}), mkKeyShortcut(keyK, {mkCtrl})],
  tesCutText: @[mkKeyShortcut(keyX, {mkSuper})],
  tesCopyText: @[mkKeyShortcut(keyC, {mkSuper})],
  tesPasteText: @[mkKeyShortcut(keyV, {mkSuper})],
  tesInsertNewline:
    @[
      mkKeyShortcut(keyEnter, {mkShift}),
      mkKeyShortcut(keyKpEnter, {mkShift}),
      mkKeyShortcut(keyO, {mkCtrl}),
    ],
  tesPrevTextField: @[mkKeyShortcut(keyTab, {mkShift})],
  tesNextTextField: @[mkKeyShortcut(keyTab, {})],
  tesAccept: @[mkKeyShortcut(keyEnter, {}), mkKeyShortcut(keyKpEnter, {})],
  tesCancel: @[mkKeyShortcut(keyEscape, {}), mkKeyShortcut(keyLeftBracket, {mkCtrl})],
}.toTable
