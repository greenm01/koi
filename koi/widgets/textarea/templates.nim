template textArea*(
    x, y, w, h: float,
    text: var string,
    tooltip: string = "",
    disabled: bool = false,
    activate: bool = false,
    drawWidget: bool = true,
    constraint: Option[TextAreaConstraint] = TextAreaConstraint.none,
    style: TextAreaStyle = borrowDefaultTextAreaStyle(),
) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)
  textArea(
    id, x, y, w, h, text, tooltip, disabled, activate, drawWidget, constraint, style
  )

template textArea*(
    text: var string,
    tooltip: string = "",
    disabled: bool = false,
    activate: bool = false,
    drawWidget: bool = true,
    constraint: Option[TextAreaConstraint] = TextAreaConstraint.none,
    style: TextAreaStyle = borrowDefaultTextAreaStyle(),
) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)
  autoLayoutPre()
  textArea(
    id,
    g_uiState.autoLayoutState.x,
    autoLayoutNextY(),
    autoLayoutNextItemWidth(),
    autoLayoutNextItemHeight(),
    text,
    tooltip,
    disabled,
    activate,
    drawWidget,
    constraint,
    style,
  )
  autoLayoutPost()
