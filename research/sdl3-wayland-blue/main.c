#include <SDL3/SDL.h>
#include <SDL3/SDL_hints.h>
#include <SDL3/SDL_render.h>
#include <SDL3/SDL_surface.h>
#include <SDL3/SDL_video.h>

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static const char *safe_cstr(const char *s)
{
	return s ? s : "(null)";
}

static void die_sdl(const char *what)
{
	fprintf(stderr, "%s: %s\n", what, SDL_GetError());
	SDL_Quit();
	exit(1);
}

static void print_window_flags(SDL_WindowFlags flags)
{
	printf("DIAG SDL_PRESENT window_flags=0x%llx\n", (unsigned long long)flags);
}

static const char *get_backend_mode(void)
{
	const char *backend = getenv("SDL_BLUE_BACKEND");
	if (!backend || !backend[0]) {
		return "surface";
	}
	if (strcmp(backend, "surface") == 0 || strcmp(backend, "software-renderer") == 0) {
		return backend;
	}
	fprintf(stderr, "invalid SDL_BLUE_BACKEND=%s (expected surface or software-renderer)\n", backend);
	exit(1);
}

static void log_window_state(SDL_Window *window, const char *tag, SDL_Surface *surface)
{
	int logical_w = 0;
	int logical_h = 0;
	int pixel_w = 0;
	int pixel_h = 0;
	Uint32 window_id = SDL_GetWindowID(window);
	(void)SDL_GetWindowSize(window, &logical_w, &logical_h);
	(void)SDL_GetWindowSizeInPixels(window, &pixel_w, &pixel_h);
	printf("DIAG SDL_PRESENT %s event window_id=%u logical_size=%dx%d pixel_size=%dx%d surface=%p",
		tag, window_id, logical_w, logical_h, pixel_w, pixel_h, (void *)surface);
	if (surface) {
		printf(" surface_size=%dx%d", surface->w, surface->h);
	}
	printf("\n");
}

static bool handle_window_event(SDL_Window *window, SDL_Event *event, SDL_Surface **surface, const char *backend, Uint64 start_ms, bool *logged_first_two_seconds)
{
	switch (event->type) {
	case SDL_EVENT_WINDOW_SHOWN:
		log_window_state(window, "window_shown", *surface);
		break;
	case SDL_EVENT_WINDOW_EXPOSED:
		log_window_state(window, "window_exposed", *surface);
		break;
	case SDL_EVENT_WINDOW_RESIZED:
		log_window_state(window, "window_resized", *surface);
		break;
	case SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED:
		log_window_state(window, "window_pixel_size_changed", *surface);
		break;
	case SDL_EVENT_WINDOW_FOCUS_GAINED:
		log_window_state(window, "window_focus_gained", *surface);
		break;
	case SDL_EVENT_WINDOW_FOCUS_LOST:
		log_window_state(window, "window_focus_lost", *surface);
		break;
	case SDL_EVENT_WINDOW_MOVED:
		log_window_state(window, "window_moved", *surface);
		break;
	default:
		break;
	}

	if (backend && strcmp(backend, "surface") == 0) {
		if (event->type == SDL_EVENT_WINDOW_EXPOSED ||
		    event->type == SDL_EVENT_WINDOW_RESIZED ||
		    event->type == SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED ||
		    event->type == SDL_EVENT_WINDOW_SHOWN) {
			SDL_Surface *new_surface = SDL_GetWindowSurface(window);
			printf("DIAG SDL_PRESENT surface_reacquire old=%p new=%p\n", (void *)*surface, (void *)new_surface);
			if (new_surface) {
				printf("DIAG SDL_PRESENT surface_size=%dx%d\n", new_surface->w, new_surface->h);
			} else {
				printf("DIAG SDL_PRESENT surface_reacquire_error=%s\n", SDL_GetError());
			}
			*surface = new_surface;
		}
	}

	if (!*logged_first_two_seconds && (SDL_GetTicks() - start_ms) < 2000) {
		*logged_first_two_seconds = true;
		log_window_state(window, "first_two_seconds", *surface);
	}

	return true;
}

static void print_display_info(SDL_DisplayID display_id);

static void print_display_ids(SDL_DisplayID *display_ids, int display_count)
{
	for (int i = 0; i < display_count; i++) {
		const SDL_DisplayID display_id = display_ids ? display_ids[i] : 0;
		printf("DIAG SDL_PRESENT display_index=%d display_id=%u display_name=%s\n",
			i, (unsigned)display_id, safe_cstr(SDL_GetDisplayName(display_id)));
		print_display_info(display_id);
	}
}

