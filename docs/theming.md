# Koi Theming Notes

This note records current theming policy so style additions stay consistent
across the NanoVG/OpenGL path, the WebGPU renderer, and native-window work.

## Style Model

Koi styles are plain value objects. Widgets take a `*Style` object, usually
defaulted from `koi/defaults.nim`, and draw code reads concrete colors, metrics,
and label styles from that object. Custom widget draw procs are the extension
point when an application needs visuals outside the built-in style surface.

Core style fields should meet three tests:

- They describe widget behavior or appearance in renderer-neutral terms.
- Every supported renderer can implement them with comparable fidelity.
- They are common enough that carrying them on the public style object is worth
  the API weight.

## Effects Policy

### Shadows

Shadows stay in core. `ShadowStyle` already exists and is used by popups,
dropdowns, and dialogs. It is expressed in renderer-neutral geometry and color
terms: offsets, size offsets, feather, corner radius, and color.

Future shadow work should improve coverage and consistency, not replace the
concept with renderer-specific hooks.

### Gradients

Gradients should not be added piecemeal to individual widget styles. A gradient
field on one widget would either be under-specified or would leak renderer
details into the public API.

If Koi needs gradients, add a shared paint abstraction first, then let renderer
backends map that abstraction to their native implementation. Until then,
applications that need gradients should use custom draw procs.

### Text Shadows

Text shadows should also stay out of core for now. Label drawing currently
models text as stateful colors plus font metrics. Adding text shadow to
`LabelStyle` would expand every text-bearing widget and still needs careful
renderer parity work for clipping, wrapping, and selection overlays.

If text effects become necessary, introduce them as a renderer-neutral
`TextEffectStyle` or a broader text paint abstraction, then apply it consistently
to `LabelStyle`, text fields, text areas, table cells, and menu labels.

## Current Decision

Core Koi keeps:

- Solid colors.
- Renderer-neutral metrics.
- `ShadowStyle` for overlay/frame shadows.

Core Koi defers:

- Gradients.
- Text shadows.
- Renderer-specific blend, blur, or shader effects.

Those deferred effects belong behind a shared paint/text-effect abstraction or
inside application-provided custom draw procs.
