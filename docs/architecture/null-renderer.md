# Null Renderer

Audit date: 2026-07-27

Relevant symbols:

- `GSDeviceNone`
- `GSRendererNull`
- `RenderAPI::None`
- `GSRendererType::Null`

## What it disables

The Null renderer disables real graphics API usage.

Confirmed by source:

- `GSDeviceNone::GetRenderAPI()` returns `RenderAPI::None`
- `GSDeviceNone::DoBeginPresent()` always returns `FrameSkipped`
- `GSRendererNull::Draw()` is empty
- `GSRendererNull::GetOutput()` returns `nullptr`

## What still runs

The GS subsystem still exists.

This matters:

- the GS thread still opens
- the renderer still receives VSync calls
- textures still exist as RAM-backed stubs
- the VM still has a GS subsystem to talk to

`GSDeviceNone` is therefore a headless GS device, not a total GS shutdown.

## Host display

No real host display is required for the Null path.

Evidence:

- `Host::AcquireRenderWindow()` can return a surfaceless window in the headless runners
- `GSDeviceNone::HasSurface()` returns true only for nominal layout purposes, not because it needs a visible surface
- there is no swapchain creation in the Null device

## Audio

Null renderer does not imply Null audio.

Audio is controlled separately by `AudioStream::AudioBackend`.

Confirmed behavior:

- `AudioBackend::Null` exists
- `AudioStream::CreateNullStream()` creates a zero-output stream
- `SPU2::CreateOutputStream()` chooses the backend from config

## BIOS boot with Null renderer

Yes, the upstream tree can boot BIOS with the Null renderer, provided a valid BIOS is present.

Reason:

- `VMManager::Initialize()` still loads BIOS
- `GSopen()` still succeeds with `GSRendererType::Null`
- the CPU thread still executes normally after VM state changes to Running

This is one of the strongest facts for the first build target.

## Can BIOS hang without presentation?

The code does not require presentation for the Null path.

However:

- BIOS execution still depends on the GS subsystem being initialized
- timing-sensitive boot code can still expose unrelated bugs
- lack of presentation does not mean lack of GS work

## Framebuffer dump and screenshot paths

Useful diagnostic paths already exist:

- GS dump capture
- GSDump replay
- readback texture support in the GS stack
- headless runner hooks in `pcsx2-eerunner`

That means a headless diagnostic loop is already partially present.

## Difference from Software renderer

Null renderer:

- consumes the GS stream
- does not draw
- does not produce a real image

Software renderer:

- consumes the GS stream
- rasterizes on CPU
- can produce a framebuffer for presentation or capture

Software rendering is much more expensive but is far more useful for visual validation.

## Minimum host layer for full VM + Null

Minimum practical stack:

- CPU thread
- VMManager
- GS thread
- Null GS device / renderer
- Null audio backend
- some form of host settings layer
- filesystem access for BIOS and runtime data

No GUI window is required.

## Final answer

Does an upstream full Linux ARM64 runtime already exist that can load BIOS with Null renderer without Qt and without a physical GPU?

`yes`

Qualification:

- `pcsx2-eerunner` already models exactly that kind of runtime
- it still depends on a valid BIOS image
- it is headless, but it is not BIOS-free
