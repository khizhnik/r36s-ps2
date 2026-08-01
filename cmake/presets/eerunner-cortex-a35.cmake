set(ENABLE_TESTS OFF CACHE BOOL "")
set(ENABLE_QT_UI OFF CACHE BOOL "")
set(ENABLE_GSRUNNER OFF CACHE BOOL "")
set(ENABLE_VURUNNER OFF CACHE BOOL "")
set(ENABLE_EERUNNER ON CACHE BOOL "")
set(ENABLE_SDL_FRONTEND OFF CACHE BOOL "")
set(ENABLE_LIBRETRO OFF CACHE BOOL "")
set(USE_OPENGL OFF CACHE BOOL "")
set(USE_VULKAN OFF CACHE BOOL "")
set(X11_API OFF CACHE BOOL "")
set(WAYLAND_API OFF CACHE BOOL "")
set(USE_BACKTRACE OFF CACHE BOOL "")
# Cortex-A35 / RK3326 is an ARMv8.0 core without unconditional LSE atomics.
# Keep the host ISA at ARMv8-a and force non-outlined atomics so the build
# cannot emit unconditional ARMv8.1 LSE instructions into the host binary.
set(CMAKE_C_FLAGS "-march=armv8-a -mno-outline-atomics" CACHE STRING "")
set(CMAKE_CXX_FLAGS "-march=armv8-a -mno-outline-atomics" CACHE STRING "")
