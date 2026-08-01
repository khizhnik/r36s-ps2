# R36S Package Manifest

The full package list is captured as a local artifact rather than embedded
directly in this document.

## Artifact

- `artifacts/target-environment/20260727T180305Z/packages.stdout.txt`

## Trusted Run

- `artifacts/target-environment/20260727T180305Z/`

## Relevant Installed Packages

- `archr 20260709-1`
- `binutils 2.44-1`
- `gcc 14.2.0-1`
- `glibc 2.40-1`
- `systemd 255.8-1`
- `mesa 26.1.3-1`
- `mali-bifrost-r52p0 00eac0-1`
- `libdrm 2.4.128-1`
- `SDL2 2.32.10-1`
- `SDL2_glesonly 2.32.10-1`
- `alsa-lib 1.2.14-1`
- `wayland 1.25.0-1`
- `pulseaudio 17.0-1`
- `pipewire 1.2.6-1`
- `fontconfig 2.17.1-1`
- `freetype 2.13.3-1`
- `libpng 1.6.40-1`
- `curl 8.14.1-1`
- `xz 5.8.1-1`
- `zstd 1.5.7-1`

## Development Metadata Notes

- `pkg-config` is not present in `PATH`.
- `/usr/share/cmake` exists, with some package config files present.
- `/usr/include` is absent, so the live console does not expose a usable
  system header tree for cross-compilation.
- `gcc` is installed as a package, but the compiler driver is not exposed on the
  live target.
- `pacman -Ql glibc` shows headers in the package manifest even though the live
  filesystem does not contain `/usr/include`.

## Current Status

- Collection method prepared.
- Runtime package database is read-only for this stage.
- Full reconciliation against a package archive source is deferred.
