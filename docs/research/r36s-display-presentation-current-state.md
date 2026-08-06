# R36S Display Presentation Research State

This document freezes the current investigation state for the R36S / Arch-R handheld display path. It is intended to be self-contained and usable without the chat transcript.

## Table of Contents

1. [Platform And Runtime Context](#platform-and-runtime-context)
2. [Original Crash Chain](#original-crash-chain)
3. [Validation Patch](#validation-patch)
4. [Presentation Test Matrix](#presentation-test-matrix)
5. [Corrected False Leads](#corrected-false-leads)
6. [Vendor Stack Findings](#vendor-stack-findings)
7. [Working Native SHM Control](#working-native-shm-control)
8. [Current Boundary](#current-boundary)

## Platform And Runtime Context

The target is an R36S handheld based on:

- RK3326 SoC
- Mali G31 GPU
- Arch-R userspace and launch stack
- Sway compositor on the internal `DSI-1` output
- native output mode `640x480`

The emulator and presentation stack under test uses:

- PCSX2 / ARMSX2 SDL frontend
- SDL3 Wayland backend
- EGL / OpenGL ES on the handheld graphics path
- Arch-R Wayland session and Sway startup scripts

The relevant runtime environment used by the working tests is:

- `XDG_RUNTIME_DIR=/var/run/0-runtime-dir`
- `WAYLAND_DISPLAY=wayland-1`
- `SWAYSOCK=/var/run/0-runtime-dir/sway-ipc.0.sock`

The emulator test workflow uses the existing repository scripts rather than ad-hoc manual launch steps. Relevant scripts include:

- `tools/package-pcsx2-sdl-r36s.sh`
- `tools/deploy-pcsx2-sdl-r36s.sh`
- `tools/run-pcsx2-sdl-r36s.sh`
- `tools/research-mode-pcsx2-sdl-r36s.sh`

The native presentation control and SDL-only presentation tests also have dedicated scripts in `tools/` and `research/`.

## Original Crash Chain

The original failure boundary was established as:

```text
Linux GLES
→ GPU timing enabled
→ GSDeviceOGL::PopTimestampQuery()
→ desktop glad_glGetQueryObjectiv slot is NULL
→ indirect call through NULL
→ PC = 0
→ SIGSEGV
→ secondary fault in ARM64 PageFaultHandler/IsStoreInstruction()
```

This is split into two separate issues:

1. Primary timestamp-query crash:
   - `GSDeviceOGL::PopTimestampQuery()` on the GLES path called the desktop `glGetQueryObjectiv` / `glGetQueryObjectui64v` readers.
   - On this runtime path, the desktop GLAD slots were null.
   - The resulting indirect call branched to `PC = 0` and triggered `SIGSEGV`.

2. Secondary ARM64 signal-handler crash:
   - After the first signal, `PageFaultHandler::SignalHandler()` tried to classify the fault by decoding the faulting instruction via `IsStoreInstruction()`.
   - When the handler was entered with a null/invalid PC context, `IsStoreInstruction(nullptr)` dereferenced a null pointer and faulted again inside the handler.

The secondary crash is separate from the original emulator bug.

## Validation Patch

The temporary experimental gate was:

```cpp
if (enabled && m_is_gles)
    return false;
```

inside:

```text
GSDeviceOGL::SetGPUTimingEnabled(bool enabled)
```

This is a validation patch only. It is **not** the final timestamp-query implementation.

After this change:

- the immediate `PC = 0` crash disappeared
- the emulator stayed alive for the bounded run
- CPU utilization rose to roughly 140%
- memory use rose to roughly 60%
- the process ended via external timeout rather than the former crash
- the physical LCD still remained black

This established that the former `PopTimestampQuery()` null-indirect-call boundary was real and that suppressing GPU timing on GLES removes it.

## Presentation Test Matrix

The following presentation tests were run and verified physically by the user:

| Test | API path | Protocol/buffer path | Physical result |
|---|---|---|---|
| Emulator GLES green | SDL / EGL / GLES | vendor / Mali presentation path | black |
| SDL surface blue | SDL window surface | Wayland buffer accepted / released | black |
| SDL software renderer blue | SDL software renderer | Wayland buffer accepted / released | black |
| Native Wayland SHM red | native Wayland + `wl_shm` + `WL_SHM_FORMAT_XRGB8888` | standard SHM attach / damage / commit / release | red visible |

### Native red control

The native Wayland control client used:

```text
wl_shm
→ WL_SHM_FORMAT_XRGB8888
→ wl_surface.attach
→ wl_surface.damage_buffer
→ wl_surface.commit
→ Sway
→ DSI-1
→ physical LCD
```

The user physically confirmed that:

- green was not visible during the GLES green test
- blue was not visible during the SDL-only tests
- the native red SHM client was clearly visible

### SDL results

The SDL-only tests completed their Wayland and buffer lifecycles successfully, but the physical LCD remained black. That means:

- successful `SwapBuffers()` does not prove correct physical presentation
- successful `SDL_UpdateWindowSurface()` does not prove correct physical presentation
- repeated `wl_buffer.release` does not prove correct physical presentation

## Corrected False Leads

Several earlier explanations were ruled out:

- Sway’s raw JSON did **not** contain `mapped=false`; that value came from a parser default when the field was absent.
- Focusing the SDL window could hide EmulationStation, but that did not make blue visible.
- Workspace focus and fullscreen state alone do not explain the black result.
- The issue is not solved simply by successful Wayland commits or compositor releases.

The current finding is that physical visibility is not guaranteed by API success at the SDL / EGL / Wayland layer.

## Vendor Stack Findings

The inspected SDL3 source tree does **not** contain a `mali_buffer_sharing` implementation:

- `mali_buffer_sharing` is absent from the SDL3 source/history inspected in this repository
- SDL3’s Wayland backend still contains the standard SHM helper in:
  - `upstream/armsx2/platforms/android/app/src/main/cpp/3rdparty/sdl3/src/video/wayland/SDL_waylandshmbuffer.c`
- SDL3’s Wayland driver binds standard `wl_shm` in:
  - `upstream/armsx2/platforms/android/app/src/main/cpp/3rdparty/sdl3/src/video/wayland/SDL_waylandvideo.c`

The vendor/runtime side does contain `mali_buffer_sharing`:

- `libmali.so.1.9.0` exports `mali_buffer_sharing_interface`
- the deployed `libwayland-egl.so.1.25.0` depends on `libmali-hook.so.1`
- `libmali-hook.so.1.9.0` depends on `libmali.so.1`
- Arch-R wlroots is built with vendor/libmali modifications

The proven conclusion at this point is:

- the black-screen boundary is somewhere in the non-SHM presentation route used by the SDL/EGL stack
- there is no supported SDL runtime switch or SDL build-time option found so far that forces ordinary `wl_shm`

This does **not** prove libmali or wlroots is defective; it only identifies where the black boundary currently sits.

### Relevant source and packaging paths

- SDL3 Wayland SHM helper:
  - `upstream/armsx2/platforms/android/app/src/main/cpp/3rdparty/sdl3/src/video/wayland/SDL_waylandshmbuffer.c`
- SDL3 Wayland registry / driver:
  - `upstream/armsx2/platforms/android/app/src/main/cpp/3rdparty/sdl3/src/video/wayland/SDL_waylandvideo.c`
- SDL framebuffer path and hint handling:
  - `upstream/armsx2/platforms/android/app/src/main/cpp/3rdparty/sdl3/src/video/SDL_video.c`
  - `upstream/armsx2/platforms/android/app/src/main/cpp/3rdparty/sdl3/include/SDL3/SDL_hints.h`
- Arch-R SDL3 package recipe:
  - `research/upstream/arch-r/projects/ArchR/packages/graphics/SDL3/package.mk`
- Vendor libmali package recipe:
  - `research/upstream/arch-r/projects/ArchR/packages/graphics/libmali/package.mk`
- Vendor GPU driver switcher:
  - `research/upstream/arch-r/projects/ArchR/packages/graphics/gpudriver/sources/bin/gpudriver`
- wlroots with libmali patching:
  - `research/upstream/arch-r/projects/ArchR/packages/wayland/lib/wlroots/package.mk`
  - `research/upstream/arch-r/projects/ArchR/packages/wayland/lib/wlroots/patches/libmali/001-libmali-workaround-allow-zero-stride.patch`
- sway startup and runtime layout:
  - `research/upstream/arch-r/projects/ArchR/packages/wayland/compositor/sway/scripts/sway.sh`
  - `research/upstream/arch-r/projects/ArchR/packages/wayland/compositor/sway/scripts/sway-config`
  - `research/upstream/arch-r/projects/ArchR/packages/wayland/compositor/sway/scripts/sway-touch.sh`
  - `research/upstream/arch-r/projects/ArchR/packages/wayland/compositor/sway/profile.d/050-sway.conf`
  - `research/upstream/arch-r/projects/ArchR/packages/wayland/compositor/sway/system.d/sway.service`
  - `research/upstream/arch-r/projects/ArchR/packages/wayland/compositor/sway/system.d/sway-touch.service`
  - `research/upstream/arch-r/projects/ArchR/packages/wayland/compositor/sway/autostart/111-sway-init`

### SDL runtime controls found

The only relevant documented SDL hint found so far is:

- `SDL_FRAMEBUFFER_ACCELERATION`

It can influence whether SDL attempts the texture-framebuffer / renderer-backed path for `SDL_GetWindowSurface()`, but it is **not** a documented control that forces ordinary `wl_shm` on this stack.

No supported SDL runtime hint/environment variable was found that explicitly disables the vendor Mali buffer-sharing route.

## Working Native SHM Control

The confirmed visible control client is the standalone native Wayland SHM test.

### Source and scripts

- Source:
  - `research/native-wayland-shm/main.c`
- Build:
  - `tools/build-native-wayland-shm.sh`
- Package:
  - `tools/package-native-wayland-shm.sh`
- Deploy:
  - `tools/deploy-native-wayland-shm.sh`
- Run:
  - `tools/run-native-wayland-shm.sh`
- Make targets:
  - defined in `Makefile`

### Known working buffer details

- protocol: `wl_shm`
- format: `WL_SHM_FORMAT_XRGB8888`
- size: `640x480`
- stride: `2560`
- physical result: visible red on the R36S LCD

### Required Wayland environment

- `XDG_RUNTIME_DIR=/var/run/0-runtime-dir`
- `WAYLAND_DISPLAY=wayland-1`
- `SWAYSOCK=/var/run/0-runtime-dir/sway-ipc.0.sock`

The native SHM client is the current proof that the compositor / output / scanout chain can show a simple shared-memory buffer.

## Current Boundary

The current technically important boundary is:

- native `wl_shm` presentation is visible
- SDL3 software and surface paths are black on this R36S stack
- SDL / EGL / GLES green presentation is black
- the former GLES timing crash is gone when GPU timing is disabled on GLES

The current open question is where the SDL / vendor path loses visibility compared with the native SHM client. The next step is a controlled SHM mirror experiment, but that work is not part of this frozen state document.
