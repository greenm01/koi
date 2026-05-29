import koi/types
import koi/core
import koi/input

type SimpleWidgetBehavior* = object
  clicked*: bool
  state*: WidgetState

proc captureSimpleWidget*(id: ItemId, disabled: bool) =
  markHot(id)
  if not disabled and g_uiState.mbLeftDown and hasNoActiveItem():
    markActive(id)

func simpleWidgetClicked*(id: ItemId, mbLeftDown, hot, active: bool): bool =
  (not mbLeftDown) and hot and active

func simpleWidgetState*(
    disabled, hot, active, canHover: bool, selected: bool = false
): WidgetState =
  if disabled:
    wsDisabled
  elif hot and canHover:
    if selected: wsActiveHover else: wsHover
  elif hot and active:
    wsDown
  else:
    if selected: wsActive else: wsNormal

proc simpleWidgetBehavior*(id: ItemId, disabled: bool): SimpleWidgetBehavior =
  result.clicked =
    simpleWidgetClicked(id, g_uiState.mbLeftDown, isHot(id), isActive(id))
  result.state = simpleWidgetState(disabled, isHot(id), isActive(id), hasNoActiveItem())

proc selectableWidgetBehavior*(
    id: ItemId, disabled, selected: bool
): SimpleWidgetBehavior =
  result.clicked =
    simpleWidgetClicked(id, g_uiState.mbLeftDown, isHot(id), isActive(id))
  result.state =
    simpleWidgetState(disabled, isHot(id), isActive(id), hasNoActiveItem(), selected)

func radioButtonState*(
    hot, active, canHover, selected: bool, hotButton, buttonIndex: int
): WidgetState =
  let groupState = simpleWidgetState(false, hot, active, canHover)
  let buttonHot = hotButton == buttonIndex

  if selected:
    if buttonHot:
      case groupState
      of wsHover: wsActiveHover
      of wsDown: wsActiveDown
      else: wsActive
    else:
      wsActive
  else:
    if buttonHot:
      case groupState
      of wsHover: wsHover
      of wsDown: wsDown
      else: wsNormal
    else:
      wsNormal
