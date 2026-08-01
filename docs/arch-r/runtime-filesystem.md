# Runtime Filesystem

## Source fact

Arch-R uses a mixed read-only rootfs + writable overlays model.

## Early boot

`projects/ArchR/packages/sysutils/busybox/scripts/init`

- mounts `devtmpfs` on `/dev`
- mounts `proc` on `/proc`
- mounts `sysfs` on `/sys`
- mounts `tmpfs` on `/run`
- prepares `/flash`, `/sysroot`, `/storage`, `/update`

## Storage and autostart

`projects/ArchR/packages/archr/sources/scripts/archr-update`

- reads boot/update settings
- rewrites mirrorlist
- may seed the local pacman db

`projects/ArchR/packages/sysutils/autostart/sources/autostart`

- starts `archr-automount`
- runs common and device-specific autostart scripts
- starts the UI service

## Mounts and overlays

Inspected runtime constructs include:

- `/var` as tmpfs
- `/var/log` bind-mounted from `/storage/.cache/log`
- `/var/lib/pacman` symlinked into `/storage/.pacman/db`
- `/var/cache/pacman/pkg` symlinked into `/storage/.pacman/cache`
- RetroArch overlay mounts for cores, database, assets, shaders, overlays, and joypads
- `/etc` configuration indirections into `/storage/.config`

## Inference

The live filesystem is not a plain image clone. It is a booted rootfs plus runtime overlays and bind mounts, so live file presence/absence must be interpreted in that context.

