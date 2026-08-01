# First Build Experiment

This is a plan, not an implementation.

## 1. First target

Build `pcsx2-eerunner` first.

Why:

- smallest full-system runtime that still reaches BIOS and EE execution
- no Qt
- no real window
- can run with Null GS
- can run without audio output
- gives the earliest signal on ARM64 dynarec viability

## 2. Second target

Build `pcsx2-vurunner` second.

Why:

- isolates microVU codegen and replay behavior
- helps separate full-system failures from VU backend failures

## 3. Initial compile flags

Start with the upstream defaults.

If a Cortex-A35 experiment is needed later, the likely direction is:

- `-march=armv8-a`
- `-mcpu=cortex-a35`

Do not change the host baseline yet.

## 4. Functions to keep disabled initially

- GUI-heavy paths
- optional debug overlays
- RenderDoc
- nonessential frontend integration

## 5. Build host dependencies

The build host should already provide whatever the selected target needs from the current tree:

- CMake
- compiler toolchain
- SDL3 for `pcsx2-sdl`
- Qt only for `pcsx2-qt`
- Vulkan / OpenGL development headers as required by the full core build

Do not install system packages in this phase without explicit approval.

## 6. Cross-compilation vs native ARM64

Prefer native ARM64 compilation on the actual host architecture when the experiment reaches that point.

For now, do not assume cross-compilation is necessary.

## 7. Binary verification without the R36S

Initial verification can happen on the build machine by:

- checking the linker output
- checking target dependencies
- checking that the binary starts in headless mode
- checking that the correct runner flags are accepted

No SSH deployment is part of this plan.

## 8. Success criteria

- Milestone A: ARM64 backend compiles
- Milestone B: host-side runner starts
- Milestone C: synthetic EE code executes
- Milestone D: VU test executes
- Milestone E: full VM starts with Null renderer
- Milestone F: BIOS loads
- Milestone G: first rendered frame

## 9. Expected failure classes

- compiler failure
- ISA incompatibility
- JIT failure
- memory mapping failure
- frontend failure
- renderer failure

## 10. How to separate failures

- compiler failure: build stops before link
- ISA incompatibility: SIGILL or illegal instruction on first launch
- JIT failure: runner starts but codegen or execution diverges
- memory mapping failure: allocation, mprotect, or icache flush errors
- frontend failure: runner starts but host display or input layer fails
- renderer failure: VM starts but GS cannot open or present
