// Three minimal xdg-shell windows for isolated Niri layout integration tests.
#define _GNU_SOURCE
#include <wayland-client.h>
#include "xdg-shell-client-protocol.h"
#include <sys/mman.h>
#include <unistd.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

struct test_window {
    struct wl_surface *surface;
    struct xdg_surface *xdg;
    struct xdg_toplevel *top;
    int width, height;
    uint32_t color;
};
static struct wl_compositor *compositor;
static struct wl_shm *shm;
static struct xdg_wm_base *shell;
static void ping(void *data, struct xdg_wm_base *base, uint32_t serial) {
    (void)data;
    xdg_wm_base_pong(base, serial);
}
static const struct xdg_wm_base_listener shell_listener = {.ping = ping};
static void global(void *data, struct wl_registry *registry, uint32_t name,
                   const char *interface, uint32_t version) {
    (void)data; (void)version;
    if (!strcmp(interface, "wl_compositor"))
        compositor = wl_registry_bind(registry, name, &wl_compositor_interface, 4);
    else if (!strcmp(interface, "wl_shm"))
        shm = wl_registry_bind(registry, name, &wl_shm_interface, 1);
    else if (!strcmp(interface, "xdg_wm_base")) {
        shell = wl_registry_bind(registry, name, &xdg_wm_base_interface, 1);
        xdg_wm_base_add_listener(shell, &shell_listener, NULL);
    }
}
static void removed(void *data, struct wl_registry *registry, uint32_t name) {
    (void)data; (void)registry; (void)name;
}
static const struct wl_registry_listener registry_listener = {global, removed};
static void configure(void *data, struct xdg_toplevel *top, int32_t width,
                      int32_t height, struct wl_array *states) {
    (void)top; (void)states;
    struct test_window *w = data;
    if (width > 0) w->width = width;
    if (height > 0) w->height = height;
}
static void close_window(void *data, struct xdg_toplevel *top) {
    (void)data; (void)top;
    exit(0);
}
static const struct xdg_toplevel_listener top_listener = {
    .configure = configure, .close = close_window,
};
struct allocation {void *data; size_t size;};
static void released(void *data, struct wl_buffer *buffer) {
    struct allocation *allocation = data;
    wl_buffer_destroy(buffer);
    munmap(allocation->data, allocation->size);
    free(allocation);
}
static const struct wl_buffer_listener buffer_listener = {.release = released};
static void surface_configure(void *data, struct xdg_surface *surface, uint32_t serial) {
    struct test_window *w = data;
    xdg_surface_ack_configure(surface, serial);
    size_t size = (size_t)w->width * w->height * 4;
    int fd = memfd_create("niri-test", MFD_CLOEXEC);
    if (fd < 0 || ftruncate(fd, size)) exit(2);
    uint32_t *pixels = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (pixels == MAP_FAILED) exit(2);
    for (size_t i = 0; i < size / 4; i++) pixels[i] = w->color;
    struct wl_shm_pool *pool = wl_shm_create_pool(shm, fd, size);
    struct wl_buffer *buffer = wl_shm_pool_create_buffer(pool, 0, w->width, w->height,
                                                       w->width * 4, WL_SHM_FORMAT_XRGB8888);
    struct allocation *allocation = malloc(sizeof(*allocation));
    *allocation = (struct allocation){pixels, size};
    wl_buffer_add_listener(buffer, &buffer_listener, allocation);
    wl_shm_pool_destroy(pool);
    close(fd);
    wl_surface_attach(w->surface, buffer, 0, 0);
    wl_surface_damage_buffer(w->surface, 0, 0, w->width, w->height);
    wl_surface_commit(w->surface);
}
static const struct xdg_surface_listener surface_listener = {.configure = surface_configure};
int main(void) {
    struct wl_display *display = wl_display_connect(NULL);
    if (!display) return 2;
    struct wl_registry *registry = wl_display_get_registry(display);
    wl_registry_add_listener(registry, &registry_listener, NULL);
    wl_display_roundtrip(display);
    if (!compositor || !shm || !shell) return 2;
    struct test_window windows[3] = {0};
    const uint32_t colors[] = {0xffcc3333, 0xff33cc33, 0xff3333cc};
    for (int i = 0; i < 3; i++) {
        struct test_window *w = &windows[i];
        w->width = 500; w->height = 500; w->color = colors[i];
        w->surface = wl_compositor_create_surface(compositor);
        w->xdg = xdg_wm_base_get_xdg_surface(shell, w->surface);
        xdg_surface_add_listener(w->xdg, &surface_listener, w);
        w->top = xdg_surface_get_toplevel(w->xdg);
        xdg_toplevel_add_listener(w->top, &top_listener, w);
        char title[32];
        snprintf(title, sizeof(title), "niri-test-%d", i + 1);
        xdg_toplevel_set_title(w->top, title);
        xdg_toplevel_set_app_id(w->top, title);
        wl_surface_commit(w->surface);
        wl_display_roundtrip(display);
    }
    while (wl_display_dispatch(display) >= 0) {}
    return 0;
}
