#define _GNU_SOURCE

#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <time.h>
#include <unistd.h>

#include <wayland-client.h>

#include "xdg-shell-client-protocol.h"

struct app_state {
	struct wl_display *display;
	struct wl_registry *registry;
	struct wl_compositor *compositor;
	struct wl_shm *shm;
	struct xdg_wm_base *wm_base;
	struct wl_surface *surface;
	struct xdg_surface *xdg_surface;
	struct xdg_toplevel *toplevel;
	struct wl_buffer *buffer;
	void *shm_data;
	size_t shm_size;
	int width;
	int height;
	uint32_t configure_serial;
	bool configured;
	bool running;
	bool buffer_released;
};

static const char *safe_cstr(const char *s)
{
	return s ? s : "(null)";
}

static void xdg_wm_base_ping(void *data, struct xdg_wm_base *wm_base, uint32_t serial)
{
	(void)data;
	xdg_wm_base_pong(wm_base, serial);
}

static const struct xdg_wm_base_listener xdg_wm_base_listener = {
	.ping = xdg_wm_base_ping,
};

static void die(const char *what)
{
	fprintf(stderr, "%s: %s\n", what, strerror(errno));
	exit(1);
}

static void die_wayland(const char *what)
{
	fprintf(stderr, "%s\n", what);
	exit(1);
}

static uint64_t now_ms(void)
{
	struct timespec ts;
	if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0) {
		die("clock_gettime");
	}
	return (uint64_t)ts.tv_sec * 1000u + (uint64_t)ts.tv_nsec / 1000000u;
}

static void fill_red(struct app_state *app)
{
	uint32_t *pixels = (uint32_t *)app->shm_data;
	const size_t count = (size_t)app->width * (size_t)app->height;
	for (size_t i = 0; i < count; i++) {
		pixels[i] = 0x00FF0000u;
	}
}

static void buffer_release(void *data, struct wl_buffer *buffer)
{
	struct app_state *app = data;
	(void)buffer;
	app->buffer_released = true;
	printf("DIAG WAYLAND_SHM buffer_release buffer=%p\n", (void *)buffer);
	fflush(stdout);
}

static const struct wl_buffer_listener buffer_listener = {
	.release = buffer_release,
};

static void xdg_toplevel_configure(void *data, struct xdg_toplevel *xdg_toplevel, int32_t width, int32_t height, struct wl_array *states)
{
	struct app_state *app = data;
	(void)xdg_toplevel;
	(void)states;
	if (width > 0) {
		app->width = width;
	}
	if (height > 0) {
		app->height = height;
	}
	printf("DIAG WAYLAND_SHM toplevel_configure width=%d height=%d\n", width, height);
	fflush(stdout);
}

static void xdg_toplevel_close(void *data, struct xdg_toplevel *xdg_toplevel)
{
	struct app_state *app = data;
	(void)xdg_toplevel;
	app->running = false;
	printf("DIAG WAYLAND_SHM toplevel_close\n");
	fflush(stdout);
}

static void xdg_toplevel_configure_bounds(void *data, struct xdg_toplevel *xdg_toplevel, int32_t width, int32_t height)
{
	(void)data;
	(void)xdg_toplevel;
	printf("DIAG WAYLAND_SHM toplevel_configure_bounds width=%d height=%d\n", width, height);
	fflush(stdout);
}

static void xdg_toplevel_wm_capabilities(void *data, struct xdg_toplevel *xdg_toplevel, struct wl_array *capabilities)
{
	(void)data;
	(void)xdg_toplevel;
	printf("DIAG WAYLAND_SHM toplevel_wm_capabilities size=%zu\n", capabilities->size);
	fflush(stdout);
}

static const struct xdg_toplevel_listener xdg_toplevel_listener = {
	.configure = xdg_toplevel_configure,
	.close = xdg_toplevel_close,
	.configure_bounds = xdg_toplevel_configure_bounds,
	.wm_capabilities = xdg_toplevel_wm_capabilities,
};

