# radioButtons templates - seq[string]

template radioButtons*[T](
    x, y, w, h: float,
    labels: seq[string],
    activeButton: var T,
    tooltips: seq[string] = @[],
    layout: RadioButtonsLayout = RadioButtonsLayout(kind: rblHoriz),
    drawProc: Option[RadioButtonsDrawProc] = RadioButtonsDrawProc.none,
    style: RadioButtonsStyle = borrowDefaultRadioButtonsStyle(),
    disabled: bool = false,
) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)

  var activeButtons = @[activeButton]

  radioButtons(
    id,
    x,
    y,
    w,
    h,
    labels,
    activeButtons,
    tooltips,
    multiselect = false,
    allowNoSelection = false,
    layout,
    drawProc,
    style,
    disabled,
  )

  activeButton = activeButtons[0]

template radioButtons*[T](
    labels: seq[string],
    activeButton: var T,
    tooltips: seq[string] = @[],
    layout: RadioButtonsLayout = RadioButtonsLayout(kind: rblHoriz),
    drawProc: Option[RadioButtonsDrawProc] = RadioButtonsDrawProc.none,
    style: RadioButtonsStyle = borrowDefaultRadioButtonsStyle(),
    disabled: bool = false,
) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)

  autoLayoutPre()

  var activeButtons = @[activeButton]

  radioButtons(
    id,
    g_uiState.autoLayoutState.x,
    autoLayoutNextY(),
    autoLayoutNextItemWidth(),
    autoLayoutNextItemHeight(),
    labels,
    activeButtons,
    tooltips,
    multiselect = false,
    allowNoSelection = false,
    layout,
    drawProc,
    style,
    disabled,
  )

  autoLayoutPost()
  activeButton = activeButtons[0]

template radioButtons*[T](
    x, y, w, h: float,
    labels: seq[string],
    activeButtons: var seq[T],
    tooltips: seq[string] = @[],
    multiselect: bool = true,
    allowNoSelection: bool = false,
    layout: RadioButtonsLayout = RadioButtonsLayout(kind: rblHoriz),
    drawProc: Option[RadioButtonsDrawProc] = RadioButtonsDrawProc.none,
    style: RadioButtonsStyle = borrowDefaultRadioButtonsStyle(),
    disabled: bool = false,
) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)

  radioButtons(
    id, x, y, w, h, labels, activeButtons, tooltips, multiselect, allowNoSelection,
    layout, drawProc, style, disabled,
  )

template radioButtons*[T](
    labels: seq[string],
    activeButtons: var seq[T],
    tooltips: seq[string] = @[],
    multiselect: bool = true,
    allowNoSelection: bool = false,
    layout: RadioButtonsLayout = RadioButtonsLayout(kind: rblHoriz),
    drawProc: Option[RadioButtonsDrawProc] = RadioButtonsDrawProc.none,
    style: RadioButtonsStyle = borrowDefaultRadioButtonsStyle(),
    disabled: bool = false,
) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)

  autoLayoutPre()

  radioButtons(
    id,
    g_uiState.autoLayoutState.x,
    autoLayoutNextY(),
    autoLayoutNextItemWidth(),
    autoLayoutNextItemHeight(),
    labels,
    activeButtons,
    tooltips,
    multiselect,
    allowNoSelection,
    layout,
    drawProc,
    style,
    disabled,
  )

  autoLayoutPost()

template radioButtons*[E: enum](
    x, y, w, h: float,
    activeButton: var E,
    tooltips: seq[string] = @[],
    layout: RadioButtonsLayout = RadioButtonsLayout(kind: rblHoriz),
    drawProc: Option[RadioButtonsDrawProc] = RadioButtonsDrawProc.none,
    style: RadioButtonsStyle = borrowDefaultRadioButtonsStyle(),
    disabled: bool = false,
) =
  let
    i = instantiationInfo(fullPaths = true)
    id = nextId(i.filename, i.line)
    labels = enumToSeq[E]()

  var activeButtons = @[activeButton]
  radioButtons(
    id,
    x,
    y,
    w,
    h,
    labels,
    activeButtons,
    tooltips,
    multiselect = false,
    allowNoSelection = false,
    layout,
    drawProc,
    style,
    disabled,
  )
  activeButton = activeButtons[0]

