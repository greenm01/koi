#include "koi_wayland.h"

static void on_close(void* userdata) {
  (void)userdata;
}

int main(void) {
  KoiWaylandCallbacks callbacks = {0};
  callbacks.on_close = on_close;
  koi_wayland_set_callbacks(0, &callbacks);

  KoiWaylandDisplay* display = koi_wayland_init();
  if (display == 0) {
    return 0;
  }

  koi_wayland_poll_events(display);
  (void)koi_wayland_get_wl_display(display);
  koi_wayland_destroy(display);
  return 0;
}