static void print_display_info(SDL_DisplayID display_id)
{
	SDL_Rect bounds = {0, 0, 0, 0};
	SDL_Rect usable = {0, 0, 0, 0};
	const SDL_DisplayMode *mode = SDL_GetCurrentDisplayMode(display_id);
	const float scale = SDL_GetDisplayContentScale(display_id);

	if (!SDL_GetDisplayBounds(display_id, &bounds)) {
		printf("DIAG SDL_PRESENT display_bounds=<error>\n");
	} else {
		printf("DIAG SDL_PRESENT display_bounds=%dx%d+%d+%d\n", bounds.w, bounds.h, bounds.x, bounds.y);
	}

	if (!SDL_GetDisplayUsableBounds(display_id, &usable)) {
		printf("DIAG SDL_PRESENT usable_bounds=<error>\n");
	} else {
		printf("DIAG SDL_PRESENT usable_bounds=%dx%d+%d+%d\n", usable.w, usable.h, usable.x, usable.y);
	}

	if (mode) {
		printf("DIAG SDL_PRESENT current_mode=%dx%d@%.3f pixel_density=%.3f\n",
			mode->w, mode->h, mode->refresh_rate, mode->pixel_density);
	} else {
		printf("DIAG SDL_PRESENT current_mode=<null>\n");
	}

	printf("DIAG SDL_PRESENT display_content_scale=%.3f\n", scale);
}

static void print_all_displays(void)
{
	int display_count = 0;
	SDL_DisplayID *display_ids = SDL_GetDisplays(&display_count);
	printf("DIAG SDL_PRESENT display_count=%d\n", display_count);
	print_display_ids(display_ids, display_count);
	SDL_free(display_ids);
}

static void run_surface_blue(SDL_Window *window, SDL_Surface *surface, Uint64 start_ms, Uint64 duration_ms)
{
	const Uint32 blue = SDL_MapSurfaceRGB(surface, 0, 0, 255);
	unsigned int iteration = 0;
	int first_fill_result = 0;
	int first_update_result = 0;
	bool logged_first_two_seconds = false;
	const char *backend = get_backend_mode();

	while ((SDL_GetTicks() - start_ms) < duration_ms) {
		SDL_Event event;
		while (SDL_PollEvent(&event)) {
			if (event.type == SDL_EVENT_QUIT) {
				return;
			}
			handle_window_event(window, &event, &surface, backend, start_ms, &logged_first_two_seconds);
		}

		if (!surface) {
			surface = SDL_GetWindowSurface(window);
			if (!surface) {
				fprintf(stderr, "SDL_GetWindowSurface: %s\n", SDL_GetError());
				return;
			}
			printf("DIAG SDL_PRESENT surface_reacquire old=<null> new=%p surface_size=%dx%d\n",
				(void *)surface, surface->w, surface->h);
		}

		if (!SDL_FillSurfaceRect(surface, NULL, blue)) {
			fprintf(stderr, "SDL_FillSurfaceRect: %s\n", SDL_GetError());
			return;
		}
		if (iteration == 0) {
			first_fill_result = 1;
			printf("DIAG SDL_PRESENT first_fill_result=%d\n", first_fill_result);
		}

		if (!SDL_UpdateWindowSurface(window)) {
			fprintf(stderr, "SDL_UpdateWindowSurface: %s\n", SDL_GetError());
			return;
		}
		if (iteration == 0) {
			first_update_result = 1;
			printf("DIAG SDL_PRESENT first_update_result=%d\n", first_update_result);
		}

		iteration++;
		if (iteration == 1 || (iteration % 10) == 0) {
			const Uint64 elapsed_ms = SDL_GetTicks() - start_ms;
			printf("DIAG SDL_PRESENT iteration=%u elapsed_ms=%llu\n",
				iteration, (unsigned long long)elapsed_ms);
			fflush(stdout);
		}

		SDL_Delay(150);
	}
}

static void run_renderer_blue(SDL_Window *window, SDL_Renderer *renderer, Uint64 start_ms, Uint64 duration_ms)
{
	unsigned int iteration = 0;
	int first_fill_result = 0;
	int first_update_result = 0;
	bool logged_first_two_seconds = false;

	while ((SDL_GetTicks() - start_ms) < duration_ms) {
		SDL_Event event;
		while (SDL_PollEvent(&event)) {
			if (event.type == SDL_EVENT_QUIT) {
				return;
			}
			if (!logged_first_two_seconds && (SDL_GetTicks() - start_ms) < 2000) {
				logged_first_two_seconds = true;
				log_window_state(window, "first_two_seconds", NULL);
			}
		}

		if (!SDL_SetRenderDrawColor(renderer, 0, 0, 255, 255)) {
			fprintf(stderr, "SDL_SetRenderDrawColor: %s\n", SDL_GetError());
			return;
		}
		if (iteration == 0) {
			first_fill_result = 1;
			printf("DIAG SDL_PRESENT first_fill_result=%d\n", first_fill_result);
		}

		if (!SDL_RenderClear(renderer)) {
			fprintf(stderr, "SDL_RenderClear: %s\n", SDL_GetError());
			return;
		}
		if (!SDL_RenderPresent(renderer)) {
			fprintf(stderr, "SDL_RenderPresent: %s\n", SDL_GetError());
			return;
		}
		if (iteration == 0) {
			first_update_result = 1;
			printf("DIAG SDL_PRESENT first_update_result=%d\n", first_update_result);
		}

		iteration++;
		if (iteration == 1 || (iteration % 10) == 0) {
			const Uint64 elapsed_ms = SDL_GetTicks() - start_ms;
			printf("DIAG SDL_PRESENT iteration=%u elapsed_ms=%llu\n",
				iteration, (unsigned long long)elapsed_ms);
			fflush(stdout);
		}

		SDL_Delay(150);
	}
}

