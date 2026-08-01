# Arch-R Rootfs Pruning

## Source fact

The live filesystem is intentionally pruned to runtime-only content.

## Central pruning point

`scripts/install` tars package install trees into the image tree while excluding:

- `./usr/include`
- `./usr/local/include`
- `./usr/lib/cmake`
- `./usr/lib/pkgconfig`
- `./usr/share/aclocal`
- `./usr/share/pkgconfig`
- `./include`
- `./lib/cmake`
- `./lib/pkgconfig`
- `./share/aclocal`
- `./share/pkgconfig`
- hidden dot-directories
- `*.a`
- `*.la`

This is the strongest generic explanation for the absence of development surface on the live target.

## Package-specific pruning

### `glibc`

- keeps only selected runtime tools in target rootfs
- removes `usr/lib/audit`, `usr/lib/glibc`, `usr/lib/*.o`, and `var`

### `systemd`

- removes init, X11, udev, nspawn, catalog, networkd, and many installer-related components
- makes journald volatile
- rewrites configuration and symlinks into `/storage`

### `pacman`

- removes locale, doc, and man pages
- rewrites shell shebangs
- binds package database/cache to `/storage`

### `libmali`

- removes `${SYSROOT_PREFIX}/usr/include`
- removes `ld.so.conf.d`
- patches the blob to depend on `libmali-hook.so.1`

## Package DB vs live filesystem

The package database can remain more descriptive than the live runtime filesystem because:

- package metadata is generated separately from the runtime overlay view
- runtime mounts and bind mounts can shadow files
- package-specific pruning may happen after installation into the image tree

This means `pacman -Ql` style package metadata is not sufficient to infer the live development surface.

## Open question

Whether the live R36S package DB is perfectly aligned with the final runtime tree or partly reflects pre-overlay package contents still needs careful source-by-source checking per package.

