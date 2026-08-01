# Arch-R Sysroot Exportability

Audit date: 2026-07-28

## Source-backed conclusion

The build tree exposes a working cross-toolchain/sysroot environment, but it is not a turnkey SDK export.

## What can be copied

At a minimum, the following can be archived together if the original prefix is preserved:

- `toolchain/bin`
- `toolchain/lib`
- `toolchain/aarch64-archr-linux-gnu/sysroot`
- package stamps and helper metadata if incremental rebuilds are desired

## What breaks a naïve move

- absolute symlink targets inside the toolchain
- wrapper scripts that hard-code the shared sysroot prefix
- rewritten `.pc` and `.cmake` files that point at the original build-tree sysroot
- compiler specs and linker scripts that resolve into the build tree

## Required environment

Likely required variables for downstream use:

- `PATH`
- `SYSROOT_PREFIX`
- `PKG_CONFIG_SYSROOT_DIR`
- `PKG_CONFIG_LIBDIR`
- `CMAKE_FIND_ROOT_PATH`
- compiler prefix (`aarch64-archr-linux-gnu-`)

## Practical export rule

The tree is easiest to reuse if:

- the build prefix remains unchanged
- a wrapper script recreates the expected environment
- the downstream project uses the same sysroot path or a carefully normalized copy

## What is not proven

- a fully relocatable tarball SDK
- a package-free standalone sysroot archive
- a path-agnostic compiler wrapper set

Those may be achievable later, but they are not proven by the inspected source.
