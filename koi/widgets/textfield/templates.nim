proc textField*(
    id: ItemId,
    x, y, w, h: float,
    text_out: var string,
    tooltip: string = "",
    disabled: bool = false,
    activate: bool = false,
    drawWidget: bool = true,
    constraint: Option[TextFieldConstraint] = TextFieldConstraint.none,
    style: TextFieldStyle = borrowDefaultTextFieldStyle(),
    filter: TextFieldFilterKind = tffAny,
) =
  let (x, y) = addDrawOffset(x, y)
  let slot = layoutSlot(id, rect(x, y, w, h))
  textFieldWithSlot(
    slot, id, text_out, tooltip, disabled, activate, drawWidget, constraint, style,
    filter,
  )

template rawTextField*(
    x, y, w, h: float,
    text: var string,
    tooltip: string = "",
    disabled: bool = false,
    activate: bool = false,
    constraint: Option[TextFieldConstraint] = TextFieldConstraint.none,
    style: TextFieldStyle = borrowDefaultTextFieldStyle(),
    filter: TextFieldFilterKind = tffAny,
) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)
  textField(
    id,
    x,
    y,
    w,
    h,
    text,
    tooltip,
    disabled,
    activate,
    drawWidget = false,
    constraint,
    style,
    filter,
  )

template textField*(
    x, y, w, h: float,
    text: var string,
    tooltip: string = "",
    disabled: bool = false,
    activate: bool = false,
    drawWidget: bool = true,
    constraint: Option[TextFieldConstraint] = TextFieldConstraint.none,
    style: TextFieldStyle = borrowDefaultTextFieldStyle(),
    filter: TextFieldFilterKind = tffAny,
) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)
  textField(
    id, x, y, w, h, text, tooltip, disabled, activate, drawWidget, constraint, style,
    filter,
  )

template textField*(
    text: var string,
    tooltip: string = "",
    disabled: bool = false,
    activate: bool = false,
    drawWidget: bool = true,
    constraint: Option[TextFieldConstraint] = TextFieldConstraint.none,
    style: TextFieldStyle = borrowDefaultTextFieldStyle(),
    filter: TextFieldFilterKind = tffAny,
) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)
  autoLayoutPre()
  textField(
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
    filter,
  )
  autoLayoutPost()
