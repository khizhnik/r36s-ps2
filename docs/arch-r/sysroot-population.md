# Arch-R Sysroot Population

Audit date: 2026-07-28

## Population model

Arch-R does not use a separate `makeinstall_sysroot` phase. Instead, `scripts/build`:

1. creates a package-specific temporary sysroot under:

   ```text
   ${BUILD}/.sysroot/${PKG_NAME}.${TARGET}
   ```

2. installs the package there when the `sysroot` flag is enabled
3. rewrites sysroot-relative metadata back to the shared sysroot prefix
4. copies the temporary sysroot into the shared sysroot
5. deletes the temporary sysroot

## What is preserved

The temporary sysroot path is seeded with:

- `usr/lib`
- `usr/include`
- `usr/bin`
- `usr/lib/pkgconfig`

After install, the scripts rewrite or keep:

- `.la`
- `*-config`
- `.pc`
- `.cmake`
- symlink targets that point at the temporary sysroot

## What is not preserved in the final image tree

The runtime image install tree is pruned separately by `scripts/install` and package-specific `post_makeinstall_target()` hooks.

That pruning removes or rewrites:

- headers
- pkg-config metadata
- CMake package config files
- static libraries
- many helper binaries

## Important source facts

- `libmali` explicitly removes `${SYSROOT_PREFIX}/usr/include`
- `glibc` prunes the target image install tree but still seeds a functional runtime library set
- `binutils` and `gcc` install different artifacts into sysroot versus image

## Relocation behavior

The sysroot is not purely a copy of upstream install prefixes. The build system rewrites metadata to the canonical shared sysroot prefix under the build tree.

That makes the sysroot usable inside the Arch-R build tree, but not automatically relocatable by naïvely moving the directory elsewhere.

## Confidence

- `CONFIRMED_BY_SOURCE`: temporary sysroot exists
- `CONFIRMED_BY_SOURCE`: metadata rewrites happen
- `INFERENCE`: full relocatability requires wrapper or normalization work
