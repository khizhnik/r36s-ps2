#include <SDL3/SDL.h>
#include <SDL3/SDL_hints.h>
#include <SDL3/SDL_version.h>
#include <SDL3/SDL_video.h>

#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES2/gl2.h>

#include <wayland-client.h>
#include <wayland-egl.h>

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>

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

static void die_egl(const char *what, EGLDisplay display)
{
    const EGLint err = eglGetError();
    fprintf(stderr, "%s: EGL error 0x%04x\n", what, (unsigned)err);
    if (display != EGL_NO_DISPLAY) {
        fprintf(stderr, "  egl vendor: %s\n", safe_cstr(eglQueryString(display, EGL_VENDOR)));
        fprintf(stderr, "  egl version: %s\n", safe_cstr(eglQueryString(display, EGL_VERSION)));
    }
    SDL_Quit();
    exit(1);
}

static void print_sdl_version(void)
{
    const int linked = SDL_GetVersion();
    printf("SDL compile version: %d.%d.%d\n",
           SDL_MAJOR_VERSION, SDL_MINOR_VERSION, SDL_MICRO_VERSION);
    printf("SDL linked version: %d.%d.%d (raw=%d)\n",
           SDL_VERSIONNUM_MAJOR(linked),
           SDL_VERSIONNUM_MINOR(linked),
           SDL_VERSIONNUM_MICRO(linked),
           linked);
    printf("SDL revision: %s\n", SDL_GetRevision());
}

static void print_gl_info(void)
{
    printf("GL_VENDOR: %s\n", safe_cstr((const char *)glGetString(GL_VENDOR)));
    printf("GL_RENDERER: %s\n", safe_cstr((const char *)glGetString(GL_RENDERER)));
    printf("GL_VERSION: %s\n", safe_cstr((const char *)glGetString(GL_VERSION)));
}

static void sleep_visible_5s(void)
{
    const Uint64 start = SDL_GetTicks();
    while ((SDL_GetTicks() - start) < 5000) {
        SDL_Event event;
        while (SDL_PollEvent(&event)) {
            if (event.type == SDL_EVENT_QUIT) {
                return;
            }
        }
        SDL_Delay(16);
    }
}

static EGLDisplay query_wayland_egl_display(struct wl_display *wl_display)
{
    EGLDisplay egl_display = EGL_NO_DISPLAY;
    PFNEGLGETPLATFORMDISPLAYPROC get_platform_display =
        (PFNEGLGETPLATFORMDISPLAYPROC)eglGetProcAddress("eglGetPlatformDisplay");
    PFNEGLGETPLATFORMDISPLAYEXTPROC get_platform_display_ext =
        (PFNEGLGETPLATFORMDISPLAYEXTPROC)eglGetProcAddress("eglGetPlatformDisplayEXT");

    if (get_platform_display) {
        egl_display = get_platform_display(EGL_PLATFORM_WAYLAND_KHR, wl_display, NULL);
    } else if (get_platform_display_ext) {
        egl_display = get_platform_display_ext(EGL_PLATFORM_WAYLAND_KHR, wl_display, NULL);
    } else {
        egl_display = eglGetDisplay((EGLNativeDisplayType)wl_display);
    }

    return egl_display;
}

static void print_current_egl_diagnostics(void)
{
    EGLDisplay egl_display = eglGetCurrentDisplay();
    if (egl_display == EGL_NO_DISPLAY) {
        fprintf(stderr, "warning: eglGetCurrentDisplay returned no EGLDisplay\n");
        return;
    }

    printf("EGL vendor: %s\n", safe_cstr(eglQueryString(egl_display, EGL_VENDOR)));
    printf("EGL version: %s\n", safe_cstr(eglQueryString(egl_display, EGL_VERSION)));
    printf("EGL client APIs: %s\n", safe_cstr(eglQueryString(egl_display, EGL_CLIENT_APIS)));
    printf("EGL extensions: %s\n", safe_cstr(eglQueryString(egl_display, EGL_EXTENSIONS)));
}

