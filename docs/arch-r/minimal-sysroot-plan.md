# Arch-R Minimal Sysroot Plan

Audit date: 2026-07-28

## Candidate strategies

### Variant A: full RK3326 build

Build everything for RK3326 and stop after the image/sysroot is complete.

- Pros: maximal fidelity
- Cons: heaviest disk and time cost, not needed for first ARMSX2 probes

### Variant B: package bootstrap

Build only the toolchain and the package set needed for a usable sysroot, then stop before image assembly.

- Pros: best match for ARMSX2 cross builds
- Cons: requires careful target selection and package graph tracing

### Variant C: artifact reuse

Reuse already published toolchain or sysroot artifacts if the source tree or releases provide them.

- Pros: cheapest if available
- Cons: not yet proven for Arch-R RK3326

## Recommendation

Source inspection favors Variant B as the first practical path.

It is the smallest path that can still produce:

- cross binutils
- compiler bootstrap
- kernel headers
- glibc runtime
- `libstdc++`
- `pkg-config`
- selected ARMSX2 dependencies

## Confidence table

| Criterion | Full build | Package bootstrap | Existing artifacts |
| --- | ---: | ---: | ---: |
| Disk use | ESTIMATE | ESTIMATE | UNKNOWN |
| Build time | ESTIMATE | ESTIMATE | UNKNOWN |
| Reproducibility | SOURCE_CONFIRMED | SOURCE_CONFIRMED | UNKNOWN |
| Exact target match | SOURCE_CONFIRMED | SOURCE_CONFIRMED | UNKNOWN |
| Risk to host | ESTIMATE | ESTIMATE | ESTIMATE |
| Complexity | ESTIMATE | ESTIMATE | UNKNOWN |

## Stop condition

The proposed stop point for the next practical stage is:

- toolchain exists
- Level 2 C++ sysroot exists
- no image assembly has started

That is enough to begin external downstream probes without building the final distro image.
