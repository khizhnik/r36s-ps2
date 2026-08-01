# Arch-R Toolchain Bootstrap

Audit date: 2026-07-28

## High-level chain

The source tree shows this bootstrap dependency chain:

```text
host tools
-> virtual/toolchain
-> binutils:host
-> linux:host headers
-> gcc:bootstrap
-> glibc target headers + start files
-> glibc target runtime
-> gcc:host
-> libstdc++ runtime
-> pkg-config:host / cmake:host / ninja:host / meson:host
```

This is the source-backed version of the chain; there is no separate standalone SDK target in the inspected tree.

## Package roles

| Component | Source package | Role |
| --- | --- | --- |
| Host tool spine | `packages/virtual/toolchain/package.mk` | Declares the bootstrap host dependencies |
| Binutils | `packages/devel/binutils/package.mk` | Produces cross binutils and installs `libiberty.h` into the sysroot |
| Kernel headers | `packages/linux/package.mk` | Installs UAPI headers via `makeinstall_host()` |
| Bootstrap GCC | `packages/lang/gcc/package.mk` | C-only compiler without headers, used before glibc is complete |
| Glibc | `packages/devel/glibc/package.mk` | Installs loader/libc/startup runtime and prunes the image install tree |
| Final GCC/G++ | `packages/lang/gcc/package.mk` | Installs wrappers and `libstdc++` into the shared sysroot |
| pkg-config | `packages/devel/pkg-config/package.mk` | Seeds `pkg.m4` into the sysroot and host toolchain |
| CMake / Meson / Ninja / Make | `packages/devel/cmake`, `packages/python/devel/meson`, `packages/python/devel/ninja`, `packages/devel/make` | Host build tools for later packages |

## Concrete dependencies

### `toolchain` virtual package

- `PKG_DEPENDS_HOST`
  - `7-zip:host`
  - `autoconf:host`
  - `autoconf-archive:host`
  - `automake:host`
  - `bison:host`
  - `configtools:host`
  - `cmake:host`
  - `flex:host`
  - `intltool:host`
  - `libtool:host`
  - `ninja:host`
  - `make:host`
  - `meson:host`
  - `openssl:host`
  - `sed:host`
  - `xmlstarlet:host`
- `PKG_DEPENDS_TARGET`
  - `toolchain:host`
  - `gcc:host`
  - `patchelf:host`
  - `pax-utils:host`

### `binutils`

- Host deps: `ccache:host`, `bison:host`, `flex:host`, `linux:host`
- Target deps: `toolchain`, `zlib`, `binutils:host`
- Host configure uses `--with-sysroot=${SYSROOT_PREFIX}`
- Target install copies `libiberty.a`, `bfd`, and `opcodes` into the sysroot

### `gcc`

- Bootstrap deps: `ccache:host`, `autoconf:host`, `binutils:host`, `gmp:host`, `mpfr:host`, `mpc:host`, `zstd:host`
- Host deps: same plus `glibc`, `libxcrypt`
- Target deps: `toolchain`
- `bootstrap` stage is C-only, `host` stage enables C and C++
- `host` stage installs `libstdc++.so*` into the sysroot

### `glibc`

- Target deps: `ccache:host`, `autotools:host`, `linux:host`, `gcc:bootstrap`, `Python3:host`
- Target configure consumes `--with-headers=${SYSROOT_PREFIX}/usr/include`
- `makeinstall_init` installs the loader and runtime libraries into the target image

## When the sysroot becomes usable

Practical readiness appears in layers:

1. `SYSROOT_PREFIX` directory exists.
2. Kernel headers and basic compiler support are installed.
3. `glibc:init` and `gcc:bootstrap` have produced a C-linkable target sysroot.
4. `gcc:host` has added `libstdc++` and wrapper tools.
5. `pkg-config:host` and the common host build tools are installed.

The exact stopping point for a plain C++ `hello world` is therefore later than the directory-creation step and earlier than any image build.