static bool run_sdl_gl_path(void)
{
    if (!SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_ES)) {
        die_sdl("SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK)");
    }
    if (!SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 2)) {
        die_sdl("SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION)");
    }
    if (!SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 0)) {
        die_sdl("SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION)");
    }
    if (!SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1)) {
        die_sdl("SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER)");
    }

    SDL_Window *window = SDL_CreateWindow("sdl3-wayland-smoke",
                                          640, 360,
                                          SDL_WINDOW_FULLSCREEN | SDL_WINDOW_OPENGL | SDL_WINDOW_HIGH_PIXEL_DENSITY);
    if (!window) {
        return false;
    }
    SDL_ShowWindow(window);

    int win_w = 0;
    int win_h = 0;
    if (!SDL_GetWindowSizeInPixels(window, &win_w, &win_h)) {
        die_sdl("SDL_GetWindowSizeInPixels");
    }

    SDL_GLContext gl_ctx = SDL_GL_CreateContext(window);
    if (!gl_ctx) {
        SDL_DestroyWindow(window);
        return false;
    }

    if (!SDL_GL_MakeCurrent(window, gl_ctx)) {
        SDL_GL_DestroyContext(gl_ctx);
        SDL_DestroyWindow(window);
        die_sdl("SDL_GL_MakeCurrent");
    }

    printf("SDL video driver: %s\n", safe_cstr(SDL_GetCurrentVideoDriver()));
    print_sdl_version();
    printf("Window pixel size: %dx%d\n", win_w, win_h);
    const SDL_PropertiesID props = SDL_GetWindowProperties(window);
    printf("Wayland display: %p\n",
           SDL_GetPointerProperty(props, SDL_PROP_WINDOW_WAYLAND_DISPLAY_POINTER, NULL));
    printf("Wayland surface: %p\n",
           SDL_GetPointerProperty(props, SDL_PROP_WINDOW_WAYLAND_SURFACE_POINTER, NULL));
    print_current_egl_diagnostics();

    glViewport(0, 0, win_w, win_h);
    glClearColor(1.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    print_gl_info();

    if (!SDL_GL_SwapWindow(window)) {
        SDL_GL_DestroyContext(gl_ctx);
        SDL_DestroyWindow(window);
        die_sdl("SDL_GL_SwapWindow");
    }

    printf("Presented one frame through SDL_GL_CreateContext; holding for 5 seconds.\n");
    fflush(stdout);
    sleep_visible_5s();

    SDL_GL_DestroyContext(gl_ctx);
    SDL_DestroyWindow(window);
    SDL_Quit();
    return true;
}

