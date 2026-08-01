# Arch-R Upstream Baseline

Audit date: 2026-07-27

## Source fact

- Official URL: `https://github.com/archr-linux/Arch-R`
- Default branch: `main`
- Current pinned commit: `c9fa2ae9d33cbc1111985bfb81b59db30740de26`
- Local clone path: `research/upstream/arch-r`
- Repository size: about `164M` in this checkout
- License file: [`LICENSE.md`](../../research/upstream/arch-r/LICENSE.md)
- ArchR software and scripts are GPL-2.0; branding has separate CC BY-NC-SA 4.0 terms; bundled components keep their own licenses.
- Submodules: none observed in the clone root
- Git LFS: no LFS pointers or `.gitattributes` evidence were seen in the inspected tree

## Top-level layout

Observed top-level entries:

- `.github`
- `.gitignore`
- `Dockerfile`
- `LICENSE.md`
- `Makefile`
- `README.md`
- `config`
- `distributions`
- `docs`
- `documentation`
- `licenses`
- `packages`
- `projects`
- `scripts`
- `tools`
- `weston_pkg_0.2.squashfs`

## Build system lineage

The tree is a LibreELEC/CoreELEC-style distro build system with ArchR-specific project overlays.
The build is source-based: packages are defined in `package.mk` files, built into a staging tree, then assembled into an image and finally published as an ArchR pacman repository.

## Relevant entrypoints

- `Makefile`
- `scripts/build_distro`
- `scripts/build`
- `scripts/install`
- `scripts/image`
- `scripts/repo/gen-pacman-repo`
- `scripts/update_packages`

## Supported RK3326 target

- `projects/ArchR/devices/RK3326/options`
- `projects/ArchR/devices/RK3326/packages/*`
- `projects/ArchR/devices/RK3326/filesystem/*`

Important RK3326 defaults:

- `TARGET_CPU=cortex-a35`
- `TARGET_ARCH_FLAGS=+crc+fp+simd` for `aarch64`
- `MALI_FAMILY=bifrost-g31`
- `GRAPHIC_DRIVERS=mali panfrost`
- `DISPLAYSERVER=wl`
- `WINDOWMANAGER=swaywm-env`
- `ADDITIONAL_PACKAGES=device-switch libmali generic-dsi`

## Build commands

- `make docker-RK3326`
- `make RK3326`
- `PROJECT=ArchR DEVICE=RK3326 ARCH=aarch64 ./scripts/build_distro`
- `PROJECT=ArchR DEVICE=RK3326 ARCH=aarch64 ./scripts/update_packages`

## Repository model

- Packages are built from source tarballs or git archives described in `package.mk`.
- A pacman repository is generated from `build.*-RK3326/install_pkg/<pkg>/`.
- A matching local pacman database seed is generated alongside the repo assets.
- Release distribution uses GitHub Releases under `archr-linux/archr-repo`.