static void xdg_surface_configure(void *data, struct xdg_surface *xdg_surface, uint32_t serial)
{
	struct app_state *app = data;
	xdg_surface_ack_configure(xdg_surface, serial);
	app->configure_serial = serial;
	app->configured = true;
	printf("DIAG WAYLAND_SHM surface_configure serial=%u\n", serial);
	fflush(stdout);
}

static const struct xdg_surface_listener xdg_surface_listener = {
	.configure = xdg_surface_configure,
};

static void registry_global(void *data, struct wl_registry *registry, uint32_t name, const char *interface, uint32_t version)
{
	struct app_state *app = data;
	if (strcmp(interface, wl_compositor_interface.name) == 0) {
		app->compositor = wl_registry_bind(registry, name, &wl_compositor_interface, version < 4 ? version : 4);
	} else if (strcmp(interface, wl_shm_interface.name) == 0) {
		app->shm = wl_registry_bind(registry, name, &wl_shm_interface, version < 1 ? version : 1);
	} else if (strcmp(interface, xdg_wm_base_interface.name) == 0) {
		app->wm_base = wl_registry_bind(registry, name, &xdg_wm_base_interface, version < 7 ? version : 7);
		xdg_wm_base_add_listener(app->wm_base, &xdg_wm_base_listener, app);
	}
	(void)version;
}

static void registry_global_remove(void *data, struct wl_registry *registry, uint32_t name)
{
	(void)data;
	(void)registry;
	(void)name;
}

static const struct wl_registry_listener registry_listener = {
	.global = registry_global,
	.global_remove = registry_global_remove,
};