static void run_manual_wayland_egl_path(void)
{
    SDL_Window *window = SDL_CreateWindow("sdl3-wayland-smoke",
                                          640, 360,
                                          SDL_WINDOW_FULLSCREEN | SDL_WINDOW_HIGH_PIXEL_DENSITY);
    if (!window) {
        die_sdl("SDL_CreateWindow");
    }
    SDL_ShowWindow(window);

    int win_w = 0;
    int win_h = 0;
    if (!SDL_GetWindowSizeInPixels(window, &win_w, &win_h)) {
        die_sdl("SDL_GetWindowSizeInPixels");
    }

    const SDL_PropertiesID props = SDL_GetWindowProperties(window);
    struct wl_display *wl_display = SDL_GetPointerProperty(props, SDL_PROP_WINDOW_WAYLAND_DISPLAY_POINTER, NULL);
    struct wl_surface *wl_surface = SDL_GetPointerProperty(props, SDL_PROP_WINDOW_WAYLAND_SURFACE_POINTER, NULL);

    if (!wl_display || !wl_surface) {
        fprintf(stderr, "SDL Wayland properties missing: wl_display=%p wl_surface=%p\n",
                (void *)wl_display, (void *)wl_surface);
        SDL_DestroyWindow(window);
        SDL_Quit();
        exit(1);
    }

    printf("SDL video driver: %s\n", safe_cstr(SDL_GetCurrentVideoDriver()));
    print_sdl_version();
    printf("Wayland display: %p\n", (void *)wl_display);
    printf("Wayland surface: %p\n", (void *)wl_surface);
    printf("Window pixel size: %dx%d\n", win_w, win_h);

    EGLDisplay egl_display = query_wayland_egl_display(wl_display);
    if (egl_display == EGL_NO_DISPLAY) {
        die_egl("eglGetDisplay / eglGetPlatformDisplay", EGL_NO_DISPLAY);
    }

    if (!eglInitialize(egl_display, NULL, NULL)) {
        die_egl("eglInitialize", egl_display);
    }

    printf("EGL vendor: %s\n", safe_cstr(eglQueryString(egl_display, EGL_VENDOR)));
    printf("EGL version: %s\n", safe_cstr(eglQueryString(egl_display, EGL_VERSION)));
    printf("EGL client APIs: %s\n", safe_cstr(eglQueryString(egl_display, EGL_CLIENT_APIS)));
    printf("EGL extensions: %s\n", safe_cstr(eglQueryString(egl_display, EGL_EXTENSIONS)));

    if (!eglBindAPI(EGL_OPENGL_ES_API)) {
        die_egl("eglBindAPI(EGL_OPENGL_ES_API)", egl_display);
    }

    const EGLint config_attribs[] = {
        EGL_SURFACE_TYPE, EGL_WINDOW_BIT,
        EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT,
        EGL_RED_SIZE, 8,
        EGL_GREEN_SIZE, 8,
        EGL_BLUE_SIZE, 8,
        EGL_ALPHA_SIZE, 8,
        EGL_NONE
    };

    EGLConfig config = NULL;
    EGLint num_configs = 0;
    if (!eglChooseConfig(egl_display, config_attribs, &config, 1, &num_configs) || num_configs < 1) {
        die_egl("eglChooseConfig", egl_display);
    }

    const EGLint context_attribs[] = {
        EGL_CONTEXT_CLIENT_VERSION, 2,
        EGL_NONE
    };

    EGLContext egl_context = eglCreateContext(egl_display, config, EGL_NO_CONTEXT, context_attribs);
    if (egl_context == EGL_NO_CONTEXT) {
        die_egl("eglCreateContext", egl_display);
    }

    struct wl_egl_window *wl_egl = wl_egl_window_create(wl_surface, win_w, win_h);
    if (!wl_egl) {
        die_egl("wl_egl_window_create", egl_display);
    }

    EGLSurface egl_surface = eglCreateWindowSurface(egl_display, config, (EGLNativeWindowType)wl_egl, NULL);
    if (egl_surface == EGL_NO_SURFACE) {
        die_egl("eglCreateWindowSurface", egl_display);
    }

    if (!eglMakeCurrent(egl_display, egl_surface, egl_surface, egl_context)) {
        die_egl("eglMakeCurrent", egl_display);
    }

    glViewport(0, 0, win_w, win_h);
    glClearColor(1.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    print_gl_info();

    if (!eglSwapBuffers(egl_display, egl_surface)) {
        die_egl("eglSwapBuffers", egl_display);
    }

    printf("Presented one frame through manual Wayland/EGL; holding for 5 seconds.\n");
    fflush(stdout);
    sleep_visible_5s();

    eglMakeCurrent(egl_display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
    eglDestroySurface(egl_display, egl_surface);
    eglDestroyContext(egl_display, egl_context);
    wl_egl_window_destroy(wl_egl);
    eglTerminate(egl_display);
    SDL_DestroyWindow(window);
    SDL_Quit();
}

int main(void)
{
    if (!SDL_SetHint(SDL_HINT_VIDEO_DRIVER, "wayland")) {
        fprintf(stderr, "warning: SDL_SetHint(SDL_HINT_VIDEO_DRIVER, wayland) failed\n");
    }

    if (!SDL_InitSubSystem(SDL_INIT_VIDEO)) {
        die_sdl("SDL_InitSubSystem(SDL_INIT_VIDEO)");
    }

    printf("SDL video driver: %s\n", safe_cstr(SDL_GetCurrentVideoDriver()));
    print_sdl_version();

    if (run_sdl_gl_path()) {
        return 0;
    }

    printf("SDL_GL_CreateContext failed; falling back to manual Wayland/EGL.\n");
    run_manual_wayland_egl_path();
    return 0;
}
