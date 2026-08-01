# Build Feasibility Report

Audit date: 2026-07-27

## Environment

- host architecture: `x86_64`
- compiler: GCC 12.2.0 available; Clang not installed
- CMake: not installed in `PATH`
- generator: Ninja 1.11.1 and GNU Make 4.3 available
- memory: 46 GiB total, 28 GiB available
- disk: 46 GiB free on the working filesystem
- page size: 4096

## Profiles

| Profile | Configure | Compile | Link | Runtime help | Effective ISA | First blocker |
| ------- | --------: | ------: | ---: | -----------: | ------------- | ------------- |
| Profile A upstream ARM64 baseline | blocked | not run | not run | not run | not established | missing `cmake` |
| Profile B explicit ARMv8-A | blocked | not run | not run | not run | not established | missing `cmake` |
| Profile C Cortex-A35 | blocked | not run | not run | not run | not established | missing `cmake` |
| Profile D Cortex-A35 + outlined atomics | not attempted | not run | not run | not run | not established | dependent on Profile C |

## Target availability

- factually defined target names exist in upstream: `pcsx2-eerunner`, `pcsx2-vurunner`, `pcsx2-gsrunner`, `pcsx2-sdl`, `pcsx2-libretro`, `pcsx2-qt`
- minimum configure command is not executable on this host because `cmake` is absent
- required dependencies were not resolved by a configure run
- optional dependencies were identified from source only

## ARM ISA findings

- upstream default desktop ARM64 baseline is `-march=armv8.1-a`
- ARMv8-A override is present only as a downstream idea in the preset scaffolding, not as a tested build result
- Cortex-A35 override is not build-proven
- outlined atomics are not build-proven
- no disassembly evidence exists yet because no object files were produced

## Dependency findings

- Null runtime closure was mapped from source only, not build-verified
- renderer source inclusion is still controlled at CMake time by `USE_OPENGL` and `USE_VULKAN`
- Vulkan/OpenGL headers and libraries are still part of the upstream core discovery path unless a future configure run proves otherwise
- the build graph has not been generated yet, so closure size remains theoretical

## Conclusions

1. `pcsx2-eerunner` is not build-proven on this host.
2. `-march=armv8-a` and `-mcpu=cortex-a35` are not build-proven on this host.
3. `-moutline-atomics` remains an untested fallback.
4. No ELF or object files were produced.
5. No LSE instructions were observed in objects or binaries, because none exist yet.
6. Vulkan/OpenGL headers are not proven avoidable at build time yet.
7. The first real blocker is the missing `cmake` executable.
8. Because the host is `x86_64`, this machine is not a native ARM64 build host for the requested target.
9. Downstream CMake/toolchain scaffolding is prepared, but not exercised.
10. The project is not yet ready for an R36S artifact from this host.
