#ifndef KOI_WAYLAND_H
#define KOI_WAYLAND_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct KoiWaylandDisplay KoiWaylandDisplay;
typedef struct KoiWaylandWindow KoiWaylandWindow;

enum {
  KOI_WAYLAND_MOD_SHIFT = 1u << 0,
  KOI_WAYLAND_MOD_CTRL = 1u << 1,
  KOI_WAYLAND_MOD_ALT = 1u << 2,
  KOI_WAYLAND_MOD_SUPER = 1u << 3,
};

typedef enum {
  KOI_WAYLAND_CURSOR_DEFAULT = 1,
  KOI_WAYLAND_CURSOR_TEXT = 2,
  KOI_WAYLAND_CURSOR_CROSSHAIR = 3,
  KOI_WAYLAND_CURSOR_POINTER = 4,
  KOI_WAYLAND_CURSOR_RESIZE_EW = 5,
  KOI_WAYLAND_CURSOR_RESIZE_NS = 6,
  KOI_WAYLAND_CURSOR_RESIZE_NWSE = 7,
  KOI_WAYLAND_CURSOR_RESIZE_NESW = 8,
  KOI_WAYLAND_CURSOR_RESIZE_ALL = 9,
} KoiWaylandCursorShape;

typedef struct {
  void (*on_close)(void* userdata);
  void (*on_resize)(uint32_t w, uint32_t h, void* userdata);
  void (*on_key_down)(uint32_t sym, uint32_t mods, void* userdata);
  void (*on_key_repeat)(uint32_t sym, uint32_t mods, void* userdata);
  void (*on_key_up)(uint32_t sym, uint32_t mods, void* userdata);
  void (*on_char)(uint32_t codepoint, void* userdata);
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
bool koi_wayland_window_should_close(KoiWaylandWindow* window);
void koi_wayland_set_title(KoiWaylandWindow* window, const char* title);
void koi_wayland_set_size(KoiWaylandWindow* window, uint32_t w, uint32_t h);
void koi_wayland_set_cursor_shape(
    KoiWaylandWindow* window, KoiWaylandCursorShape shape);
void koi_wayland_destroy_window(KoiWaylandWindow* window);
void koi_wayland_destroy(KoiWaylandDisplay* display);

#ifdef __cplusplus
}
#endif

#endif
