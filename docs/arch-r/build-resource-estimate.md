# Arch-R Build Resource Estimate

Audit date: 2026-07-28

## Host baseline

Measured on the current host:

- disk free on repository filesystem: `96G`
- RAM available: `28G`
- RAM total: `46G`
- CPU cores: `20`

## Source-backed signals

- `CCACHE_CACHE_SIZE=15G`
- Dockerfile installs a large host build environment, including compilers, scripting tools, and packaging utilities
- the full RK3326 distro build is intended to produce both toolchain and image artifacts

## Estimate

| Resource | Minimum safe | Recommended | Confidence |
| --- | ---: | ---: | --- |
| Disk for bootstrap-only sysroot work | 20G+ free remaining | 30G+ free remaining | ESTIMATE |
| Disk for a full RK3326 distro build | much larger than bootstrap | 60G+ free remaining | ESTIMATE |
| RAM for bootstrap-only work | 8G+ | 16G+ | ESTIMATE |
| Parallelism | 2-4 jobs for first probes | up to host cores once stable | ESTIMATE |

## Notes

- These are not measured build peaks.
- The current host already clears the bootstrap safety threshold.
- The safest next step is still a narrow package bootstrap, not a full image build.
