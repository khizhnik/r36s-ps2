# Minimal Target Graph

Audit date: 2026-07-27

This file maps the small build targets to their dependency surface.

## Target inclusion switches

- `ENABLE_EERUNNER` -> `pcsx2-eerunner`
- `ENABLE_VURUNNER` -> `pcsx2-vurunner`
- `ENABLE_GSRUNNER` -> `pcsx2-gsrunner`
- `ENABLE_SDL_FRONTEND` -> `pcsx2-sdl`
- `ENABLE_LIBRETRO` -> `pcsx2-libretro`
- `ENABLE_QT_UI` -> `pcsx2-qt`

## Core observation

All of these targets link the shared `PCSX2_FLAGS` + `PCSX2` core, but they do not carry the same frontend surface.

## Per-target dependency notes

### pcsx2-eerunner

- target name: `pcsx2-eerunner`
- source: `pcsx2-eerunner/Main.cpp`
- internal libraries: `PCSX2_FLAGS`, `PCSX2`
- external frontend deps: none beyond the core
- UI deps: none
- renderer deps: core GS stack only, defaulting to Null
- audio deps: core SPU2 init, but Null audio backend can be selected
- can build without Qt: yes
- can build without SDL: yes
- can build without Vulkan: yes, if renderer choice stays Null
- can build without OpenGL: yes
- can build with Null renderer only: yes
- static build expectation: not the default on Linux, but the target itself is not frontend-locked to shared UI libs
- dependency closure size: small relative to the other full-system frontends

### pcsx2-vurunner

- target name: `pcsx2-vurunner`
- source: `pcsx2-vurunner/Main.cpp` plus harness sources from `tests/ctest/core/recompilers/harness/`
- internal libraries: `PCSX2_FLAGS`, `PCSX2`
- external frontend deps: no GUI frontend
- UI deps: none
- renderer deps: none
- audio deps: none
- can build without Qt: yes
- can build without SDL: yes
- can build without Vulkan: yes
- can build without OpenGL: yes
- can build with Null renderer only: it does not need a renderer at all
- static build expectation: likely easier than GUI targets, but not the default packaging shape
- dependency closure size: smaller than any full-system frontend, but larger than a pure library test because it pulls the harness sources

### pcsx2-gsrunner

- target name: `pcsx2-gsrunner`
- source: `pcsx2-gsrunner/Main.cpp`, `RenderDocCapture.cpp`
- internal libraries: `PCSX2_FLAGS`, `PCSX2`
- external frontend deps: `dl` on UNIX; Wayland client and generated Wayland protocol code when enabled
- UI deps: no Qt
- renderer deps: GS stack, platform window path, optional RenderDoc
- audio deps: core SPU2 init
- can build without Qt: yes
- can build without SDL: yes
- can build without Vulkan: not necessarily, because the core still carries Vulkan sources unless the whole core is configured otherwise
- can build without OpenGL: not necessarily for the same reason
- can build with Null renderer only: the runner itself is not designed as a Null-only host
- static build expectation: not the natural shape
- dependency closure size: medium

### pcsx2-sdl

- target name: `pcsx2-sdl`
- source: `pcsx2-sdl/Main.cpp`
- internal libraries: `PCSX2_FLAGS`, `PCSX2`, `SDL3::SDL3`
- external frontend deps: SDL3, and the runtime display stack used by the renderer
- UI deps: FullscreenUI / ImGui core
- renderer deps: Vulkan preferred, OpenGL/EGL fallback in the core
- audio deps: SDL audio path
- can build without Qt: yes
- can build without SDL: no
- can build without Vulkan: not for the preferred direct-display path
- can build without OpenGL: yes if Vulkan is used, but the core still compiles the OpenGL backend unless disabled globally
- can build with Null renderer only: not as the intended frontend
- static build expectation: not the normal path
- dependency closure size: larger than the runners above

### pcsx2-libretro

- target name: `pcsx2-libretro`
- source: `pcsx2-libretro/Main.cpp`
- internal libraries: `PCSX2_FLAGS`, `PCSX2`, `libretro-headers`
- external frontend deps: libretro API
- UI deps: none
- renderer deps: Vulkan negotiation path first, Null fallback if frontend refuses Vulkan
- audio deps: Null backend in the milestone-1 scaffold
- can build without Qt: yes
- can build without SDL: yes
- can build without Vulkan: yes for the Null fallback, though the core still includes Vulkan support
- can build without OpenGL: yes for the same reason
- can build with Null renderer only: yes
- static build expectation: shared library by design
- dependency closure size: small to medium

### pcsx2-qt

- target name: `pcsx2-qt`
- source: `pcsx2-qt/MainWindow.cpp` and the full Qt UI tree
- internal libraries: `PCSX2_FLAGS`, `PCSX2`
- external frontend deps: Qt6, plus optional KDDockWidgets and Fontconfig on Linux
- UI deps: Qt widgets stack
- renderer deps: full graphics backend support
- audio deps: full audio support
- can build without Qt: no
- can build without SDL: yes
- can build without Vulkan: not if the installed core configuration expects Vulkan support
- can build without OpenGL: not if the core keeps the OpenGL backend enabled
- can build with Null renderer only: not as a meaningful Qt frontend target
- static build expectation: no
- dependency closure size: largest

## Tier classification

- Tier 0: compile-only ARM64 backend test -> no dedicated target exists; the closest existing piece is the shared core itself, but not a standalone compile-only target
- Tier 1: runner without VM or renderer -> `pcsx2-vurunner` for the narrow replay harness
- Tier 2: full VM with Null renderer -> `pcsx2-eerunner`
- Tier 3: SDL full-system runtime -> `pcsx2-sdl`
- Tier 4: graphical renderer -> `pcsx2-gsrunner`
- Tier 5: full Qt frontend -> `pcsx2-qt`

## Dependency closure summary

Smallest practical full-system closure:

`pcsx2-eerunner` + shared core + Null GS + Null audio

The next useful step after that is `pcsx2-sdl`, because it exercises a more realistic handheld-facing host stack while still staying below the Qt UI.
