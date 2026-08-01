# SDK and Sysroot

## Source fact

The Arch-R tree does produce a build-time cross sysroot.

## Location

`config/path` defines:

- `TOOLCHAIN=$BUILD/toolchain`
- `SYSROOT_PREFIX=$TOOLCHAIN/$TARGET_NAME/sysroot`

`scripts/build` then uses that sysroot during package builds.

## Contents

The staged sysroot is populated with:

- headers
- pkg-config files
- CMake package metadata
- shared libraries
- cross compiler helper tools

The build system also rewrites `.pc`, `.cmake`, and `*-config` files so they remain relocatable with the original sysroot prefix.

## Can Arch-R serve as an SDK?

Inference:

- yes, the build tree already has the shape of a cross-compilation SDK/sysroot environment
- however, the source tree does not show a dedicated standalone SDK export target
- the practical SDK is the build-tree toolchain/sysroot under `build.../toolchain/...`

## Minimum support

The build host needs the toolchain/sysroot generation path, not the full image packaging path, if the goal is external cross-compilation against Arch-R.

