# libGL Placeholder

## Source fact

The placeholder is not a static `libGL` file in the rootfs.
It is part of the GPU-driver switch mechanism.

## Build-time setup

`projects/ArchR/packages/graphics/libglvnd/package.mk` creates the GLVND layout and rewires `libGL.so` / `libGL.so.1` into `/var/lib/libGL.so`.
That provides a writable indirection point in the image.

## Runtime switching

`projects/ArchR/packages/graphics/gpudriver/sources/bin/gpudriver` manages the actual runtime state.

In `libmali` mode it:

- loads `mali_kbase`
- bind-mounts Mali user-space libraries over Mesa equivalents
- binds `/dev/null` over `/usr/lib/libGL.so`
- binds `/dev/null` over `/usr/lib32/libGL.so`
- masks the panfrost Vulkan ICD JSONs

In `panfrost` mode it:

- unbinds the Mali overlay paths
- restores the real `libGL.so` visibility
- unmasks panfrost Vulkan ICD entries

## Implications

- The placeholder is runtime behavior, not a compile-time substitute.
- It depends on mount semantics and the boot-time driver selector.
- It should be mirrored in any future sysroot analysis as a runtime quirk, not as a standalone library artifact.

