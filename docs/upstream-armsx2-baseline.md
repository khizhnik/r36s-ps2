# ARMSX2 Baseline Audit

Audit date: 2026-07-27

## Upstream Reference

- Official URL: `https://github.com/ARMSX2/ARMSX2`
- Default branch: `master`
- Current pinned commit: `0dbf7bd54b9f5945f5dfbcbb89c354f73ccccbae`
- License: `GPL-3.0`

The GitHub repository is the official ARMSX2 source repository, but it is also marked upstream as a fork of `PCSX2/pcsx2`.

## Submodule State

- Local submodule path: `upstream/armsx2`
- Nested Git submodules in the current upstream HEAD: none detected
- `upstream/armsx2/.gitmodules` at this commit is empty
- No `160000` gitlinks were present in `git ls-tree`
- Full recursive initialization command remains:

```bash
git submodule update --init --recursive
```

## Top-Level Layout

The upstream tree contains these major top-level directories and files:

- `.github`
- `3rdparty`
- `bin`
- `cmake`
- `common`
- `pcsx2`
- `pcsx2-eerunner`
- `pcsx2-gsrunner`
- `pcsx2-libretro`
- `pcsx2-qt`
- `pcsx2-sdl`
- `pcsx2-vurunner`
- `platforms`
- `tests`
- `tools`
- `updater`
- `CMakeLists.txt`
- `CMakePresets.json`
- `COPYING.GPLv3`
- `README.md`
- `REFACTOR_STATUS.md`

## High-Level Components

- `pcsx2/` contains the shared emulator core, PS2 subsystems, and the ARM64/x86 backend split.
- `pcsx2/arm64/` contains the AArch64 dynamic recompilers and ARM64-specific helpers.
- `pcsx2/x86/` still holds shared or historical code that is reused by the ARM64 build, such as `BaseblockEx.cpp` and `iR5900Analysis.cpp`.
- `pcsx2-qt/` is the full Qt UI frontend.
- `pcsx2-sdl/` is an SDL3 frontend aimed at handheld / direct-display usage.
- `pcsx2-libretro/` is a libretro frontend/core scaffold.
- `pcsx2-eerunner/` is a headless full-system runner for EE recompiler analysis.
- `pcsx2-gsrunner/` is a standalone GS replay runner.
- `pcsx2-vurunner/` is a headless VU microprogram replayer / benchmark harness.
- `platforms/android/` and `platforms/ios/` contain mobile platform layers and their build glue.
- `tests/` provides the recompiler harness and supporting test infrastructure.

## Runner and Frontend Targets

### Confirmed present

- `pcsx2-sdl/Main.cpp`
- `pcsx2-libretro/Main.cpp`
- `pcsx2-eerunner/Main.cpp`
- `pcsx2-gsrunner/Main.cpp`
- `pcsx2-vurunner/Main.cpp`
- `pcsx2-qt/MainWindow.cpp`

### Role of each target

- `pcsx2-sdl` boots a game from CLI or opens the fullscreen UI, and normally uses Vulkan direct display via `VK_KHR_display`, with a Wayland fallback when a compositor is present.
- `pcsx2-libretro` starts as a headless libretro core with Null GS for milestone 1, then plans a Vulkan hardware-render path through libretro's Vulkan negotiation interface.
- `pcsx2-eerunner` is the best match for a first investigative target: it is headless, deterministic, and built specifically for EE JIT vs interpreter divergence triage.
- `pcsx2-gsrunner` is a GS replay / RenderDoc-oriented harness that still uses a visible platform window when needed.
- `pcsx2-vurunner` replays captured VU microprograms through both the microVU JIT and interpreter, and also supports benchmark / disassembly modes.

## ARMSX2-Related ARM64 Recompiler Coverage

The ARM64 backend is not a thin x86 shim. It emits AArch64 directly with VIXL and carries native ARM64 code paths for the major PS2 CPU subsystems.

### Files of interest

