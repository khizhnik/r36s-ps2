# r36s-ps2

Research and porting laboratory for exploring PlayStation 2 software on the R36S handheld.

Target context:

- Device: R36S
- SoC: RK3326
- CPU: 4 x Cortex-A35
- GPU: Mali-G31
- Runtime: ARM64 Linux

This repository uses the official ARMSX2 project as its upstream reference and keeps it isolated in `upstream/armsx2`.

Current project status:

- research and porting laboratory
- repository bootstrap and upstream analysis stage
- no BIOS, ROM, ISO, CHD, keys, firmware dumps, or other protected local media are stored here
- no claim is made about current playability

Research objective:

The goal is not to assume that PlayStation 2 emulation on the R36S is either possible or impossible. The goal is to determine the real hardware and software limits through reproducible experiments.

Planned repository areas:

- `docs/` for audit notes and analysis
- `patches/` for future downstream patch sets
- `tools/` for helper scripts and investigation utilities
- `upstream/` for pinned reference sources

Documentation index:

- `docs/README.md`
- `docs/arch-r/README.md`
- `docs/target/README.md`
- `docs/target/remote-execution-contract.md`
- `docs/target/artifact-run-audit.md`
- `docs/target/development-surface.md`
- `docs/target/libgl-runtime-layout.md`
- `docs/upstream-armsx2-baseline.md`
- `docs/build/build-host-baseline.md`
- `docs/build/cmake-options.md`
- `docs/build/build-feasibility-report.md`
- `docs/architecture/boot-path.md`
- `docs/architecture/runners.md`
- `docs/architecture/arm64-cortex-a35.md`
- `docs/architecture/null-renderer.md`
- `docs/architecture/graphics-paths.md`
- `docs/build/minimal-targets.md`
- `docs/testing/test-inputs.md`
- `docs/plans/first-build-experiment.md`
- `docs/arch-r/toolchain-layout.md`
- `docs/arch-r/toolchain-bootstrap.md`
- `docs/arch-r/package-build-entrypoints.md`
- `docs/arch-r/sysroot-readiness.md`
- `docs/arch-r/sysroot-population.md`
- `docs/arch-r/sysroot-exportability.md`
- `docs/arch-r/eerunner-sysroot-packages.md`
- `docs/arch-r/minimal-sysroot-plan.md`
- `docs/arch-r/build-resource-estimate.md`
- `docs/arch-r/ci-build-path.md`

Upstream reference initialization:

```bash
git clone --recurse-submodules <repository-url>
git submodule update --init --recursive
```
