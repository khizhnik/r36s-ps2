# Arch-R Toolchain Layout

Audit date: 2026-07-28
Source clone: `research/upstream/arch-r`
Pinned commit: `c9fa2ae9d33cbc1111985bfb81b59db30740de26`

## Source of truth

The layout is assembled from:

- `config/options`
- `config/path`
- `config/arch.aarch64`
- `distributions/ArchR/options`
- `scripts/build`

## Key variables

| Variable | Declared in | Meaning for `PROJECT=ArchR DEVICE=RK3326 ARCH=aarch64` |
| --- | --- | --- |
| `ROOT` | `config/options` | Repository root (`$PWD` when the build is launched) |
| `BUILD_ROOT` | `config/path` | Defaults to `BUILD_DIR` or `ROOT` |
| `BUILD_BASE` | `config/path` | Literal `build` |
| `BUILD` | `config/path` | `${BUILD_ROOT}/build.ArchR-RK3326.aarch64` |
| `TOOLCHAIN` | `config/path` | `${BUILD}/toolchain` |
| `TARGET_GCC_ARCH` | `config/arch.aarch64` | `aarch64` |
| `OSNAME` | `distributions/ArchR/options` | `archr` |
| `TARGET_NAME` | `config/path` | `aarch64-archr-linux-gnu` |
| `SYSROOT_PREFIX` | `config/path` | `${TOOLCHAIN}/aarch64-archr-linux-gnu/sysroot` |
| `TARGET_PREFIX` | `config/path` | `${TOOLCHAIN}/bin/aarch64-archr-linux-gnu-` |
| `TARGET_CPU` | `config/arch.aarch64` | `cortex-a35` for RK3326 defaults |
| `TARGET_SUBARCH` | `config/arch.aarch64` | `armv8-a` plus `TARGET_ARCH_FLAGS` |
| `TARGET_ARCH_FLAGS` | `projects/ArchR/devices/RK3326/options` | `+crc+fp+simd` |

## Expected path shape

For the RK3326 profile, the build tree is expected at:

```text
build.ArchR-RK3326.aarch64/
└── toolchain/
    ├── bin/
    ├── lib/
    └── aarch64-archr-linux-gnu/
        └── sysroot/
```

The exact subdirectories under `toolchain/` are created incrementally by package stages.

## First writers

- `scripts/build` creates `PKG_BUILD`, `PKG_INSTALL`, and the temporary per-package sysroot.
- The shared sysroot is first populated by the package install phase that runs with `flag_enabled "sysroot" "yes"`.
- `glibc:target`, `gcc:bootstrap`, `gcc:host`, and `linux:host` are the main early writers to toolchain and sysroot content.

## Notes

- The sysroot is not a separate exported SDK by default.
- The shared sysroot is rooted under an absolute build-tree path and is therefore source-tree local unless additional normalization is added later.
