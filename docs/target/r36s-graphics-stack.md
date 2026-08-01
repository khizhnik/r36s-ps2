# R36S Graphics Stack

This document tracks the console graphics runtime in read-only form.

## Artifact Inputs

- `artifacts/target-environment/20260727T180305Z/graphics.stdout.txt`
- `artifacts/target-environment/20260727T180305Z/vulkan-runtime.stdout.txt`
- `artifacts/target-environment/20260727T180305Z/libgl-runtime.stdout.txt`

## Confirmed Runtime Stack

- DRM device: `/dev/dri/card0`
- Kernel DRM driver: `rockchip-drm`
- GPU kernel module: `mali_kbase`
- Mali kernel driver banner: `r52p0-00eac0`
- GPU identified by the kernel as `arch 7.0.9 r0p0`
- Userspace package present: `mali-bifrost-r52p0 00eac0-1`
- Mesa is installed: `mesa 26.1.3-1`
- `libdrm 2.4.128-1` is installed
- `wayland 1.25.0-1` is installed
- `SDL2 2.32.10-1` is installed
- `glxinfo` is present
- `kmsprint` is present

## Confirmed Library Surface

- `libEGL.so.1` and `libGLESv2.so.2` are provided by `libglvnd 1.7.0-1`
- `libgbm.so.1` is provided by Mesa
- `libwayland-egl.so.1` is present
- `libGL.so.1.7.0` is a devtmpfs-mounted null device placeholder, not a normal
  shared object
- `libvulkan.so.1` is not present

## Runtime Utilities Not Present

- `vulkaninfo`
- `eglinfo`
- `es2_info`

## Vulkan Status

- Status: `VULKAN_ABSENT`
- `/usr/share/vulkan` exists, but the only file observed in the clean run was
  `implicit_layer.d/MangoHud.aarch64.json`
- No Vulkan loader was found under `/usr/lib`, `/lib`, or `/usr/local/lib`

## Notes

- The target clearly has a working DRM/Mali stack for the shipped OS image.
- Vulkan runtime availability is not confirmed and currently looks absent.
- No benchmark or presentation test was run.