template radioButtons*[E: enum](
    activeButton: var E,
    tooltips: seq[string] = @[],
    layout: RadioButtonsLayout = RadioButtonsLayout(kind: rblHoriz),
    drawProc: Option[RadioButtonsDrawProc] = RadioButtonsDrawProc.none,
    style: RadioButtonsStyle = borrowDefaultRadioButtonsStyle(),
    disabled: bool = false,
) =
  let
    i = instantiationInfo(fullPaths = true)
    id = nextId(i.filename, i.line)
    labels = enumToSeq[E]()

  autoLayoutPre()
  var activeButtons = @[activeButton]
  radioButtons(
    id,
    g_uiState.autoLayoutState.x,
    autoLayoutNextY(),
    autoLayoutNextItemWidth(),
    autoLayoutNextItemHeight(),
    labels,
    activeButtons,
    tooltips,
    multiselect = false,
    allowNoSelection = false,
    layout,
    drawProc,
    style,
    disabled,
  )
  activeButton = activeButtons[0]
  autoLayoutPost()

template multiRadioButtons*[T](
    x, y, w, h: float,
    labels: seq[string],
    activeButtons: var seq[T],
    allowNoSelection: bool = false,
    tooltips: seq[string] = @[],
    layout: RadioButtonsLayout = RadioButtonsLayout(kind: rblHoriz),
    drawProc: Option[RadioButtonsDrawProc] = RadioButtonsDrawProc.none,
    style: RadioButtonsStyle = borrowDefaultRadioButtonsStyle(),
    disabled: bool = false,
) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)
  radioButtons(
    id,
    x,
    y,
    w,
    h,
    labels,
    activeButtons,
    tooltips,
    multiselect = true,
    allowNoSelection,
    layout,
    drawProc,
    style,
    disabled,
  )

template multiRadioButtons*[T](
    labels: seq[string],
    activeButtons: var seq[T],
    allowNoSelection: bool = false,
    tooltips: seq[string] = @[],
    layout: RadioButtonsLayout = RadioButtonsLayout(kind: rblHoriz),
    drawProc: Option[RadioButtonsDrawProc] = RadioButtonsDrawProc.none,
    style: RadioButtonsStyle = borrowDefaultRadioButtonsStyle(),
    disabled: bool = false,
) =
  let i = instantiationInfo(fullPaths = true)
  let id = nextId(i.filename, i.line)

  autoLayoutPre()
  radioButtons(
    id,
    g_uiState.autoLayoutState.x,
    autoLayoutNextY(),
    autoLayoutNextItemWidth(),
    autoLayoutNextItemHeight(),
    labels,
    activeButtons,
    tooltips,
    multiselect = true,
    allowNoSelection,
    layout,
    drawProc,
    style,
    disabled,
  )
  autoLayoutPost()

template multiRadioButtons*[E: enum](
    x, y, w, h: float,
    activeButtons: var set[E],
    allowNoSelection: bool = false,
    tooltips: seq[string] = @[],
    layout: RadioButtonsLayout = RadioButtonsLayout(kind: rblHoriz),
    drawProc: Option[RadioButtonsDrawProc] = RadioButtonsDrawProc.none,
    style: RadioButtonsStyle = borrowDefaultRadioButtonsStyle(),
    disabled: bool = false,
) =
  let
    i = instantiationInfo(fullPaths = true)
    id = nextId(i.filename, i.line)
    labels = enumToSeq[E]()

  var activeButtonsSeq: seq[E] = @[]
  for b in activeButtons:
    activeButtonsSeq.add(b)

  radioButtons(
    id,
    x,
    y,
    w,
    h,
    labels,
    activeButtonsSeq,
    tooltips,
    multiselect = true,
    allowNoSelection,
    layout,
    drawProc,
    style,
    disabled,
  )

  activeButtons = {}
  for b in activeButtonsSeq:
    activeButtons.incl(b)

template multiRadioButtons*[E: enum](
    activeButtons: var set[E],
    allowNoSelection: bool = false,
    tooltips: seq[string] = @[],
    layout: RadioButtonsLayout = RadioButtonsLayout(kind: rblHoriz),
    drawProc: Option[RadioButtonsDrawProc] = RadioButtonsDrawProc.none,
    style: RadioButtonsStyle = borrowDefaultRadioButtonsStyle(),
    disabled: bool = false,
) =
  let
    i = instantiationInfo(fullPaths = true)
    id = nextId(i.filename, i.line)
    labels = enumToSeq[E]()

  autoLayoutPre()
  var activeButtonsSeq: seq[E] = @[]
  for b in activeButtons:
    activeButtonsSeq.add(b)

  radioButtons(
    id,
    g_uiState.autoLayoutState.x,
    autoLayoutNextY(),
    autoLayoutNextItemWidth(),
    autoLayoutNextItemHeight(),
    labels,
    activeButtonsSeq,
    tooltips,
    multiselect = true,
    allowNoSelection,
    layout,
    drawProc,
    style,
    disabled,
  )

  activeButtons = {}
  for b in activeButtonsSeq:
    activeButtons.incl(b)
  autoLayoutPost()
