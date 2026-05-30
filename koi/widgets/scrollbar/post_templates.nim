proc scrollBarPost*() =
  alias(ui, g_uiState)
  alias(sb, ui.scrollBarState)

  if not ui.mbLeftDown:
    sb.state = sbsDefault
    ui.widgetMouseDrag = false

# Templates

template horizScrollBar*(
    x, y, w, h: float,
    startVal, endVal: float,
    value: var float,
    tooltip: string = "",
    thumbSize: float = -1.0,
    clickStep: float = -1.0,
    style: ScrollBarStyle = borrowDefaultScrollBarStyle(),
    allowFocusCaptured: bool = false,
    disabled: bool = false,
) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)

  horizScrollBar(
    id, x, y, w, h, startVal, endVal, value, tooltip, thumbSize, clickStep, style,
    allowFocusCaptured, disabled,
  )

template vertScrollBar*(
    x, y, w, h: float,
    startVal, endVal: float,
    value: var float,
    tooltip: string = "",
    thumbSize: float = -1.0,
    clickStep: float = -1.0,
    style: ScrollBarStyle = borrowDefaultScrollBarStyle(),
    allowFocusCaptured: bool = false,
    disabled: bool = false,
) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)

  vertScrollBar(
    id, x, y, w, h, startVal, endVal, value, tooltip, thumbSize, clickStep, style,
    allowFocusCaptured, disabled,
  )
