# Koi Todo

This file tracks current follow-up work. Historical audit notes were folded down
to the deferred candidates that still look useful.

## Backend And Rendering

- Complete remaining Wayland polish: cursor shape and robust close/resize flow.

## Text And Editing

- Profile real text-editing workloads before adding persistent rune metadata
  caches beyond the current per-operation word-navigation rune sequence.

## Layout And Theming

- Audit remaining hard-coded widget colors and promote any broadly useful values
  to style fields or global theme parameters.
