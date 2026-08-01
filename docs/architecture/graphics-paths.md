# Graphics Paths

Audit date: 2026-07-27

This is a facts-first map of the graphics backends in the pinned upstream.

## Vulkan

Relevant files:

- `pcsx2/GS/Renderers/Vulkan/GSDeviceVK.h`
- `pcsx2/GS/Renderers/Vulkan/VKLoader.cpp`
- `pcsx2/GS/Renderers/Vulkan/VKSwapChain.cpp`
- `pcsx2/GS/Renderers/Vulkan/VKLibretro.cpp`

Facts:

- the core links Vulkan headers when `USE_VULKAN` is enabled
- the loader resolves Vulkan dynamically
- the device path has optional extension tracking
- the swapchain code explicitly supports `VK_KHR_display`
- the Vulkan direct-display path is aimed at kmsdrm-style handhelds
- Wayland and X11 surfaces are also supported

Minimum version:

- the code in `pcsx2-libretro/Main.cpp` requests Vulkan 1.1 in the libretro HW context negotiation

Important optional extensions and features surfaced in code:

- provoking vertex
- memory budget
- calibrated timestamps
- rasterization order attachment access
- push descriptor
- driver properties
- shader non-semantic info
- attachment feedback loop layout
- fragment shader interlock
- swapchain maintenance

Mali-specific note:

- `GSDeviceVK` explicitly carries a push-descriptor fallback because Mali drivers can crash on `vkCmdPushDescriptorSetKHR`

What this means for R36S:

- Vulkan looks like the most realistic graphics path on paper for Mali-G31
- but it still needs a working Vulkan driver stack
- nothing here proves the driver stack on the target device is sufficient

## OpenGL and EGL

Relevant files:

- `pcsx2/GS/Renderers/OpenGL/GLContextEGL.cpp`
- `pcsx2/GS/Renderers/OpenGL/GLContextEGLX11.cpp`
- `pcsx2/GS/Renderers/OpenGL/GLContextEGLWayland.cpp`

Facts:

- EGL is loaded dynamically
- surfaceless EGL is attempted first
- pbuffer or fallback context creation is used when surfaceless is unavailable
- X11 EGL support exists
- Wayland EGL support exists
- Android has its own EGL path

Important caution:

- EGL support does not automatically mean a GLES-only renderer exists
- this tree uses EGL as the context/surface layer for the OpenGL renderer

## Software renderer

Relevant files:

- `pcsx2/GS/Renderers/SW/GSRendererSW.cpp`
- `pcsx2/GS/Renderers/SW/GSRasterizer.cpp`
- `pcsx2/GS/Renderers/SW/GSDrawScanlineCodeGenerator.arm64.cpp`

Facts:

- the software renderer runs on CPU
- it is not GPU-free in the broader host sense, because presentation still goes through the frontend path
- it is the heaviest CPU fallback and the best visual correctness reference

## Null renderer

Relevant files:

- `pcsx2/GS/Renderers/Null/GSDeviceNone.cpp`
- `pcsx2/GS/Renderers/Null/GSRendererNull.cpp`

Facts:

- no graphics API is touched
- no real present happens
- no host window is required
- the GS command stream is still consumed

## Backend matrix

| Backend | Needed for BIOS execution | Requires GPU | Requires window | Mali-G31 uncertainty | CPU cost | First-stage value |
| ------- | ------------------------: | -----------: | --------------: | -------------------: | -------: | ----------------: |
| Vulkan | no, but useful | yes | no for direct display, yes for normal compositor paths | high | medium | high |
| OpenGL/EGL | no, but useful | usually yes | often yes, unless surfaceless/fallback works | high | medium to high | medium |
| Software renderer | no, but useful | no | usually yes for presentation | low GPU, high CPU | very high | medium |
| Null renderer | yes | no | no | low | very low GPU, low CPU | very high for bring-up |

## Current caution

Do not assume Vulkan is automatically the winner for the handheld until the actual R36S graphics stack is audited.

For first bring-up, the Null renderer gives the cleanest host-side signal.
