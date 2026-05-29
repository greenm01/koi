# Koi Todo

This file tracks current follow-up work. Historical audit notes were folded down
to the deferred candidates that still look useful.

## Backend And Rendering

- Complete broader Wayland input support, especially keyboard/xkb mapping,
  modifiers, repeat, cursor shape, output scale, and robust close/resize flow.

## Text And Editing

- Replace repeated rune-length scans in text editing with cached rune metadata
  only if profiling shows it matters for real text sizes.

## Layout And Theming

- Finish complete theming coverage, including global theme parameters such as
  font, corner roundness, and colors.
