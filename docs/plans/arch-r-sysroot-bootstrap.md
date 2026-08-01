# Arch-R Sysroot Bootstrap Plan

This is a proposal, not a build request.

## Preconditions

- Arch-R clone: `research/upstream/arch-r`
- pinned commit: `c9fa2ae9d33cbc1111985bfb81b59db30740de26`
- target: `PROJECT=ArchR DEVICE=RK3326 ARCH=aarch64`
- a clean build directory
- enough free disk to keep the bootstrap artifacts and logs

## First practical command

The next stage should start with the smallest package-chain probe that proves the bootstrap path, not the final distro image:

```bash
PROJECT=ArchR DEVICE=RK3326 ARCH=aarch64 ./scripts/build toolchain
```

That command is only a proposal for the next stage and is not executed here.

## Stop condition

Stop after:

- the cross toolchain exists
- the shared sysroot is present
- C and C++ probes can be built externally
- no image assembly has started

## Verification ladder

1. `hello-c`
2. `hello-cpp`
3. `atomic-cpp`
4. `mmap-jit-probe`
5. then reevaluate ARMSX2 package closure

## Rollback boundaries

- do not touch system directories
- keep build output inside the Arch-R build tree
- keep logs under the build directory or the research notes area
- do not delete live filesystem content

## Decision gate

Before any actual build in the next stage, ask for permission to install host dependencies and run the selected bootstrap phase.
