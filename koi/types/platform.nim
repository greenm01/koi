import std/options

import nanovg

import koi/rect

when not defined(waylandBackend):
  from glfw as glfwLib import nil
  type
    Window* = glfwLib.Window
    Cursor* = glfwLib.Cursor

else:
  type
    Window* = ref object
    Cursor* = pointer

type ItemId* = int64
