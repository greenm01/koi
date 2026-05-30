when not defined(waylandBackend):
  proc koiModifierKeys(mods: set[glfwLib.ModifierKey]): set[ModifierKey] =
    if glfwLib.mkShift in mods:
      result.incl(mkShift)
    if glfwLib.mkCtrl in mods:
      result.incl(mkCtrl)
    if glfwLib.mkAlt in mods:
      result.incl(mkAlt)
    if glfwLib.mkSuper in mods:
      result.incl(mkSuper)
    if glfwLib.mkCapsLock in mods:
      result.incl(mkCapsLock)
    if glfwLib.mkNumLock in mods:
      result.incl(mkNumLock)

  proc installGlfwPlatformHooks*() =
    setPlatformHooks(
      PlatformHooks(
        windowSize: proc(): tuple[w, h: float] =
          let (w, h) = glfwLib.size(activeWindow())
          (w.float, h.float),
        surfaceSize: proc(): tuple[w, h: float] =
          let (w, h) = glfwLib.framebufferSize(activeWindow())
          (w.float, h.float),
        contentScale: proc(): tuple[x, y: float] =
          let (x, y) = glfwLib.contentScale(activeWindow())
          (x.float, y.float),
        cursorPos: proc(): tuple[x, y: float] =
          let (x, y) = glfwLib.cursorPos(activeWindow())
          (x.float, y.float),
        setCursorPos: proc(x, y: float) =
          glfwLib.`cursorPos=`(activeWindow(), (x, y)),
        setCursorShape: proc(shape: CursorShape) =
          var c: Cursor
          if shape == csArrow:
            c = g_cursorArrow
          elif shape == csIBeam:
            c = g_cursorIBeam
          elif shape == csCrosshair:
            c = g_cursorCrosshair
          elif shape == csHand:
            c = g_cursorHand
          elif shape == csResizeEW:
            c = g_cursorResizeEW
          elif shape == csResizeNS:
            c = g_cursorResizeNS
          elif shape == csResizeNWSE:
            c = g_cursorResizeNWSE
          elif shape == csResizeNESW:
            c = g_cursorResizeNESW
          elif shape == csResizeAll:
            c = g_cursorResizeAll
          glfwLib.`cursor=`(activeWindow(), c),
        setCursorMode: proc(mode: PlatformCursorMode) =
          glfwLib.`cursorMode=`(
            activeWindow(),
            case mode
            of pcmNormal: glfwLib.cmNormal
            of pcmHidden: glfwLib.cmHidden
            of pcmDisabled: glfwLib.cmDisabled
            ,
          ),
        clipboardGet: proc(): string =
          $glfwLib.clipboardString(activeWindow()),
        clipboardSet: proc(text: string) =
          glfwLib.`clipboardString=`(activeWindow(), text),
      )
    )
