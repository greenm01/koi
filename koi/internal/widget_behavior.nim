import koi/types
import koi/core
import koi/input

type SimpleWidgetBehavior* = object
  clicked*: bool
  state*: WidgetState

proc captureDragWidget*(id: ItemId, hit: bool, allowActiveCapture: bool = false): bool =
  if not hit:
    return false

  markHot(id)
  if g_uiState.mbLeftDown and (hasNoActiveItem() or allowActiveCapture):
    markActive(id)
    return true

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
    not disabled and
    simpleWidgetClicked(id, g_uiState.mbLeftDown, isHot(id), isActive(id))
  result.state = simpleWidgetState(disabled, isHot(id), isActive(id), hasNoActiveItem())

proc selectableWidgetBehavior*(
    id: ItemId, disabled, selected: bool
): SimpleWidgetBehavior =
  result.clicked =
    not disabled and
    simpleWidgetClicked(id, g_uiState.mbLeftDown, isHot(id), isActive(id))
  result.state =
    simpleWidgetState(disabled, isHot(id), isActive(id), hasNoActiveItem(), selected)

func radioButtonState*(
    hot, active, canHover, selected: bool,
    hotButton, buttonIndex: int,
    disabled: bool = false,
): WidgetState =
  if disabled:
    return wsDisabled

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

func dragWidgetState*(hot, active, canHover: bool): WidgetState =
  if hot and canHover:
    wsHover
  elif active:
    wsDown
  else:
    wsNormal

proc dragWidgetState*(id: ItemId): WidgetState =
  dragWidgetState(isHot(id), isActive(id), hasNoActiveItem())
