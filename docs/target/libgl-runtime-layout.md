# libGL Runtime Layout

This document captures the unusual `libGL` layout on the live R36S target.

## Confirmed by Live Command

- `/usr/lib/libGL.so.1` is a symlink to `libGL.so.1.7.0`.
- `/usr/lib/libGL.so.1.7.0` is not a regular ELF shared object.
- `file` reports `/usr/lib/libGL.so.1.7.0` as a character special file.
- `stat` shows device number `1,3`.
- `findmnt -T /usr/lib/libGL.so.1.7.0` reports source `devtmpfs`.
- `/proc/self/mountinfo` shows the path mounted from `/null`.
- `mountpoint /usr/lib/libGL.so.1.7.0` returns nonzero.

## Package Ownership

- `pacman -Qo /usr/lib/libGL.so.1.7.0` reports `libglvnd 1.7.0-1`.
- `pacman -Qo /usr/lib/libEGL.so.1` reports `libglvnd 1.7.0-1`.
- `pacman -Qo /usr/lib/libGLESv2.so.2` reports `libglvnd 1.7.0-1`.
- `pacman -Qo /usr/lib/libgbm.so.1` reports `mesa 26.1.3-1`.

## Interpretation

- The `libGL.so.1.7.0` pathname is being used as a mounted null device path,
  not as a normal shared object file.
- `libEGL` and `libGLESv2` come from `libglvnd`.
- `libgbm` comes from Mesa.
- This is a vendor/runtime layout detail and should not be treated as a normal
  desktop GL install layout.

## Implication

Any future sysroot snapshot should preserve the difference between:

- real shared objects (`libEGL`, `libGLESv2`, `libgbm`)
- the special `libGL.so.1.7.0` runtime placeholder
