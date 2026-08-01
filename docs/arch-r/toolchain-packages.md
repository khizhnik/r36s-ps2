# Arch-R Toolchain Packages

## `gcc`

Source fact:

- package version: `14.2.0`
- target install only copies runtime libraries into `/usr/lib`
- the target rootfs does not receive a compiler frontend
- `makeinstall_target` installs:
  - `libgcc_s.so*`
  - `libstdc++.so*`
  - `libgomp.so*`
  - `libsanitizer/asan`
  - `libsanitizer/ubsan`
  - optional `libatomic.so*`

Inference:

- the `gcc` package present in the target package database is a runtime-support package, not a developer toolchain package

## `glibc`

Source fact:

- package version: `2.41`
- target install is reduced to runtime libc, loader, math, nptl, rt, and NSS libraries
- headers are required only for build/sysroot use
- target rootfs removes `usr/lib/audit`, `usr/lib/glibc`, and most binaries

## `binutils`

Expected role:

- host-side assembler/linker support during build
- runtime target does not need the full developer-facing `binutils` surface

## `libstdc++`

Source fact:

- delivered as part of GCC package install
- target receives shared runtime libs, not the compiler frontend

## `libatomic`

Source fact:

- only installed when the target architecture and build flags enable it
- may be absent on some targets

## Mechanism behind the live observation

The combination of:

- runtime-only target install rules
- explicit pruning in `post_makeinstall_target`
- separate staged sysroot under `build.../toolchain/.../sysroot`

explains why the live device can report `gcc` in package metadata while still lacking `/usr/bin/gcc` and `/usr/lib/gcc`.

