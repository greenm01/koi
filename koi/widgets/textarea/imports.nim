import std/options
import std/tables
import std/unicode
import std/math

import nanovg

import koi/types
import koi/core
import koi/drawing
import koi/layout
import koi/rect
import koi/input
import koi/defaults
import koi/internal/algorithms
import koi/widgets/common
import koi/widgets/scrollbar
import koi/utils

const
  TextVertAlignFactor = 0.55
  TextAreaScrollRowsPerTick = 3.0

# textArea()
