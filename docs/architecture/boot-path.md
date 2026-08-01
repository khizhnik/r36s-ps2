# Boot Path Map

Audit date: 2026-07-27

This document traces the actual source paths for the main PS2 workload entry points in the pinned ARMSX2 commit `0dbf7bd54b9f5945f5dfbcbb89c354f73ccccbae`.

The key finding is that the runtime does not use a single literal `BootSystem()` function in this tree. The effective boot path is:

`frontend main() -> CPU thread init -> VMManager::Initialize() -> subsystem opens -> VMManager::SetState(Running) -> VMManager::Execute() -> CPU backend dispatch`

The BIOS-to-EE transition is handled by the BIOS/EELOAD hooks in `pcsx2/Interpreter.cpp` and `pcsx2/R5900.cpp`, not by a standalone bootstrap helper.

## Common Core Sequence

Across the full-system frontends and runners:

`main() -> ParseCommandLineArgs() / frontend config -> SysMemory::ReserveMemory() -> CPUThreadMain() -> VMManager::Internal::CPUThreadInitialize() -> VMManager::ApplySettings() -> VMManager::Initialize() -> GSopen() -> SPU2::Open() -> Pad::Initialize() -> SIO2/SIO0/DEV9/USB/FW init -> hwReset() -> VMManager::SetState(Running) -> VMManager::Execute()`

Relevant files and symbols:

- `pcsx2-sdl/Main.cpp`
- `pcsx2-eerunner/Main.cpp`
- `pcsx2-gsrunner/Main.cpp`
- `pcsx2-libretro/Main.cpp`
- `pcsx2/VMManager.cpp`
- `pcsx2/GS/GS.cpp`
- `pcsx2/MTGS.cpp`
- `pcsx2/Interpreter.cpp`
- `pcsx2/R5900.cpp`

## 1. BIOS boot without a game

Entry path:

`pcsx2-sdl::main()` or `pcsx2-eerunner::main()`
`-> ParseCommandLineArgs()`
`-> VMBootParameters with NoDisc / --bios-only`
`-> CPUThreadMain()`
`-> VMManager::Initialize()`
`-> LoadBIOS()`
`-> CDVD open`
`-> GS open`
`-> SPU2 open`
`-> hwReset()`
`-> VMManager::SetState(Running)`
`-> VMManager::Execute()`

Actual BIOS-to-EE execution:

- `pcsx2/ps2/BiosTools.cpp::LoadBIOS()`
- `pcsx2/VMManager.cpp::Initialize()`
- `pcsx2/Interpreter.cpp::intExecute()`
- `pcsx2/Interpreter.cpp::eeloadHook()`
- `pcsx2/R5900.cpp::eeloadHook2()`
- `pcsx2/VMManager.cpp::Internal::EntryPointCompilingOnCPUThread()`

Boot detail:

- `VMManager::Initialize()` always loads the BIOS unless the session is replaying a GS dump.
- After the BIOS is loaded, the normal subsystem init continues.
- The BIOS itself executes inside the EE loop after `VMManager::Execute()` hands control to the CPU backend.

## 2. Fast boot without BIOS animation

Source path:

`pcsx2-sdl/Main.cpp` or `pcsx2-eerunner/Main.cpp`
`-> VMBootParameters.fast_boot = true`
`-> VMManager::Initialize()`
`-> Hle_SetHostRoot()`
`-> EELOAD / eeloadHook()`
`-> optionally eeloadHook2()`
`-> entry point compile`

Relevant mechanics:

- `VMManager::Initialize()` computes `s_fast_boot_requested`.
- `Interpreter.cpp::eeloadHook()` detects the first `EELOAD` call.
- In fast boot mode it rewrites the `rom0:OSDSYS` path to the game ELF or host ELF override.
- `R5900.cpp::eeloadHook2()` injects launch arguments when present.
- `VMManager::Internal::EntryPointCompilingOnCPUThread()` marks the point where the ELF has started executing.

This is not a BIOS animation path. It is a direct launch path that bypasses the normal BIOS startup sequence once the ELF is known.

## 3. Full boot through BIOS

Source path:

