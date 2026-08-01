# Arch-R Package Build Entrypoints

Audit date: 2026-07-28

## Primary command

The package build entrypoint is:

```bash
PROJECT=ArchR DEVICE=RK3326 ARCH=aarch64 ./scripts/build <package>[:<host|target|init|bootstrap>]
```

This syntax is confirmed by `scripts/build` itself:

- `usage: ./scripts/build package_name[:<host|target|init|bootstrap>] [parent_pkg]`
- dependencies are built recursively from `PKG_DEPENDS_HOST`, `PKG_DEPENDS_TARGET`, `PKG_DEPENDS_INIT`, and `PKG_DEPENDS_BOOTSTRAP`

## Build stages

| Stage | Meaning |
| --- | --- |
| `target` | Main target package build, default when no suffix is supplied |
| `host` | Package built for the build host and installed into `TOOLCHAIN/` |
| `init` | Initial target stage used by some bootstrap chains |
| `bootstrap` | Host-side bootstrap stage used by compiler toolchain packages |

## Source-backed properties

- `PKG_BUILD` is `build.../build/<pkg>-<version>` under the current build tree.
- `PKG_INSTALL` is used for target package output.
- `PKG_TOOLCHAIN` may be `meson`, `cmake`, `cmake-make`, `configure`, `ninja`, `make`, `autotools`, `manual`, `python-flit`, or `python`.
- `PKG_NEED_UNPACK` exists and is consumed by `scripts/unpack`/`calculate_stamp`.
- There is no separate `makeinstall_sysroot` hook; sysroot handling is embedded in `scripts/build`.

## Safe package-level candidates

These are syntactically valid and source-backed:

```bash
PROJECT=ArchR DEVICE=RK3326 ARCH=aarch64 ./scripts/build toolchain
PROJECT=ArchR DEVICE=RK3326 ARCH=aarch64 ./scripts/build binutils:host
PROJECT=ArchR DEVICE=RK3326 ARCH=aarch64 ./scripts/build gcc:bootstrap
PROJECT=ArchR DEVICE=RK3326 ARCH=aarch64 ./scripts/build glibc:init
PROJECT=ArchR DEVICE=RK3326 ARCH=aarch64 ./scripts/build gcc:host
```

They are not executed in this audit.

## Build completion detection

The build system uses stamp files under:

```text
${BUILD}/.stamps/<package>/build_<stage>
```

The stamp is recalculated from package deep hashes and `BUILD_WITH_DEBUG`. A matching stamp short-circuits rebuilding.

## What is not implied

- `./scripts/build <pkg>` does not mean only the named package is built; its dependency closure is traversed first.
- `./scripts/build` does not guarantee a sysroot-only phase.
- `make -n` is not enough by itself to prove side-effect free behavior because the package scripts use shell hooks and command substitution.
