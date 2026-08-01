# Arch-R Sysroot Readiness

Audit date: 2026-07-28

## Level 0: directory exists

The first useful artifact is the shared sysroot directory:

```text
build.ArchR-RK3326.aarch64/toolchain/aarch64-archr-linux-gnu/sysroot
```

This only proves that the tree has started bootstrap work. It is not yet a compile sysroot.

## Level 1: C compile sysroot

Needed:

- dynamic loader from glibc
- libc runtime libraries
- kernel/UAPI headers from `linux:host`
- compiler support libraries from binutils/GCC bootstrap
- startup objects and link scripts

Source-backed packages involved:

- `linux:host`
- `glibc`
- `binutils`
- `gcc:bootstrap`

## Level 2: C++ compile sysroot

Additional needs:

- `libstdc++.so*`
- C++ headers
- unwind / atomic support where required by the package set

Source-backed package:

- `gcc:host`

## Level 3: basic external CMake project

Additional needs:

- usable cross compiler wrapper
- linker
- `pkg-config`
- CMake toolchain settings
- relocatable search roots for include/library discovery

Source-backed packages:

- `pkg-config:host`
- `cmake:host`
- `ninja:host`
- `make:host`

## Level 4: ARMSX2 core dependencies

For `pcsx2-eerunner`, the external dependency set is driven by `common/` and `pcsx2/`:

- `zlib`
- `zstd`
- `lz4`
- `libpng`
- `libjpeg-turbo`
- `libwebp`
- `freetype`
- `fontconfig`
- `SDL3`
- `curl`
- `libpcap`
- `dbus-1`
- `libudev`
- `libbacktrace` when enabled
- `wayland` / `x11` only when those APIs are enabled
- `shaderc` / `vulkan-headers` only when Vulkan is enabled

## Practical stopping point

A simple AArch64 C or C++ ELF becomes possible once the bootstrap has produced:

- the shared sysroot
- kernel headers
- glibc runtime and startup objects
- `libstdc++`
- the cross compiler wrappers
- `pkg-config`

That is the first usable point for external downstream probes.
