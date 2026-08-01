# R36S Library Manifest

This document summarizes the target's shared library and loader surface.

## Artifact Inputs

- `artifacts/target-environment/20260727T180305Z/libgl-runtime.stdout.txt`
- `artifacts/target-environment/20260727T180305Z/selected-libraries.tsv`

## Loader and Core ABI

- Dynamic loader: `/usr/lib/ld-linux-aarch64.so.1`
- `/lib/ld-linux-aarch64.so.1` resolves to `/usr/lib/ld-linux-aarch64.so.1`
- `libc.so.6` is an AArch64 ELF shared object
- `systemctl`, `retroarch`, and `emulationstation` are AArch64 ELFs and all
  request `/lib/ld-linux-aarch64.so.1`

## Selected Libraries Present

- `libstdc++.so.6 -> libstdc++.so.6.0.33`
- `libatomic.so.1 -> libatomic.so.1.2.0`
- `libdrm.so.2 -> libdrm.so.2.128.0`
- `libgbm.so.1 -> libgbm.so.1.0.0`
- `libEGL.so.1 -> libEGL.so.1.1.0`
- `libGLESv2.so.2 -> libGLESv2.so.2.1.0`
- `libGL.so.1 -> libGL.so.1.7.0`
- `libasound.so.2 -> libasound.so.2.0.0`
- `libudev.so.1 -> libudev.so.1.7.8`

## Selected Libraries Missing

- `libvulkan.so.1` was not present in `/usr/lib`

## Notes

- Detailed SONAME and dependency analysis is captured from selected ELF files
  rather than by recursively scanning the full filesystem.
- The loader and library surface are sufficient for runtime, but not by
  themselves for a build sysroot.
- `libGL.so.1.7.0` is not a normal ELF shared object on this target; see
  [libGL runtime layout](libgl-runtime-layout.md).
