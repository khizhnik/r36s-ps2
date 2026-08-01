# Development Surface

This document explains why the live R36S target is runtime-oriented rather than
development-oriented.

## Confirmed by Live Command

- `/usr/include` is absent.
- `pkg-config` is absent from `PATH`.
- `/usr/lib/gcc` is absent.
- `gcc` is not present in `PATH`.
- `/usr/bin/gcc` and `/usr/bin/g++` are absent.

## Confirmed by Package DB

### `glibc`

- `pacman -Ql glibc` lists `/usr/include` and many headers.
- `pacman -Ql glibc` also lists `/usr/bin/getconf`, `ldd`, `localedef`, and
  related tools.
- `pacman -Qi glibc` shows the package is explicitly installed for `aarch64`
  and built by `ArchR Build`.

### `gcc`

- `pacman -Ql gcc` on this image lists runtime libraries such as
  `libasan.so`, `libatomic.so`, `libgcc_s.so`, `libgomp.so`, and
  `libstdc++.so`.
- The inspected manifest does not show a compiler driver, compiler headers, or a
  `/usr/lib/gcc` tree.
- `pacman -Qi gcc` shows it is explicitly installed for `aarch64`.

### `binutils`

- `pacman -Ql binutils` in the inspected slice lists `/usr/bin/strings`.
- `pacman -Qi binutils` shows it is explicitly installed for `aarch64`.

## Integrity Checks

- `pacman -Qkk glibc`
- `pacman -Qkk gcc`
- `pacman -Qkk binutils`

All three reported `no mtree file`, so they did not provide a useful file-by-file
integrity delta for this image.

## Interpretation

The live filesystem and the package database do not expose a full development
surface.

Most likely explanations, ordered by confidence:

1. The live image is intentionally runtime-only.
2. Header files are present in package metadata but not installed into the live
   filesystem.
3. The compiler frontend is not shipped on the target at all, only runtime
   support libraries are.

## Implication for Sysroot Work

The sysroot should not be reconstructed from the live rootfs alone.
Matching package archives or a proper rootfs image are required to recover the
header and compiler metadata surface.
