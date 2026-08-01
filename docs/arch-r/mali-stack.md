# Mali Stack

## Source fact

RK3326 is configured for:

- `MALI_FAMILY=bifrost-g31`
- `GRAPHIC_DRIVERS=mali panfrost`
- `PREFER_GLES=yes`

## User-space package

`projects/ArchR/packages/graphics/libmali/package.mk`

Observed behavior:

- vendor blob package
- GPL-unfriendly / nonfree license
- platform selected as `gbm`, `wayland-gbm`, or `x11-gbm`
- removes `${SYSROOT_PREFIX}/usr/include`
- removes `ld.so.conf.d`
- patches vendor libs with `libmali-hook.so.1`

## Kernel driver

`projects/ArchR/packages/linux-drivers/mali-bifrost/package.mk`

Observed behavior:

- builds `mali_kbase.ko`
- package source is hosted under `archr-linux/mali_kbase`
- patches are carried for Linux 6.12 compatibility and runtime PM fixes

## GPU driver selector

`gpudriver` is the runtime switch between:

- `libmali` / `mali_kbase`
- `panfrost`

It also masks or unmasks Vulkan ICD JSONs and library mounts as needed.

## Mesa coexistence

Mesa is still present and is configured to support:

- OpenGL
- GBM
- EGL
- GLES when enabled
- Vulkan when enabled

On RK3326, both Mesa and vendor Mali pieces can coexist, but the active path is chosen at runtime.

## Vulkan

Source-level evidence suggests Vulkan is optional, not guaranteed, for RK3326.
The live R36S baseline lacking `libvulkan.so.1` is therefore consistent with the source tree.

