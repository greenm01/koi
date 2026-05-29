#ifndef KOI_WAYLAND_H
#define KOI_WAYLAND_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct KoiWaylandDisplay KoiWaylandDisplay;
typedef struct KoiWaylandWindow KoiWaylandWindow;

typedef struct {
  void (*on_close)(void* userdata);
  void (*on_resize)(uint32_t w, uint32_t h, void* userdata);
  void (*on_key_down)(uint32_t sym, uint32_t mods, void* userdata);
  void (*on_key_up)(uint32_t sym, uint32_t mods, void* userdata);
  void (*on_mouse_move)(double x, double y, void* userdata);
  void (*on_mouse_button)(uint32_t btn, bool pressed, void* userdata);
  void (*on_scroll)(double dx, double dy, void* userdata);
  void (*on_scale)(double scale, void* userdata);
  void* userdata;
} KoiWaylandCallbacks;

KoiWaylandDisplay* koi_wayland_init(void);
KoiWaylandWindow* koi_wayland_create_window(
    KoiWaylandDisplay* display, uint32_t w, uint32_t h, const char* title);
void koi_wayland_set_callbacks(
    KoiWaylandWindow* window, const KoiWaylandCallbacks* callbacks);
void koi_wayland_poll_events(KoiWaylandDisplay* display);
void* koi_wayland_get_wl_display(KoiWaylandDisplay* display);
void* koi_wayland_get_wl_surface(KoiWaylandWindow* window);
uint32_t koi_wayland_get_width(KoiWaylandWindow* window);
uint32_t koi_wayland_get_height(KoiWaylandWindow* window);
void koi_wayland_set_title(KoiWaylandWindow* window, const char* title);
void koi_wayland_set_size(KoiWaylandWindow* window, uint32_t w, uint32_t h);
void koi_wayland_destroy_window(KoiWaylandWindow* window);
void koi_wayland_destroy(KoiWaylandDisplay* display);

#ifdef __cplusplus
}
#endif

#endif
