# Arch-R Build Pipeline

## High-level path

`make docker-RK3326`
→ Docker or Podman wrapper from `Makefile`
→ `make RK3326`
→ `scripts/build_distro`
→ `scripts/build` and `scripts/install` for packages
→ `scripts/image`
→ `scripts/mkimage`
→ `scripts/repo/gen-pacman-repo`

## Observed targets and roles

### `Makefile`

- `world: RK3326`
- `RK3326` runs:
  - `PROJECT=ArchR DEVICE=RK3326 ARCH=arm ./scripts/build_distro`
  - `PROJECT=ArchR DEVICE=RK3326 ARCH=aarch64 ./scripts/build_distro`
- `update` runs `./scripts/update_packages`
- `image` runs `./scripts/image mkimage`
- `system` runs `./scripts/image`

### `scripts/build_distro`

Source fact:

- checks `ARCH`
- loads `config/options` and `projects/${PROJECT}/devices/${DEVICE}/options`
- removes stale build output and release artifacts
- for `ARCH=arm`, runs `scripts/build_compat arm` and `scripts/install arm`
- for all other cases, runs `make image`

This means the image path is the aarch64 path for RK3326.

### `scripts/build`

Source fact:

- defines `BUILD=${BUILD_ROOT}/${BUILD_BASE}.${DISTRONAME}-${DEVICE}.${TARGET_ARCH}`
- defines the per-target sysroot as:
  - `TOOLCHAIN=$BUILD/toolchain`
  - `SYSROOT_PREFIX=$TOOLCHAIN/$TARGET_NAME/sysroot`
- sets `PKG_CONFIG_SYSROOT_DIR`, `PKG_CONFIG_LIBDIR`, `CMAKE_FIND_ROOT_PATH`, and related metadata paths
- builds package sources into a temporary per-package sysroot under `build.../.sysroot/...`
- copies the result back into the shared sysroot
- rewrites `.la`, `*-config`, `.pc`, and `.cmake` files to point at the original sysroot prefix

This is the core staging-sysroot mechanism.

### `scripts/install`

Source fact:

- copies package metadata into the image tree
- installs `profile.d`, `tmpfiles.d`, `system.d`, `udev.d`, `hwdb.d`, `sleep.d`, `sysctl.d`, `modules-load.d`, `modprobe.d`, etc.
- if `PKG_INSTALL` exists, it tars package contents into the image tree
- developer surface is pruned here with explicit `tar --exclude` rules

### `scripts/image`

Source fact:

- creates the base readonly filesystem layout
- copies project and device filesystem overlays into `${INSTALL}`
- creates legacy symlinks:
  - `/lib -> /usr/lib`
  - `/bin -> /usr/bin`
  - `/sbin -> /usr/sbin`
  - `/media -> /var/media`
- writes `/etc/os-release` and `/etc/archr-release`
- installs kernel overlays, modules, and firmware runtime symlinks
- produces the final image artifact

## When package contents become live filesystem

Arch Linux-style package contents become part of the live Arch-R filesystem in two stages:

1. package install stages them into `${INSTALL}` through `scripts/install`
2. `scripts/image` turns `${INSTALL}` into the shipped root filesystem image

Boot-time overlays and mounts then further transform that rootfs into the live runtime view.

