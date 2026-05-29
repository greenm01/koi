import std/math
import std/strformat

import nanovg

import koi/rect
import koi/types

const
  NullLayoutNodeId* = LayoutNodeId(-1'i32)
  LayoutInfinity* = 1.0e30

func isNull*(id: LayoutNodeId): bool =
  int32(id) < 0

func toIndex(id: LayoutNodeId): int =
  int(id)

func size*(w, h: float): Size =
  Size(w: w, h: h)

func padding*(left, right, top, bottom: float): Padding =
  Padding(left: left, right: right, top: top, bottom: bottom)

func paddingAll*(value: float): Padding =
  padding(value, value, value, value)

func fixed*(value: float): LayoutSize =
  LayoutSize(kind: lskFixed, min: value, max: value, value: value)

func percent*(value: float, min: float = 0.0, max: float = LayoutInfinity): LayoutSize =
  LayoutSize(kind: lskPercent, min: min, max: max, percent: value)

func grow*(min: float = 0.0, max: float = LayoutInfinity): LayoutSize =
  LayoutSize(kind: lskGrow, min: min, max: max)

func fit*(min: float = 0.0, max: float = LayoutInfinity): LayoutSize =
  LayoutSize(kind: lskFit, min: min, max: max)

func flow*(): LayoutPlacement =
  LayoutPlacement(kind: lpkFlow)

func manual*(x, y: float): LayoutPlacement =
  LayoutPlacement(kind: lpkManual, x: x, y: y)

func follow*(
    target: LayoutNodeId,
    followKind: LayoutFollowerKind,
    followAlign: HorizontalAlign = haLeft,
    windowPad: float = 10.0,
    followInset: Padding = Padding(),
): LayoutPlacement =
  LayoutPlacement(
    kind: lpkFollow,
    target: target,
    followKind: followKind,
    followAlign: followAlign,
    followInset: followInset,
    windowPad: windowPad,
  )

func attachNode*(
    target: LayoutNodeId,
    targetPoint, selfPoint: LayoutAttachPoint,
    offset: Size = Size(),
    windowPad: float = 0.0,
    clipToRoot: bool = false,
    zIndex: int = 0,
    capturePointer: bool = false,
): LayoutPlacement =
  LayoutPlacement(
    kind: lpkAttach,
    attach: LayoutAttach(
      targetKind: latNode,
      targetNode: target,
      targetPoint: targetPoint,
      selfPoint: selfPoint,
      offset: offset,
      windowPad: windowPad,
      clipToRoot: clipToRoot,
      zIndex: zIndex,
      capturePointer: capturePointer,
    ),
  )

func attachParent*(
    targetPoint, selfPoint: LayoutAttachPoint,
    offset: Size = Size(),
    windowPad: float = 0.0,
    clipToRoot: bool = false,
    zIndex: int = 0,
    capturePointer: bool = false,
): LayoutPlacement =
  LayoutPlacement(
    kind: lpkAttach,
    attach: LayoutAttach(
      targetKind: latParent,
      targetNode: NullLayoutNodeId,
      targetPoint: targetPoint,
      selfPoint: selfPoint,
      offset: offset,
      windowPad: windowPad,
      clipToRoot: clipToRoot,
      zIndex: zIndex,
      capturePointer: capturePointer,
    ),
  )

func attachRoot*(
    targetPoint, selfPoint: LayoutAttachPoint,
    offset: Size = Size(),
    windowPad: float = 0.0,
    clipToRoot: bool = false,
    zIndex: int = 0,
    capturePointer: bool = false,
): LayoutPlacement =
  LayoutPlacement(
    kind: lpkAttach,
    attach: LayoutAttach(
      targetKind: latRoot,
      targetNode: NullLayoutNodeId,
      targetPoint: targetPoint,
      selfPoint: selfPoint,
      offset: offset,
      windowPad: windowPad,
      clipToRoot: clipToRoot,
      zIndex: zIndex,
      capturePointer: capturePointer,
    ),
  )

func attach*(
    target: LayoutNodeId,
    targetPoint, selfPoint: LayoutAttachPoint,
    offset: Size = Size(),
    windowPad: float = 0.0,
    clipToRoot: bool = false,
    zIndex: int = 0,
    capturePointer: bool = false,
): LayoutPlacement =
  attachNode(
    target, targetPoint, selfPoint, offset, windowPad, clipToRoot, zIndex,
    capturePointer,
  )

proc reportLayoutError*(
    arena: var LayoutArena,
    kind: LayoutErrorKind,
    nodeId: LayoutNodeId = NullLayoutNodeId,
    itemId: ItemId = 0,
    message: string = "",
) =
  let error = LayoutError(kind: kind, itemId: itemId, nodeId: nodeId, message: message)
  arena.errors.add(error)
  if arena.errorHandler != nil:
    arena.errorHandler(error)

proc setLayoutErrorHandler*(arena: var LayoutArena, handler: LayoutErrorHandler) =
  arena.errorHandler = handler

proc clearLayoutErrors*(arena: var LayoutArena) =
  arena.errors.setLen(0)

func layoutErrors*(arena: LayoutArena): seq[LayoutError] =
  arena.errors

proc setLayoutMaxNodes*(arena: var LayoutArena, maxNodes: int) =
  arena.maxNodes = max(0, maxNodes)

func clampSize(value: float, spec: LayoutSize): float =
  case spec.kind
  of lskFixed:
    max(0.0, spec.value)
  of lskPercent, lskFit, lskGrow:
    clamp(value, spec.min, spec.max)

func axis(size: Size, horizontal: bool): float =
  if horizontal: size.w else: size.h

func setAxis(size: var Size, horizontal: bool, value: float) =
  if horizontal:
    size.w = value
  else:
    size.h = value

func axis(rect: Rect, horizontal: bool): float =
  if horizontal: rect.w else: rect.h

proc setAxis(rect: var Rect, horizontal: bool, value: float) =
  if horizontal:
    rect.w = value
  else:
    rect.h = value

func nodeSize(node: LayoutNode): Size =
  size(node.rect.w, node.rect.h)

func mainIsHorizontal(node: LayoutNode): bool =
  node.direction == ldLeftToRight

func paddingMain(node: LayoutNode): float =
  if node.mainIsHorizontal:
    node.padding.left + node.padding.right
  else:
    node.padding.top + node.padding.bottom

func paddingCross(node: LayoutNode): float =
  if node.mainIsHorizontal:
    node.padding.top + node.padding.bottom
  else:
    node.padding.left + node.padding.right

func paddingStart(node: LayoutNode, horizontal: bool): float =
  if horizontal: node.padding.left else: node.padding.top

func paddingEnd(node: LayoutNode, horizontal: bool): float =
  if horizontal: node.padding.right else: node.padding.bottom

func rectStart(node: LayoutNode, horizontal: bool): float =
  if horizontal: node.rect.x else: node.rect.y

proc setRectStart(node: var LayoutNode, horizontal: bool, value: float) =
  if horizontal:
    node.rect.x = value
  else:
    node.rect.y = value

iterator children*(arena: LayoutArena, node: LayoutNode): LayoutNodeId =
  let start = int(node.firstChild)
  for i in 0 ..< int(node.childCount):
    yield arena.childIndices[start + i]

proc initLayoutArena*(arena: var LayoutArena, measureText: MeasureTextProc = nil) =
  let
    errorHandler = arena.errorHandler
    maxNodes = arena.maxNodes
  arena.nodes.setLen(0)
  arena.childIndices.setLen(0)
  arena.childLists.setLen(0)
  arena.nodeStack.setLen(0)
  arena.errors.setLen(0)
  arena.seenItemIds.setLen(0)
  arena.measureText = measureText
  arena.errorHandler = errorHandler
  arena.maxNodes = maxNodes

proc clearLayoutArena*(arena: var LayoutArena) =
  let measureText = arena.measureText
  arena.initLayoutArena(measureText)

proc appendToParent(arena: var LayoutArena, parent, child: LayoutNodeId) =
  if not parent.isNull:
    arena.childLists[parent.toIndex].add(child)

func sanitizePercent(value: float): float =
  clamp(value, 0.0, 1.0)

proc validateSize(arena: var LayoutArena, node: var LayoutNode, horizontal: bool) =
  var spec = if horizontal: node.width else: node.height
  if spec.kind == lskPercent and (spec.percent < 0.0 or spec.percent > 1.0):
    arena.reportLayoutError(
      lekInvalidPercent,
      node.id,
      node.itemId,
      &"layout percent {spec.percent} outside 0..1; clamped",
    )
    spec.percent = spec.percent.sanitizePercent
    if horizontal:
      node.width = spec
    else:
      node.height = spec

proc addLayoutNode*(
    arena: var LayoutArena, node: LayoutNode, parent: LayoutNodeId
): LayoutNodeId =
  if arena.maxNodes > 0 and arena.nodes.len >= arena.maxNodes:
    arena.reportLayoutError(
      lekExceededMaxNodes,
      NullLayoutNodeId,
      node.itemId,
      &"layout node capacity {arena.maxNodes} exceeded",
    )
    return NullLayoutNodeId

  result = LayoutNodeId(arena.nodes.len.int32)
  var n = node
  n.id = result
  n.parent = parent
  arena.validateSize(n, horizontal = true)
  arena.validateSize(n, horizontal = false)
  if n.itemId != 0:
    for seen in arena.seenItemIds:
      if seen == n.itemId:
        arena.reportLayoutError(
          lekDuplicateItemId, result, n.itemId, &"duplicate layout item id {n.itemId}"
        )
        break
    arena.seenItemIds.add(n.itemId)
  n.firstChild = 0
  n.childCount = 0
  arena.nodes.add(n)
  arena.childLists.add(@[])
  arena.appendToParent(parent, result)

proc addLayoutNode*(arena: var LayoutArena, node: LayoutNode): LayoutNodeId =
  let parent =
    if arena.nodeStack.len > 0:
      arena.nodeStack[^1]
    else:
      NullLayoutNodeId
  arena.addLayoutNode(node, parent)

proc beginLayoutNode*(arena: var LayoutArena, node: LayoutNode): LayoutNodeId =
  let parent =
    if arena.nodeStack.len > 0:
      arena.nodeStack[^1]
    else:
      NullLayoutNodeId
  result = arena.addLayoutNode(node, parent)
  if not result.isNull:
    arena.nodeStack.add(result)

proc endLayoutNode*(arena: var LayoutArena): LayoutNodeId =
  if arena.nodeStack.len == 0:
    arena.reportLayoutError(
      lekUnbalancedLayoutStack, NullLayoutNodeId, 0,
      "endLayoutNode called with an empty layout stack",
    )
    return NullLayoutNodeId

  result = arena.nodeStack.pop()

proc finalizeLayoutChildren(arena: var LayoutArena) =
  arena.childIndices.setLen(0)
  for i in 0 ..< arena.nodes.len:
    let children = arena.childLists[i]
    arena.nodes[i].firstChild = int32(arena.childIndices.len)
    arena.nodes[i].childCount = int32(children.len)
    for child in children:
      arena.nodes[child.toIndex].parent = arena.nodes[i].id
      arena.childIndices.add(child)

func layoutNode*(
    kind: LayoutNodeKind = lnkContainer,
    width: LayoutSize = grow(),
    height: LayoutSize = fit(),
    direction: LayoutDirection = ldTopToBottom,
    padding: Padding = paddingAll(0),
    childGap: float = 0,
    alignMain: LayoutAlign = laStart,
    alignCross: LayoutCrossAlign = lcaStart,
    aspectRatio: float = 0.0,
    placement: LayoutPlacement = flow(),
    itemId: ItemId = 0,
    scrollOffset: Size = size(0, 0),
    text: string = "",
    fontSize: float = 0,
    fontFace: string = "",
): LayoutNode =
  LayoutNode(
    id: NullLayoutNodeId,
    itemId: itemId,
    parent: NullLayoutNodeId,
    kind: kind,
    placement: placement,
    direction: direction,
    width: width,
    height: height,
    padding: padding,
    childGap: childGap,
    alignMain: alignMain,
    alignCross: alignCross,
    aspectRatio: max(0.0, aspectRatio),
    scrollOffset: scrollOffset,
    text: text,
    fontSize: fontSize,
    fontFace: fontFace,
  )

func resolvedOwnSize(node: LayoutNode, horizontal: bool, parentInner: float): float =
  let spec = if horizontal: node.width else: node.height

  case spec.kind
  of lskFixed:
    max(0.0, spec.value)
  of lskPercent:
    clamp(parentInner * spec.percent, spec.min, spec.max)
  of lskFit, lskGrow:
    clampSize(node.intrinsicPref.axis(horizontal), spec)

func contributesToLayout(node: LayoutNode): bool =
  node.placement.kind notin {lpkFollow, lpkAttach}

func canAspectDeriveWidth(node: LayoutNode): bool =
  node.aspectRatio > 0.0 and node.width.kind != lskFixed and node.height.kind == lskFixed

func canAspectDeriveHeight(node: LayoutNode): bool =
  node.aspectRatio > 0.0 and node.height.kind != lskFixed

proc applyIntrinsicAspect(node: var LayoutNode) =
  if node.aspectRatio <= 0.0:
    return
  if node.height.kind != lskFixed:
    let width = max(node.intrinsicPref.w, node.intrinsicMin.w)
    if width > 0.0:
      let height = clampSize(width / node.aspectRatio, node.height)
      node.intrinsicMin.h = max(node.intrinsicMin.h, height)
      node.intrinsicPref.h = max(node.intrinsicPref.h, height)
  if node.width.kind != lskFixed and node.height.kind == lskFixed:
    let width = clampSize(max(0.0, node.height.value) * node.aspectRatio, node.width)
    node.intrinsicMin.w = max(node.intrinsicMin.w, width)
    node.intrinsicPref.w = max(node.intrinsicPref.w, width)

proc measureNode(arena: var LayoutArena, id: LayoutNodeId) =
  let i = id.toIndex
  for child in arena.children(arena.nodes[i]):
    arena.measureNode(child)

  var node = arena.nodes[i]
  var minSize = node.intrinsicMin
  var prefSize = node.intrinsicPref

  if node.kind == lnkText and arena.measureText != nil:
    let m = arena.measureText(node.text, node.fontSize, node.fontFace, LayoutInfinity)
    minSize = size(m.minWidth, m.lineHeight * max(1, m.lineCount).float)
    prefSize = size(m.prefWidth, m.lineHeight * max(1, m.lineCount).float)

  if node.childCount > 0:
    let mainHorizontal = node.mainIsHorizontal
    var minMain = 0.0
    var prefMain = 0.0
    var minCross = 0.0
    var prefCross = 0.0

    for childId in arena.children(node):
      let child = arena.nodes[childId.toIndex]
      if not child.contributesToLayout:
        continue
      minMain += child.intrinsicMin.axis(mainHorizontal)
      prefMain += child.intrinsicPref.axis(mainHorizontal)
      minCross = max(minCross, child.intrinsicMin.axis(not mainHorizontal))
      prefCross = max(prefCross, child.intrinsicPref.axis(not mainHorizontal))

    var contributingCount = 0
    for childId in arena.children(node):
      if arena.nodes[childId.toIndex].contributesToLayout:
        inc contributingCount

    let gap = node.childGap * max(0, contributingCount - 1).float
    minMain += gap + node.paddingMain
    prefMain += gap + node.paddingMain
    minCross += node.paddingCross
    prefCross += node.paddingCross

    minSize.setAxis(mainHorizontal, max(minSize.axis(mainHorizontal), minMain))
    prefSize.setAxis(mainHorizontal, max(prefSize.axis(mainHorizontal), prefMain))
    minSize.setAxis(not mainHorizontal, max(minSize.axis(not mainHorizontal), minCross))
    prefSize.setAxis(
      not mainHorizontal, max(prefSize.axis(not mainHorizontal), prefCross)
    )

  for horizontal in [true, false]:
    let spec = if horizontal: node.width else: node.height
    case spec.kind
    of lskFixed:
      minSize.setAxis(horizontal, max(0.0, spec.value))
      prefSize.setAxis(horizontal, max(0.0, spec.value))
    of lskPercent:
      minSize.setAxis(horizontal, spec.min)
      prefSize.setAxis(horizontal, max(spec.min, prefSize.axis(horizontal)))
    of lskFit, lskGrow:
      minSize.setAxis(horizontal, max(minSize.axis(horizontal), spec.min))
      prefSize.setAxis(horizontal, clamp(prefSize.axis(horizontal), spec.min, spec.max))

  node.intrinsicMin = minSize
  node.intrinsicPref = prefSize
  node.applyIntrinsicAspect()
  arena.nodes[i] = node

func resolvedChildSizes(
    arena: LayoutArena, parent: LayoutNode, horizontal: bool
): seq[float] =
  let
    parentSize = parent.nodeSize.axis(horizontal)
    gap =
      if horizontal == parent.mainIsHorizontal:
        var flowCount = 0
        for childId in arena.children(parent):
          if arena.nodes[childId.toIndex].placement.kind == lpkFlow:
            inc(flowCount)
        parent.childGap * max(0, flowCount - 1).float
      else:
        0.0
    inner = max(
      0.0,
      parentSize - parent.paddingStart(horizontal) - parent.paddingEnd(horizontal) - gap,
    )

  result = newSeq[float](int(parent.childCount))
  if parent.childCount == 0:
    return

  var growIndices: seq[int]
  var shrinkIndices: seq[int]
  var shrinkFloors = newSeq[float](int(parent.childCount))
  var used = 0.0
  var pos = 0
  for childId in arena.children(parent):
    let child = arena.nodes[childId.toIndex]
    let spec = if horizontal: child.width else: child.height
    let value =
      if horizontal and child.canAspectDeriveWidth:
        clampSize(max(0.0, child.height.value) * child.aspectRatio, child.width)
      elif not horizontal and child.canAspectDeriveHeight and child.rect.w > 0.0:
        clampSize(child.rect.w / child.aspectRatio, child.height)
      else:
        if horizontal != parent.mainIsHorizontal:
          case spec.kind
          of lskFixed:
            max(0.0, spec.value)
          of lskPercent:
            clamp(inner * spec.percent, spec.min, spec.max)
          of lskFit:
            clampSize(child.intrinsicPref.axis(horizontal), spec)
          of lskGrow:
            clampSize(inner, spec)
        else:
          case spec.kind
          of lskFixed:
            max(0.0, spec.value)
          of lskPercent:
            clamp(inner * spec.percent, spec.min, spec.max)
          of lskFit:
            let preferred = clampSize(child.intrinsicPref.axis(horizontal), spec)
            if child.placement.kind == lpkFlow:
              shrinkIndices.add(pos)
              shrinkFloors[pos] = max(spec.min, child.intrinsicMin.axis(horizontal))
            preferred
          of lskGrow:
            if child.placement.kind == lpkFlow:
              growIndices.add(pos)
              shrinkIndices.add(pos)
              shrinkFloors[pos] = spec.min
            max(spec.min, child.intrinsicMin.axis(horizontal))
    result[pos] = value
    if child.contributesToLayout and
        (horizontal != parent.mainIsHorizontal or child.placement.kind == lpkFlow):
      used += value
    inc(pos)

  if growIndices.len > 0:
    let extra = max(0.0, inner - used)
    let share = extra / growIndices.len.float
    for index in growIndices:
      let childId = arena.childIndices[int(parent.firstChild) + index]
      let spec =
        if horizontal:
          arena.nodes[childId.toIndex].width
        else:
          arena.nodes[childId.toIndex].height
      result[index] = clampSize(result[index] + share, spec)

  if horizontal == parent.mainIsHorizontal and used > inner and shrinkIndices.len > 0:
    var overflow = used - inner
    var candidates = shrinkIndices
    while overflow > 0.0001 and candidates.len > 0:
      let share = overflow / candidates.len.float
      var nextCandidates: seq[int]
      var remainingOverflow = 0.0
      for index in candidates:
        let floor = shrinkFloors[index]
        let shrinkBy = min(share, max(0.0, result[index] - floor))
        result[index] -= shrinkBy
        remainingOverflow += share - shrinkBy
        if result[index] > floor + 0.0001:
          nextCandidates.add(index)
      overflow = remainingOverflow
      candidates = nextCandidates

proc resolveAxis(arena: var LayoutArena, id: LayoutNodeId, horizontal: bool) =
  let i = id.toIndex
  var node = arena.nodes[i]
  if node.parent.isNull:
    node.rect.setAxis(
      horizontal, node.resolvedOwnSize(horizontal, node.rect.axis(horizontal))
    )
    arena.nodes[i] = node

  node = arena.nodes[i]
  let sizes = arena.resolvedChildSizes(node, horizontal)

  for childOffset in 0 ..< int(node.childCount):
    let childId = arena.childIndices[int(node.firstChild) + childOffset]
    let childIndex = childId.toIndex
    arena.nodes[childIndex].rect.setAxis(horizontal, sizes[childOffset])
    arena.resolveAxis(childId, horizontal)

proc wrapTextNodes(arena: var LayoutArena, id: LayoutNodeId) =
  let i = id.toIndex
  var node = arena.nodes[i]

  if node.kind == lnkText and arena.measureText != nil:
    let width = max(0.0, node.rect.w)
    let m = arena.measureText(node.text, node.fontSize, node.fontFace, width)
    let wrappedHeight = m.lineHeight * max(1, m.lineCount).float
    node.intrinsicMin.h = wrappedHeight
    node.intrinsicPref.h = wrappedHeight
    if node.height.kind == lskFit:
      node.rect.h = clampSize(wrappedHeight, node.height)
    arena.nodes[i] = node

  for childId in arena.children(arena.nodes[i]):
    arena.wrapTextNodes(childId)

proc refreshFitIntrinsic(arena: var LayoutArena, id: LayoutNodeId) =
  let i = id.toIndex
  for childId in arena.children(arena.nodes[i]):
    arena.refreshFitIntrinsic(childId)

  var node = arena.nodes[i]
  if node.kind != lnkText and node.childCount > 0:
    let mainHorizontal = node.mainIsHorizontal
    var minMain = 0.0
    var prefMain = 0.0
    var minCross = 0.0
    var prefCross = 0.0

    for childId in arena.children(node):
      let child = arena.nodes[childId.toIndex]
      if not child.contributesToLayout:
        continue
      minMain += child.intrinsicMin.axis(mainHorizontal)
      prefMain += child.intrinsicPref.axis(mainHorizontal)
      minCross = max(minCross, child.intrinsicMin.axis(not mainHorizontal))
      prefCross = max(prefCross, child.intrinsicPref.axis(not mainHorizontal))

    var contributingCount = 0
    for childId in arena.children(node):
      if arena.nodes[childId.toIndex].contributesToLayout:
        inc contributingCount

    let gap = node.childGap * max(0, contributingCount - 1).float
    var minSize = node.intrinsicMin
    var prefSize = node.intrinsicPref

    minSize.setAxis(mainHorizontal, minMain + gap + node.paddingMain)
    prefSize.setAxis(mainHorizontal, prefMain + gap + node.paddingMain)
    minSize.setAxis(not mainHorizontal, minCross + node.paddingCross)
    prefSize.setAxis(not mainHorizontal, prefCross + node.paddingCross)

    for horizontal in [true, false]:
      let spec = if horizontal: node.width else: node.height
      case spec.kind
      of lskFixed:
        minSize.setAxis(horizontal, max(0.0, spec.value))
        prefSize.setAxis(horizontal, max(0.0, spec.value))
      of lskPercent:
        minSize.setAxis(horizontal, spec.min)
        prefSize.setAxis(horizontal, max(spec.min, prefSize.axis(horizontal)))
      of lskFit, lskGrow:
        minSize.setAxis(horizontal, max(minSize.axis(horizontal), spec.min))
        prefSize.setAxis(
          horizontal, clamp(prefSize.axis(horizontal), spec.min, spec.max)
        )

    node.intrinsicMin = minSize
    node.intrinsicPref = prefSize
    node.applyIntrinsicAspect()
    if node.height.kind == lskFit:
      node.rect.h = clampSize(node.intrinsicPref.h, node.height)
    arena.nodes[i] = node

proc applyResolvedAspect(arena: var LayoutArena, id: LayoutNodeId) =
  let i = id.toIndex
  var node = arena.nodes[i]
  if node.aspectRatio > 0.0:
    if node.width.kind != lskFixed and node.height.kind == lskFixed:
      node.rect.w = clampSize(max(0.0, node.rect.h) * node.aspectRatio, node.width)
    elif node.height.kind != lskFixed and node.rect.w > 0.0:
      node.rect.h = clampSize(node.rect.w / node.aspectRatio, node.height)
      node.intrinsicMin.h = max(node.intrinsicMin.h, node.rect.h)
      node.intrinsicPref.h = max(node.intrinsicPref.h, node.rect.h)
    arena.nodes[i] = node

  for childId in arena.children(arena.nodes[i]):
    arena.applyResolvedAspect(childId)

func pointOffset(r: Rect, point: LayoutAttachPoint): Size =
  case point
  of lapTopLeft:
    size(0, 0)
  of lapTopCenter:
    size(r.w * 0.5, 0)
  of lapTopRight:
    size(r.w, 0)
  of lapCenterLeft:
    size(0, r.h * 0.5)
  of lapCenter:
    size(r.w * 0.5, r.h * 0.5)
  of lapCenterRight:
    size(r.w, r.h * 0.5)
  of lapBottomLeft:
    size(0, r.h)
  of lapBottomCenter:
    size(r.w * 0.5, r.h)
  of lapBottomRight:
    size(r.w, r.h)

func validNode(arena: LayoutArena, id: LayoutNodeId): bool =
  not id.isNull and id.toIndex >= 0 and id.toIndex < arena.nodes.len

func rootRectFor(arena: LayoutArena, id: LayoutNodeId): Rect =
  var cursor = id
  var last = id
  while arena.validNode(cursor):
    last = cursor
    let parent = arena.nodes[cursor.toIndex].parent
    if parent.isNull:
      break
    cursor = parent
  if arena.validNode(last):
    arena.nodes[last.toIndex].rect
  elif arena.nodes.len > 0:
    arena.nodes[0].rect
  else:
    rect(0, 0, 0, 0)

proc clampToRoot(child: var LayoutNode, root: Rect, pad: float) =
  let
    pad = max(pad, 0.0)
    minX = root.x + pad
    minY = root.y + pad
    maxX = root.x + root.w - pad
    maxY = root.y + root.h - pad
  if child.rect.x < minX:
    child.rect.x = minX
  elif child.rect.x + child.rect.w > maxX:
    child.rect.x = maxX - child.rect.w
  if child.rect.y < minY:
    child.rect.y = minY
  elif child.rect.y + child.rect.h > maxY:
    child.rect.y = maxY - child.rect.h

proc placeAttachedNode(
    arena: var LayoutArena, child: var LayoutNode, parent: LayoutNode
) =
  let attach = child.placement.attach
  let target =
    case attach.targetKind
    of latParent:
      parent.rect
    of latRoot:
      arena.rootRectFor(parent.id)
    of latNode:
      if arena.validNode(attach.targetNode):
        arena.nodes[attach.targetNode.toIndex].rect
      else:
        arena.reportLayoutError(
          lekMissingAttachTarget,
          child.id,
          child.itemId,
          &"attach target {int32(attach.targetNode)} not found",
        )
        return
  let
    targetOffset = target.pointOffset(attach.targetPoint)
    selfOffset = child.rect.pointOffset(attach.selfPoint)
  child.rect.x = target.x + targetOffset.w - selfOffset.w + attach.offset.w
  child.rect.y = target.y + targetOffset.h - selfOffset.h + attach.offset.h
  if attach.clipToRoot or attach.windowPad > 0.0:
    child.clampToRoot(arena.rootRectFor(parent.id), attach.windowPad)

proc placeChildren(arena: var LayoutArena, id: LayoutNodeId) =
  var parent = arena.nodes[id.toIndex]
  let mainHorizontal = parent.mainIsHorizontal
  let innerMain = max(
    0.0,
    parent.nodeSize.axis(mainHorizontal) - parent.paddingStart(mainHorizontal) -
      parent.paddingEnd(mainHorizontal),
  )
  let innerCross = max(
    0.0,
    parent.nodeSize.axis(not mainHorizontal) - parent.paddingStart(not mainHorizontal) -
      parent.paddingEnd(not mainHorizontal),
  )
  var flowCount = 0
  for childId in arena.children(parent):
    if arena.nodes[childId.toIndex].placement.kind == lpkFlow:
      inc(flowCount)

  let gapCount = max(0, flowCount - 1)
  var contentMain = parent.childGap * gapCount.float
  for childId in arena.children(parent):
    let child = arena.nodes[childId.toIndex]
    if child.placement.kind == lpkFlow:
      contentMain += child.rect.axis(mainHorizontal)

  let extra = max(0.0, innerMain - contentMain)
  var cursor =
    parent.rectStart(mainHorizontal) + parent.paddingStart(mainHorizontal) + (
      case parent.alignMain
      of laStart, laSpaceBetween:
        0.0
      of laCenter:
        extra * 0.5
      of laEnd:
        extra
    )
  let childGap =
    if parent.alignMain == laSpaceBetween and gapCount > 0:
      parent.childGap + extra / gapCount.float
    else:
      parent.childGap

  var contentMainExtent = 0.0
  var contentCrossExtent = 0.0

  for childId in arena.children(parent):
    let childIndex = childId.toIndex
    var child = arena.nodes[childIndex]
    var contributesContent = true

    case child.placement.kind
    of lpkManual:
      child.rect.x = parent.rect.x + child.placement.x
      child.rect.y = parent.rect.y + child.placement.y
    of lpkFollow:
      contributesContent = false
      if not child.placement.target.isNull:
        if not arena.validNode(child.placement.target):
          arena.reportLayoutError(
            lekMissingAttachTarget,
            child.id,
            child.itemId,
            &"follower target {int32(child.placement.target)} not found",
          )
          arena.nodes[childIndex] = child
          continue
        let target = arena.nodes[child.placement.target.toIndex].rect
        let inset = child.placement.followInset
        let insetTarget = rect(
          target.x + inset.left,
          target.y + inset.top,
          max(0.0, target.w - inset.left - inset.right),
          max(0.0, target.h - inset.top - inset.bottom),
        )
        case child.placement.followKind
        of lfkVerticalScrollBar:
          child.rect.x = insetTarget.x + insetTarget.w - child.rect.w
          child.rect.y = insetTarget.y
          child.rect.h = insetTarget.h
        of lfkHorizontalScrollBar:
          child.rect.x = insetTarget.x
          child.rect.y = insetTarget.y + insetTarget.h - child.rect.h
          child.rect.w = insetTarget.w
        of lfkMatchTarget:
          child.rect = insetTarget
        of lfkInsetFixed:
          child.rect.x = insetTarget.x
          child.rect.y = insetTarget.y
        of lfkDropdownPopup:
          let pad = max(child.placement.windowPad, 0.0)
          let
            minX = parent.rect.x + pad
            minY = parent.rect.y + pad
            maxX = parent.rect.x + parent.rect.w - pad
            maxY = parent.rect.y + parent.rect.h - pad
          child.rect.x =
            case child.placement.followAlign
            of haLeft:
              target.x
            of haCenter:
              target.x + target.w * 0.5 - child.rect.w * 0.5
            of haRight:
              target.x + target.w
          child.rect.y = target.y + target.h
          if child.rect.x + child.rect.w > maxX:
            child.rect.x = target.x + target.w - child.rect.w
          if child.rect.y + child.rect.h > maxY:
            child.rect.y = target.y - child.rect.h
          if child.rect.x < minX:
            child.rect.x = minX
          elif child.rect.x + child.rect.w > maxX:
            child.rect.x = maxX - child.rect.w
          if child.rect.y < minY:
            child.rect.y = minY
          elif child.rect.y + child.rect.h > maxY:
            child.rect.y = maxY - child.rect.h
    of lpkAttach:
      contributesContent = false
      arena.placeAttachedNode(child, parent)
    of lpkFlow:
      let crossSize = child.rect.axis(not mainHorizontal)
      let crossExtra = max(0.0, innerCross - crossSize)
      let crossOffset =
        case parent.alignCross
        of lcaStart:
          0.0
        of lcaCenter:
          round(crossExtra * 0.5)
        of lcaEnd:
          crossExtra
        of lcaStretch:
          0.0

      if parent.alignCross == lcaStretch:
        child.rect.setAxis(not mainHorizontal, innerCross)

      child.setRectStart(mainHorizontal, cursor)
      child.setRectStart(
        not mainHorizontal,
        parent.rectStart(not mainHorizontal) + parent.paddingStart(not mainHorizontal) +
          crossOffset,
      )
      cursor += child.rect.axis(mainHorizontal) + childGap

    if contributesContent:
      contentMainExtent = max(
        contentMainExtent,
        child.rectStart(mainHorizontal) - parent.rectStart(mainHorizontal) +
          child.rect.axis(mainHorizontal) + parent.paddingEnd(mainHorizontal),
      )
      contentCrossExtent = max(
        contentCrossExtent,
        child.rectStart(not mainHorizontal) - parent.rectStart(not mainHorizontal) +
          child.rect.axis(not mainHorizontal) + parent.paddingEnd(not mainHorizontal),
      )

      child.rect.x -= parent.scrollOffset.w
      child.rect.y -= parent.scrollOffset.h
    arena.nodes[childIndex] = child
    arena.placeChildren(childId)

  parent.contentSize.setAxis(mainHorizontal, contentMainExtent)
  parent.contentSize.setAxis(not mainHorizontal, contentCrossExtent)
  arena.nodes[id.toIndex].contentSize = parent.contentSize

proc solveLayout*(arena: var LayoutArena, root: LayoutNodeId = LayoutNodeId(0'i32)) =
  if arena.nodes.len == 0 or root.isNull:
    return

  arena.finalizeLayoutChildren()
  arena.measureNode(root)
  arena.resolveAxis(root, horizontal = true)
  arena.wrapTextNodes(root)
  arena.applyResolvedAspect(root)
  arena.refreshFitIntrinsic(root)
  arena.resolveAxis(root, horizontal = false)
  arena.applyResolvedAspect(root)
  arena.placeChildren(root)

proc solveLayout*(
    arena: var LayoutArena, rootBounds: Rect, root: LayoutNodeId = LayoutNodeId(0'i32)
) =
  if arena.nodes.len == 0 or root.isNull:
    return

  arena.nodes[root.toIndex].rect = rootBounds
  arena.solveLayout(root)

func layoutRect*(arena: LayoutArena, id: LayoutNodeId): Rect =
  if id.isNull or id.toIndex < 0 or id.toIndex >= arena.nodes.len:
    rect(0, 0, 0, 0)
  else:
    arena.nodes[id.toIndex].rect

func layoutZIndex*(arena: LayoutArena, id: LayoutNodeId): int =
  if id.isNull or id.toIndex < 0 or id.toIndex >= arena.nodes.len:
    0
  else:
    let node = arena.nodes[id.toIndex]
    if node.placement.kind == lpkAttach: node.placement.attach.zIndex else: 0