static void create_buffer(struct app_state *app)
{
	if (app->buffer) {
		wl_buffer_destroy(app->buffer);
		app->buffer = NULL;
	}
	if (app->shm_data) {
		munmap(app->shm_data, app->shm_size);
		app->shm_data = NULL;
	}

	const int stride = app->width * 4;
	app->shm_size = (size_t)stride * (size_t)app->height;
	char name[128];
	snprintf(name, sizeof(name), "/native-wayland-shm-%ld-%ld", (long)getpid(), (long)time(NULL));
	int fd = shm_open(name, O_CREAT | O_EXCL | O_RDWR, 0600);
	if (fd < 0) {
		die("shm_open");
	}
	(void)shm_unlink(name);
	if (ftruncate(fd, (off_t)app->shm_size) != 0) {
		die("ftruncate");
	}
	app->shm_data = mmap(NULL, app->shm_size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
	if (app->shm_data == MAP_FAILED) {
		die("mmap");
	}
	fill_red(app);
	app->buffer_released = false;
	struct wl_shm_pool *pool = wl_shm_create_pool(app->shm, fd, (int)app->shm_size);
	if (!pool) {
		die_wayland("wl_shm_create_pool failed");
	}
	app->buffer = wl_shm_pool_create_buffer(pool, 0, app->width, app->height, stride, WL_SHM_FORMAT_XRGB8888);
	wl_shm_pool_destroy(pool);
	close(fd);
	if (!app->buffer) {
		die_wayland("wl_shm_pool_create_buffer failed");
	}
	wl_buffer_add_listener(app->buffer, &buffer_listener, app);
}

static void present_red(struct app_state *app)
{
	wl_surface_attach(app->surface, app->buffer, 0, 0);
	wl_surface_damage_buffer(app->surface, 0, 0, app->width, app->height);
	wl_surface_commit(app->surface);
	if (wl_display_flush(app->display) < 0 && errno != EAGAIN) {
		die("wl_display_flush");
	}
}

static void dispatch_until_configured(struct app_state *app)
{
	while (!app->configured) {
		if (wl_display_roundtrip(app->display) < 0) {
			die_wayland("wl_display_roundtrip failed while waiting for configure");
		}
	}
}

int main(void)
{
	struct app_state app = {
		.width = 640,
		.height = 480,
		.running = true,
	};

	printf("DIAG WAYLAND_SHM enter\n");

	const char *runtime_dir = getenv("XDG_RUNTIME_DIR");
	const char *wayland_display = getenv("WAYLAND_DISPLAY");
	const char *swaysock = getenv("SWAYSOCK");
	printf("DIAG WAYLAND_SHM XDG_RUNTIME_DIR=%s\n", safe_cstr(runtime_dir));
	printf("DIAG WAYLAND_SHM WAYLAND_DISPLAY=%s\n", safe_cstr(wayland_display));
	printf("DIAG WAYLAND_SHM SWAYSOCK=%s\n", safe_cstr(swaysock));

	app.display = wl_display_connect(NULL);
	if (!app.display) {
		die_wayland("wl_display_connect failed");
	}

	app.registry = wl_display_get_registry(app.display);
	if (!app.registry) {
		die_wayland("wl_display_get_registry failed");
	}
	wl_registry_add_listener(app.registry, &registry_listener, &app);
	if (wl_display_roundtrip(app.display) < 0) {
		die_wayland("initial wl_display_roundtrip failed");
	}
	if (!app.compositor || !app.shm || !app.wm_base) {
		die_wayland("missing required Wayland globals");
	}

	app.surface = wl_compositor_create_surface(app.compositor);
	if (!app.surface) {
		die_wayland("wl_compositor_create_surface failed");
	}
	app.xdg_surface = xdg_wm_base_get_xdg_surface(app.wm_base, app.surface);
	if (!app.xdg_surface) {
		die_wayland("xdg_wm_base_get_xdg_surface failed");
	}
	xdg_surface_add_listener(app.xdg_surface, &xdg_surface_listener, &app);
	app.toplevel = xdg_surface_get_toplevel(app.xdg_surface);
	if (!app.toplevel) {
		die_wayland("xdg_surface_get_toplevel failed");
	}
	xdg_toplevel_add_listener(app.toplevel, &xdg_toplevel_listener, &app);
	xdg_toplevel_set_title(app.toplevel, "native-wayland-shm-red");
	wl_surface_commit(app.surface);
	if (wl_display_roundtrip(app.display) < 0) {
		die_wayland("roundtrip after window creation failed");
	}
	dispatch_until_configured(&app);

	printf("DIAG WAYLAND_SHM configured serial=%u surface=%p size=%dx%d\n",
		app.configure_serial, (void *)app.surface, app.width, app.height);

	create_buffer(&app);
	printf("DIAG WAYLAND_SHM buffer_created size=%dx%d stride=%d buffer=%p\n",
		app.width, app.height, app.width * 4, (void *)app.buffer);

	const uint64_t start_ms = now_ms();
	const uint64_t duration_ms = 10000;
	unsigned int iteration = 0;
	while (app.running && (now_ms() - start_ms) < duration_ms) {
		fill_red(&app);
		present_red(&app);
		printf("DIAG WAYLAND_SHM iteration=%u elapsed_ms=%llu buffer_released=%d\n",
			iteration + 1,
			(unsigned long long)(now_ms() - start_ms),
			app.buffer_released ? 1 : 0);
		fflush(stdout);
		if (wl_display_roundtrip(app.display) < 0) {
			die_wayland("wl_display_roundtrip failed during present loop");
		}
		iteration++;
		usleep(150000);
	}

	printf("DIAG WAYLAND_SHM exit\n");
	if (app.surface) {
		wl_surface_attach(app.surface, NULL, 0, 0);
		wl_surface_commit(app.surface);
		wl_display_flush(app.display);
	}
	if (app.buffer) {
		wl_buffer_destroy(app.buffer);
	}
	if (app.toplevel) {
		xdg_toplevel_destroy(app.toplevel);
	}
	if (app.xdg_surface) {
		xdg_surface_destroy(app.xdg_surface);
	}
	if (app.surface) {
		wl_surface_destroy(app.surface);
	}
	if (app.wm_base) {
		xdg_wm_base_destroy(app.wm_base);
	}
	if (app.shm) {
		wl_shm_destroy(app.shm);
	}
	if (app.registry) {
		wl_registry_destroy(app.registry);
	}
	if (app.display) {
		wl_display_disconnect(app.display);
	}
	return 0;
}