- `pcsx2/arm64/iR5900-arm64.cpp`
- `pcsx2/arm64/iR5900Arit-arm64.cpp`
- `pcsx2/arm64/iR5900AritImm-arm64.cpp`
- `pcsx2/arm64/iR5900Branch-arm64.cpp`
- `pcsx2/arm64/iR5900Jump-arm64.cpp`
- `pcsx2/arm64/iR5900LoadStore-arm64.cpp`
- `pcsx2/arm64/iR5900Move-arm64.cpp`
- `pcsx2/arm64/iR5900MultDiv-arm64.cpp`
- `pcsx2/arm64/iR5900Shift-arm64.cpp`
- `pcsx2/arm64/iR5900Misc-arm64.cpp`
- `pcsx2/arm64/iR3000A-arm64.cpp`
- `pcsx2/arm64/iR3000Atables-arm64.cpp`
- `pcsx2/arm64/iCOP0-arm64.cpp`
- `pcsx2/arm64/iCOP2-arm64.cpp`
- `pcsx2/arm64/iFPU-arm64.cpp`
- `pcsx2/arm64/iFPUd-arm64.cpp`
- `pcsx2/arm64/iMMI-arm64.cpp`
- `pcsx2/arm64/recVTLB-arm64.cpp`
- `pcsx2/arm64/Vif_Dynarec.cpp`
- `pcsx2/arm64/Vif_UnpackNEON.cpp`
- `pcsx2/arm64/microVU-arm64.cpp`
- `pcsx2/arm64/microVU-arm64.h`
- `pcsx2/arm64/AsmHelpers.h`
- `pcsx2/arm64/iCore-arm64.h`

### PS2 subsystems with ARM64 backends

- EE / R5900
- IOP / R3000A
- FPU
- COP0
- COP2
- MMI
- VU microcode
- VIF unpack / dynarec support
- fast VTLB / memory dispatch

### Dynarec shape

- The backend is a direct PS2 guest to AArch64 dynarec.
- The arm64 sources use `vixl::aarch64` directly.
- There is no x86 host JIT layer in the execution path.
- The code does reuse some shared files from `pcsx2/x86/`, but those files are architecture-neutral helpers or shared analysis code, not an x86 host dependency in the runtime backend.

### Expected ARM64 ISA

- The tree clearly targets AArch64 + NEON.
- I did not find a hard requirement for ARMv8.2+, LSE, FP16 arithmetic, or dot-product in the inspected arm64 backend sources.
- The desktop Linux ARM64 build path in `cmake/BuildParameters.cmake` sets `-march=armv8.1-a` unless the caller already supplied a different `-march` in `CMAKE_CXX_FLAGS`.
- The Android ARM64 build path uses `-march=armv8-a`.
- The Windows ARM64 props also contain stronger flags for some configurations, but those are platform-specific and not the Linux baseline.
- Based on the current build rules, I would not assume `-march=armv8-a -mcpu=cortex-a35` is sufficient for the desktop Linux configuration without further work.

## Renderer Backends

### Confirmed renderer types in the tree

- Vulkan
- OpenGL
- Software renderer
- Null renderer
- D3D11 / D3D12 / Metal still exist in the generic UI enums, but they are not the relevant Linux path for R36S

### Backend evidence

