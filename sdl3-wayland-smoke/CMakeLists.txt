cmake_minimum_required(VERSION 3.20)

project(sdl3_wayland_smoke LANGUAGES C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

find_package(SDL3 CONFIG REQUIRED)
find_package(Threads REQUIRED)

find_library(EGL_LIBRARY EGL REQUIRED)
find_library(GLESV2_LIBRARY GLESv2 REQUIRED)
find_library(WAYLAND_CLIENT_LIBRARY wayland-client REQUIRED)
find_library(WAYLAND_EGL_LIBRARY wayland-egl REQUIRED)

add_executable(sdl3-wayland-smoke
    main.c
)

target_compile_options(sdl3-wayland-smoke PRIVATE
    -Wall
    -Wextra
    -Wpedantic
)

target_compile_definitions(sdl3-wayland-smoke PRIVATE
    SDL_MAIN_HANDLED
)

target_link_libraries(sdl3-wayland-smoke PRIVATE
    SDL3::SDL3
    Threads::Threads
    ${EGL_LIBRARY}
    ${GLESV2_LIBRARY}
    ${WAYLAND_CLIENT_LIBRARY}
    ${WAYLAND_EGL_LIBRARY}
    m
    dl
)

set_target_properties(sdl3-wayland-smoke PROPERTIES
    OUTPUT_NAME "sdl3-wayland-smoke"
    INSTALL_RPATH "$ORIGIN/lib"
    BUILD_RPATH "$ORIGIN/lib"
)

install(TARGETS sdl3-wayland-smoke
    RUNTIME DESTINATION bin
)