`pcsx2-sdl/Main.cpp`
`-> --no-fast-boot`
`-> VMManager::Initialize()`
`-> LoadBIOS()`
`-> BIOS runs`
`-> EELOAD / OSDSYS / PS2LOGO`
`-> eeloadHook()`
`-> game ELF entry`

Fact from source:

- `Docs/PCSX2_FAQ.md` says fast boot directly mounts and launches the game without launching the BIOS.
- `pcsx2-sdl/Main.cpp` exposes `--no-fast-boot` specifically to preserve the BIOS animation.
- `VMManager::Initialize()` reads `fast_boot` late, so the frontend or per-game config can override it.

## 4. EE runner

`pcsx2-eerunner/Main.cpp`

Entry path:

`main() -> ParseCommandLineArgs() -> CPUThreadMain() -> VMManager::Initialize() -> VMManager::SetState(Paused) -> mode-specific runner -> VMManager::Execute()`

This runner is full-system, but its intended use is deterministic EE analysis:

- it runs headless
- it defaults to the Null GS renderer
- it can switch renderers with `--renderer`
- it can boot BIOS with `--bios-only`
- it can run live boot or state-based analysis modes

## 5. VU runner

`pcsx2-vurunner/Main.cpp`

This is not a full VM boot path.

Entry path:

`main() -> ParseArgs() -> load .vucap fixtures -> RecompilerTestEnvironment -> microVU replay`

There is no BIOS boot, CDVD boot, or full VM lifecycle here.

## 6. GS runner

`pcsx2-gsrunner/Main.cpp`

This runner is GS-centric, not headless:

`main() -> ParseCommandLineArgs() -> platform window / RenderDoc setup -> CPUThreadMain() -> VMManager::Initialize() -> VMManager::SetState(Running) -> VMManager::Execute()`

It is useful for GS replay and renderer inspection, but it is not the minimal BIOS path.

## Answers to the core questions

- Can BIOS execute with the Null renderer? Yes, if a BIOS is present. `GSRendererType::Null` is accepted, and `GSDeviceNone`/`GSRendererNull` keep the GS subsystem alive without a GPU API.
- Is GS initialized under Null renderer? Yes. `VMManager::Initialize()` still opens GS, and `GSopen()` still creates a device and renderer pair.
- Does Null renderer require a window or swapchain? No. `GSDeviceNone::HasSurface()` returns true for a nominal surface, but `DoBeginPresent()` always returns `FrameSkipped`, and `Host::AcquireRenderWindow()` can return `WindowInfo::Type::Surfaceless`.
- Is SPU2/audio required? The core opens SPU2 during VM init, but `AudioStream::AudioBackend::Null` exists and `SPU2::CreateOutputStream()` uses it. Audio can be disabled by backend selection, not by skipping core init.
- Can audio be disabled without changing core code? Yes, via the Null audio backend in settings. I did not find a dedicated CLI flag in the inspected frontends.
- Can VM start without Qt frontend? Yes. `pcsx2-sdl`, `pcsx2-eerunner`, `pcsx2-gsrunner`, and `pcsx2-libretro` all start the VM without Qt.
- Can `pcsx2-sdl` do full BIOS boot? Yes. It has `--bios-only` and `--no-fast-boot`.
- Are there CLI flags for BIOS boot, fast boot, fullscreen, renderer selection, and audio disabling? BIOS boot and fast boot exist in `pcsx2-sdl`; renderer selection exists in `pcsx2-eerunner` and `pcsx2-gsrunner`; fullscreen mode exists in `pcsx2-sdl`. I did not find a stable CLI audio-disable switch in the inspected frontends.

## Direct source anchors

- `pcsx2/VMManager.cpp::Initialize`
- `pcsx2/VMManager.cpp::Execute`
- `pcsx2/ps2/BiosTools.cpp::LoadBIOS`
- `pcsx2/Interpreter.cpp::intExecute`
- `pcsx2/Interpreter.cpp::eeloadHook`
- `pcsx2/R5900.cpp::eeloadHook2`
- `pcsx2/GS/GS.cpp::GSopen`
- `pcsx2/GS/Renderers/Null/GSDeviceNone.cpp`
- `pcsx2/GS/Renderers/Null/GSRendererNull.cpp`
