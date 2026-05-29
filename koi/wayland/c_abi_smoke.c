#include "koi_wayland.h"

static void on_close(void* userdata) {
  (void)userdata;
}

static void on_key_repeat(uint32_t sym, uint32_t mods, void* userdata) {
  (void)sym;
  (void)mods;
  (void)userdata;
}

int main(void) {
  if ((KOI_WAYLAND_MOD_SHIFT | KOI_WAYLAND_MOD_CTRL |
       KOI_WAYLAND_MOD_ALT | KOI_WAYLAND_MOD_SUPER) != 15u) {
    return 1;
  }
  if (KOI_WAYLAND_CURSOR_DEFAULT == KOI_WAYLAND_CURSOR_TEXT) {
    return 1;
  }

  KoiWaylandCallbacks callbacks = {0};
  callbacks.on_close = on_close;
  callbacks.on_key_repeat = on_key_repeat;
  koi_wayland_set_callbacks(0, &callbacks);

  KoiWaylandDisplay* display = koi_wayland_init();
  if (display == 0) {
    return 0;
  }

  koi_wayland_poll_events(display);
  (void)koi_wayland_get_wl_display(display);

  KoiWaylandWindow* window =
      koi_wayland_create_window(display, 320, 240, "Koi Wayland ABI Smoke");
  if (window != 0) {
    koi_wayland_set_callbacks(window, &callbacks);
    koi_wayland_set_title(window, "Koi Wayland ABI Smoke");
    koi_wayland_set_size(window, 320, 240);
    koi_wayland_set_cursor_shape(window, KOI_WAYLAND_CURSOR_DEFAULT);
    (void)koi_wayland_window_should_close(window);
    (void)koi_wayland_get_wl_surface(window);
    if (koi_wayland_get_width(window) == 0 ||
        koi_wayland_get_height(window) == 0) {
      koi_wayland_destroy_window(window);
      koi_wayland_destroy(display);
      return 1;
    }
    koi_wayland_destroy_window(window);
  }

  koi_wayland_destroy(display);
  return 0;
}
