# CMake Options Map

Audit date: 2026-07-27

This file lists only options that exist in the pinned upstream.

## Core frontend and runner options

| Option | Default | Declared in | Effect |
| --- | --- | --- | --- |
| `ENABLE_TESTS` | `ON` | `cmake/BuildParameters.cmake` | Builds unit tests and enables test infrastructure. |
| `ENABLE_RECOMPILER_TEST_HOOKS` | `ENABLE_TESTS` | `cmake/BuildParameters.cmake` | Compiles rec test hooks into the EE recompiler; required by VU runner. |
| `ENABLE_QT_UI` | `ON` | `cmake/BuildParameters.cmake` | Builds the Qt frontend. |
| `ENABLE_GSRUNNER` | `OFF` | `cmake/BuildParameters.cmake` | Adds `pcsx2-gsrunner` to the default build graph. |
| `ENABLE_VURUNNER` | `OFF` | `cmake/BuildParameters.cmake` | Adds `pcsx2-vurunner`; requires `ENABLE_RECOMPILER_TEST_HOOKS=ON`. |
| `ENABLE_EERUNNER` | `OFF` | `cmake/BuildParameters.cmake` | Adds `pcsx2-eerunner`. |
| `ENABLE_SDL_FRONTEND` | `OFF` | `cmake/BuildParameters.cmake` | Adds `pcsx2-sdl`. |
| `ENABLE_LIBRETRO` | `OFF` | `cmake/BuildParameters.cmake` | Adds `pcsx2-libretro` only when explicitly enabled. |

## Renderer options

| Option | Default | Declared in | Effect |
| --- | --- | --- | --- |
| `USE_OPENGL` | `ON` on non-Apple | `cmake/BuildParameters.cmake` | Builds the OpenGL GS renderer. |
| `USE_VULKAN` | `ON` | `cmake/BuildParameters.cmake` | Builds the Vulkan GS renderer. |

## Platform and dependency options

| Option | Default | Declared in | Effect |
| --- | --- | --- | --- |
| `ENABLE_SETCAP` | `OFF` | `cmake/BuildParameters.cmake` | Networking capability for DEV9. |
| `X11_API` | `ON` on UNIX non-Apple | `cmake/BuildParameters.cmake` | Enables X11 support and X11 EGL path. |
| `WAYLAND_API` | `ON` on UNIX non-Apple | `cmake/BuildParameters.cmake` | Enables Wayland support and Wayland EGL path. |
| `USE_BACKTRACE` | `ON` on UNIX non-Apple | `cmake/BuildParameters.cmake` | Enables libbacktrace support. |
| `USE_LINKED_FFMPEG` | `OFF` | `cmake/BuildParameters.cmake` | Links against system FFmpeg instead of using dynamic loading. |
| `ENABLE_QT_DEBUGGER` | `OFF` on ARM64, `ON` elsewhere | `cmake/BuildParameters.cmake` | Builds the Qt debugger UI and KDDockWidgets dependency path. |
| `ENABLE_MOBILE_GAMEDB_OVERLAY` | `ON` on ARM64 Linux, `OFF` elsewhere | `cmake/BuildParameters.cmake` | Copies the mobile GPU GameDB overlay into resources. |

## Build and instrumentation options

| Option | Default | Declared in | Effect |
| --- | --- | --- | --- |
| `LTO_PCSX2_CORE` | `OFF` unless set | `cmake/BuildParameters.cmake` | Enables LTO/IPO for the core subset. |
| `USE_VTUNE` | `OFF` unless set | `cmake/BuildParameters.cmake` | Enables VTune hooks. |
| `USE_PERF_JITDUMP` | `OFF` | `cmake/BuildParameters.cmake` | Emits Linux perf jitdump records. |
| `USE_PERF_MAP` | `OFF` | `cmake/BuildParameters.cmake` | Emits `/tmp/perf-<pid>.map`. |
| `PACKAGE_MODE` | `OFF` unless set | `cmake/BuildParameters.cmake` | Switches install layout for packaging. |
| `BUNDLE_EMOJI_FONT` | `ON` | `cmake/BuildParameters.cmake` | Bundles the emoji font. |
| `POSITION_INDEPENDENT_CODE` | `ON` | `cmake/BuildParameters.cmake` | Builds PIC by default. |
| `USE_ASAN` | `OFF` unless set | `cmake/BuildParameters.cmake` | Enables AddressSanitizer. |

## Compiler and baseline options

| Option / behavior | Default | Declared in | Effect |
| --- | --- | --- | --- |
| `-march=armv8.1-a` on ARM64 Linux | enabled unless user already supplied `-march` | `cmake/BuildParameters.cmake` | Sets the desktop ARM64 baseline to LSE-capable v8.1. |
| `-march=armv8-a` on Android ARM64 | explicit Android path | `cmake/BuildParameters.cmake` | Android keeps the ARMv8-A baseline. |
| `CMAKE_CXX_STANDARD=20` | fixed | `cmake/BuildParameters.cmake` | Forces C++20. |

## What the options do to targets

- `ENABLE_QT_UI=OFF` skips the Qt frontend subtree.
- `ENABLE_LIBRETRO=OFF` removes the libretro subtree entirely, not just from `all`.
- `ENABLE_EERUNNER`, `ENABLE_VURUNNER`, `ENABLE_GSRUNNER`, and `ENABLE_SDL_FRONTEND` only add their respective subdirectories; they do not rewrite the core.
- `USE_OPENGL=OFF` and `USE_VULKAN=OFF` affect renderer source inclusion in `pcsx2/CMakeLists.txt`.
- `X11_API` and `WAYLAND_API` change both dependency discovery and source inclusion.
- `ENABLE_RECOMPILER_TEST_HOOKS` affects recompiler test-only code paths and is relevant for `pcsx2-vurunner`.

## Can disabling an option break core?

Yes, in a few cases:

- `ENABLE_RECOMPILER_TEST_HOOKS=OFF` breaks `pcsx2-vurunner`.
- `ENABLE_LIBRETRO=OFF` removes the libretro core entirely.
- `USE_OPENGL=OFF` or `USE_VULKAN=OFF` may limit renderer choices and can change compile closure.
- `ENABLE_QT_UI=OFF` removes the Qt frontend but should not break the core.

## Build default takeaway

The existing upstream defaults are already close to the desired minimal target shape, except for the missing `cmake` executable on this host and the ARM64 baseline mismatch for Cortex-A35 testing.
