# Runner Roles

Audit date: 2026-07-27

This document separates full-system runtimes from narrow harnesses.

## Summary table

| Target | Full VM | BIOS | EE JIT | VU JIT | GS | Window | Protected input required | Value for first Cortex-A35 test |
| ------ | ------: | ---: | -----: | -----: | -: | -----: | -----------------------: | ------------------------------- |
| `pcsx2-eerunner` | yes | yes | yes | yes | yes | no | no for synthetic / state-based modes | highest for headless full-system bring-up |
| `pcsx2-vurunner` | no | no | no | yes | no | no | no if using synthetic `.vucap` fixtures | highest for isolated VU backend validation |
| `pcsx2-gsrunner` | yes | sometimes | yes | yes | yes | yes | usually yes, via GS dumps | useful for GS replay, not first target |
| `pcsx2-sdl` | yes | yes | yes | yes | yes | yes | BIOS or disc required for meaningful boot | best later for handheld runtime validation |
| `pcsx2-libretro` | yes | partial | yes | yes | yes | no host window | frontend content / negotiation data | useful later for frontend integration |

The most important correction from the earlier baseline is that `pcsx2-eerunner` is not merely a JIT unit test. It is a full-system VM runner. It is still the best first build target, because it removes the GUI, window-system, and audio layers while still reaching BIOS and EE execution.

## pcsx2-eerunner

Source:

- `pcsx2-eerunner/Main.cpp`

Inputs:

- BIOS image
- optional ISO / ELF / savestate / GS dump / synthetic modes
- command line flags such as `--bios-only`, `--renderer`, `--selfcheck`, `--localize`, `--repro`

Behavior:

- full VM lifecycle
- BIOS boot supported
- EE interpreter and EE AArch64 dynarec are both reachable
- VU and GS subsystems are still initialized
- default renderer is Null
- default host render window is surfaceless / headless
- no UI window is created
- no audio output is required for the Null backend

What it is good for:

- first ARM64 host binary
- deterministic EE bring-up
- BIOS boot without GUI
- JIT-vs-interpreter diagnostics

What it is not:

- not a narrow EE-only test
- not a pure compile-only harness
- not a substitute for graphics validation

## pcsx2-vurunner

Source:

- `pcsx2-vurunner/Main.cpp`
- `tests/ctest/core/recompilers/harness/RecompilerTestEnvironment.cpp`
- `tests/ctest/core/recompilers/harness/VuReplay.cpp`
- `tests/ctest/core/recompilers/harness/VuSnapshot.cpp`

Inputs:

- `.vucap` capture files
- optional replay metadata
- no BIOS and no disc image are required

Behavior:

- not a full VM
- no BIOS boot
- no CDVD boot
- no GS renderer
- no window
- exercises microVU codegen and interpreter replay

What it is good for:

- isolated ARM64 VU backend smoke tests
- JIT shape checks
- persisted-JIT cache validation

What it is not:

- a route to BIOS boot
- a way to validate full-system boot timing

## pcsx2-gsrunner

Source:

- `pcsx2-gsrunner/Main.cpp`
- `pcsx2-gsrunner/RenderDocCapture.cpp`

Inputs:

- GS dumps and related replay inputs
- optional renderer selection
- optional RenderDoc integration

Behavior:

- full VM lifecycle
- GS-focused
- creates a real host display path when needed
- can use Wayland/X11 platform code on Linux
- not headless by default

What it is good for:

- GS replay
- renderer debugging
- display path validation

What it is not:

- the smallest boot target
- the cleanest first headless experiment

## pcsx2-sdl

Source:

- `pcsx2-sdl/Main.cpp`

Inputs:

- BIOS or disc image
- CLI `--bios-only`
- CLI `--no-fast-boot`

Behavior:

- full VM lifecycle
- BIOS boot supported
- handheld-friendly direct-display flow
- SDL input and audio
- Vulkan direct-display path preferred
- Wayland fallback exists

What it is good for:

- later handheld runtime work
- direct-display validation
- path closer to the real R36S deployment

What it is not:

- the smallest dependency closure
- the cleanest first target for backend bring-up

## pcsx2-libretro

Source:

- `pcsx2-libretro/Main.cpp`

Behavior:

- shared library core
- headless host display path
- starts with Vulkan negotiation when available
- can fall back to Null GS if the frontend refuses Vulkan
- designed around frontend content negotiation, not as a first boot target

What it is good for:

- libretro integration
- headless core embedding

What it is not:

- the lowest-risk first BIOS boot target

## Recommendation

The best first target remains `pcsx2-eerunner`.

Reason:

- it is the smallest full-system runtime that still reaches BIOS and EE execution
- it avoids a real window, compositor, and normal user-facing UI
- it can be forced into Null renderer mode
- it is more informative than `pcsx2-vurunner`, which is not a full VM
