type TextRow* = object
  startPos*: Natural
  startBytePos*: Natural
  endPos*: Natural
  endBytePos*: Natural
  nextRowPos*: int
  nextRowBytePos*: int
  width*: float

type ListViewRange* = object
  first*: Natural
  last*: Natural
  startY*: float
  contentHeight*: float