int main(int argc, char **argv)
{
	(void)argc;
	(void)argv;

	printf("DIAG SDL_PRESENT enter\n");

	if (!SDL_SetHint(SDL_HINT_VIDEO_DRIVER, "wayland")) {
		fprintf(stderr, "warning: SDL_SetHint(SDL_HINT_VIDEO_DRIVER) failed\n");
	}

	if (!SDL_Init(SDL_INIT_VIDEO)) {
		die_sdl("SDL_Init(SDL_INIT_VIDEO)");
	}

	printf("DIAG SDL_PRESENT video_driver=%s\n", safe_cstr(SDL_GetCurrentVideoDriver()));
	print_all_displays();

	SDL_DisplayID display_id = SDL_GetPrimaryDisplay();
	int display_count = 0;
	SDL_DisplayID *display_ids = SDL_GetDisplays(&display_count);
	SDL_Rect display_bounds = {0, 0, 0, 0};
	if (display_id == 0 && display_ids && display_count > 0) {
		display_id = display_ids[0];
	}
	SDL_free(display_ids);
	if (display_id != 0) {
		if (!SDL_GetDisplayBounds(display_id, &display_bounds)) {
			die_sdl("SDL_GetDisplayBounds");
		}
	}

	const int win_w = display_bounds.w > 0 ? display_bounds.w : 640;
	const int win_h = display_bounds.h > 0 ? display_bounds.h : 480;

	SDL_WindowFlags flags = SDL_WINDOW_FULLSCREEN | SDL_WINDOW_BORDERLESS;
	SDL_Window *window = SDL_CreateWindow("sdl3-wayland-blue", win_w, win_h, flags);
	if (!window) {
		die_sdl("SDL_CreateWindow");
	}

	SDL_ShowWindow(window);

	int window_logical_w = 0;
	int window_logical_h = 0;
	int window_pixel_w = 0;
	int window_pixel_h = 0;
	if (!SDL_GetWindowSize(window, &window_logical_w, &window_logical_h)) {
		die_sdl("SDL_GetWindowSize");
	}
	if (!SDL_GetWindowSizeInPixels(window, &window_pixel_w, &window_pixel_h)) {
		die_sdl("SDL_GetWindowSizeInPixels");
	}

	printf("DIAG SDL_PRESENT window_logical_size=%dx%d\n", window_logical_w, window_logical_h);
	printf("DIAG SDL_PRESENT window_pixel_size=%dx%d\n", window_pixel_w, window_pixel_h);
	print_window_flags(SDL_GetWindowFlags(window));

	const char *backend = get_backend_mode();
	printf("DIAG SDL_PRESENT backend=%s\n", backend);

	SDL_Surface *surface = NULL;
	SDL_Renderer *renderer = NULL;
	if (strcmp(backend, "surface") == 0) {
		surface = SDL_GetWindowSurface(window);
		printf("DIAG SDL_PRESENT presentation_mode=surface\n");
		if (!surface) {
			die_sdl("SDL_GetWindowSurface");
		}
		printf("DIAG SDL_PRESENT surface_size=%dx%d\n", surface->w, surface->h);
	} else {
		printf("DIAG SDL_PRESENT presentation_mode=renderer\n");
		SDL_ClearError();
		renderer = SDL_CreateRenderer(window, "software");
		if (!renderer) {
			die_sdl("SDL_CreateRenderer");
		}
		printf("DIAG SDL_PRESENT renderer_name=%s\n", safe_cstr(SDL_GetRendererName(renderer)));
	}

	const Uint64 start_ms = SDL_GetTicks();
	const Uint64 duration_ms = 20000;
	if (strcmp(backend, "surface") == 0) {
		run_surface_blue(window, surface, start_ms, duration_ms);
	} else {
		run_renderer_blue(window, renderer, start_ms, duration_ms);
	}

	printf("DIAG SDL_PRESENT exit\n");
	fflush(stdout);

	if (renderer) {
		SDL_DestroyRenderer(renderer);
	}
	SDL_DestroyWindow(window);
	SDL_Quit();
	return 0;
}
