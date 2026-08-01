# Arch-R Package Sources

## Source fact

The tree does not use Arch Linux ARM binary repositories as its primary source of packages.
Instead, packages are defined and built locally from `package.mk` files, then repackaged into an ArchR pacman repository.

## Evidence

- `scripts/get` dispatches to source/archive fetch logic for package upstreams
- `scripts/update_packages` updates source versions and hashes
- `scripts/repo/gen-pacman-repo` reads `build.*-RK3326/install_pkg/<pkg>/`
- `scripts/repo/gen-pacman-repo` emits `archr.db`, `archr.files`, and `*.pkg.tar.zst`
- `projects/ArchR/packages/sysutils/pacman/config/pacman.conf` points pacman clients at `archr-linux/archr-repo`
- `projects/ArchR/packages/archr/sources/scripts/archr-update` rewrites `/etc/pacman.d/mirrorlist` by channel
- `projects/ArchR/packages/archr/autostart/004-seed-pacmandb` seeds the local pacman DB from `archr-localdb.tar.gz`

## Package types

### Built locally from source

Most packages are built from upstream source tarballs, git archives, or generated source trees declared in `package.mk`.

Examples inspected:

- `gcc`
- `glibc`
- `binutils`
- `systemd`
- `mesa`
- `pacman`
- `vulkan-loader`

### Repacked vendor or binary content

Some packages wrap vendor binaries or repackaged blobs.

Examples inspected:

- `libmali` repacks the Mali user-space blob
- `mali-bifrost` repacks the kernel driver source tree from ArchR-hosted sources

## Repository and signing model

ArchR publishes the built package set to GitHub Releases as `archr-repo`.
`repo-add` builds the repo database from the packaged install trees.
The local pacman database seed is shipped separately so the base image can report its installed packages on first boot.

## Channel model

- `stable`
- `next`
- `dev`

`archr-update` rewrites the mirrorlist to the matching release tag.

## Answered questions

1. Official Arch Linux ARM binaries are not the primary package source.
2. A custom Arch-R repository exists.
3. Most packages are custom-built from source in this tree.
4. Vendor blobs such as `libmali` are repackaged rather than built from scratch.
5. Package archives live under the generated repo output, not in the live rootfs.
6. The exact package set for a build is reproducible from the ArchR source tree and the pinned package versions/hashes in `package.mk`.
7. A package manifest exists as build output, but it is generated rather than hand-maintained as a separate canonical file.
8. Channel pinning exists via the repo tag and mirrorlist rewrite.
9. The package set for `ArchR 20260709` is meant to be reproducible from the source tree plus matching upstream fetches, but this is source inference, not a build claim.

