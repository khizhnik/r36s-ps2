# Sysroot Scope

This document defines the intended boundaries of a future R36S sysroot
snapshot for cross-compilation.

## Likely Layers

- ABI baseline: `/lib`, `/usr/lib`
- Headers: `/usr/include` from package archives or an image, because the live
  console does not expose them
- Metadata: `/usr/lib/pkgconfig`, `/usr/share/pkgconfig`, `/usr/lib/cmake`,
  `/usr/share/cmake`
- Selected runtime data: package-specific `/usr/share/<pkg>` content and
  linker configuration files as needed

## Exclusions

- `/boot`
- `/flash`
- `/dev`
- `/proc`
- `/sys`
- `/run`
- `/tmp`
- `/var/cache`
- `/var/log`
- user homes
- ROMs, BIOS, saves, firmware dumps
- SSH material and network settings

## Open Questions

- Which additional package-owned paths need to be preserved for vendor graphics
  runtime compatibility
- Whether absolute symlinks or linker scripts need normalization
- The live console is merged-usr in the practical sense because `/lib` resolves
  to `/usr/lib`.

## Trusted Sources

- Clean live ABI snapshot: `artifacts/target-environment/20260727T180305Z/`
- Package database query results: same clean run
- Mounted vendor runtime layout: same clean run