- `pcsx2/GS/GS.h` defines `RenderAPI::Vulkan`, `RenderAPI::OpenGL`, `RenderAPI::None`, and the D3D / Metal values.
- `pcsx2/GS/Renderers/Null/GSDeviceNone.h` documents a true headless Null device and Null renderer pairing.
- `pcsx2/GS/Renderers/Vulkan/GSDeviceVK.h` is the Vulkan backend.
- `pcsx2/GS/Renderers/Vulkan/VKSwapChain.cpp` explicitly documents `VK_KHR_display` direct-to-monitor usage for kmsdrm-style handhelds and notes that this path does not need GBM.
- `pcsx2/GS/Renderers/OpenGL/GLContextEGL.cpp` loads EGL dynamically and can create EGL/OpenGL ES or EGL/OpenGL contexts.
- `pcsx2/GS/Renderers/OpenGL/GLContextEGLX11.cpp` provides the X11 EGL path.
- `pcsx2/GS/Renderers/OpenGL/GLContextEGLWayland.cpp` provides the Wayland EGL path.
- `pcsx2/GS/Renderers/OpenGL/GLContextEGLAndroid.cpp` provides the Android EGL path.
- `pcsx2-qt/Settings/GraphicsSettingsWidget.cpp` enumerates OpenGL, Vulkan, Software Renderer, and Null in the settings UI.

### Platform requirements surfaced by the code

- SDL3 is used by `pcsx2-sdl`.
- Qt is used by `pcsx2-qt`.
- X11 is supported by the OpenGL EGL path and by the Qt frontend on Linux.
- Wayland is supported by the OpenGL EGL path, the Qt frontend, and the SDL frontend fallback.
- EGL is used for the OpenGL renderer.
- GBM / DRM are not a separate emulator layer here, but they do appear in the SDL / Vulkan direct-display path via `VK_KHR_display` and in SDL3's KMSDRM support files.

### Most realistic path for Mali-G31 on Linux

- The first path I would investigate is Vulkan, because the SDL frontend and Vulkan swapchain code explicitly support direct-display and Wayland Vulkan flows.
- The next fallback is OpenGL through EGL, including the Wayland or X11 EGL paths.
- I did not find a dedicated GLES-only renderer; GLES would be reached through the EGL-backed OpenGL path if the platform chooses an ES profile.
- None of these paths should be assumed to work on Mali-G31 until the driver stack is verified.

## Linux / ARM64 Platform Notes

- `platforms/android/` contains Android-specific sources, including an ANGLE override for OpenGL on Android.
- `platforms/ios/` contains ARM64 JIT-related platform glue and settings repair code.
- `platforms/android/app/src/main/cpp/cmake/SearchForStuff.cmake` enables SDL3, Vulkan, libdrm / GBM-aware KMSDRM support in the bundled SDL3 tree, and Wayland/X11 support on desktop Linux.
- The inspected code did not expose a standalone GBM-only renderer path.

## Potentially Useful for R36S

- `pcsx2-eerunner` for deterministic headless EE analysis.
- `pcsx2-vurunner` for microVU capture / replay work.
- `pcsx2-sdl` for a direct-display handheld-oriented frontend.
- `pcsx2/GS/Renderers/Null/GSDeviceNone.h` for headless boot paths and runner scaffolding.
- `pcsx2/arm64/` for the actual ARM64 dynarec and register allocation work.
- `common/` and `tests/ctest/core/recompilers/` for reusable host / harness code.

## Heavy or Platform-Dependent Areas

- `pcsx2-qt/` is the heaviest UI surface.
- `pcsx2/GS/Renderers/Vulkan/` is the largest graphics backend and the most driver-sensitive path.
- `pcsx2/GS/Renderers/OpenGL/` is platform-dependent through EGL/X11/Wayland.
- `platforms/android/` and `platforms/ios/` are not directly relevant to the Linux handheld target, but they contain ARM64 and JIT-related ideas worth tracking.
- `3rdparty/` includes large vendor trees, especially `vixl`, `SDL3`, `vulkan`, `imgui`, and `cpuinfo`.

## First Target Recommendation

Best first investigation target: `pcsx2-eerunner`

Reason:

- it is the smallest clear Linux ARM64-style runtime target that is explicitly headless
- it can exercise the EE recompiler without a full GUI stack
- it is designed for divergence triage and deterministic analysis
- it keeps the first experiment away from window-system, audio, and frontend complexity

Secondary targets after that:

- `pcsx2-vurunner`
- `pcsx2-sdl`
- `pcsx2-libretro`
- `pcsx2-qt`
