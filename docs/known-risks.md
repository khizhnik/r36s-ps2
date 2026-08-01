# Known Risks

Status vocabulary:

- `CONFIRMED_BY_SOURCE`
- `CONFIRMED_BY_BUILD`
- `CONFIRMED_BY_RUNTIME`
- `HYPOTHESIS`
- `BLOCKED`
- `REFUTED`

## Current claims

| Claim | Initial status | Current note |
| --- | --- | --- |
| `pcsx2-eerunner` configures without Qt | `CONFIRMED_BY_SOURCE` | Source shows it is in its own subdirectory and Qt is only added when `ENABLE_QT_UI` is on. |
| `pcsx2-eerunner` builds without SDL frontend | `CONFIRMED_BY_SOURCE` | The target does not link SDL3 directly. |
| Null renderer does not require GPU API | `CONFIRMED_BY_SOURCE` | `GSDeviceNone::GetRenderAPI()` returns `RenderAPI::None`. |
| BIOS can execute with Null renderer | `CONFIRMED_BY_SOURCE` | Source supports the path, but it is not runtime-proven yet. |
| `pcsx2-eerunner` builds on ARM64 host | `HYPOTHESIS` | Not tested. This host is `x86_64`. |
| `pcsx2-eerunner` works on Cortex-A35 | `HYPOTHESIS` | Not tested. |
| ARMv8-A is sufficient for the dynarec | `HYPOTHESIS` | Source suggests the backend is close, but build defaults still assume ARMv8.1-A atomics. |
| LSE is required only by the host binary, not by generated JIT code | `HYPOTHESIS` | Needs compile/runtime evidence. |
| `-moutline-atomics` solves Cortex-A35 compatibility | `HYPOTHESIS` | Unproven. |
| Core can be built without Vulkan/OpenGL development stack | `HYPOTHESIS` | Not tested. |
| Null-only configuration removes graphical backend objects | `HYPOTHESIS` | Needs build-graph proof. |

## Current hard blocker

- `BLOCKED`: the local build host does not have `cmake` in `PATH`.
- `BLOCKED`: the local build host is `x86_64`, so the intended ARM64/Cortex-A35 build cannot be exercised natively here.

## What this means

The current stage can still produce source-level CMake and dependency maps, but it cannot yet perform the requested configure/build feasibility experiment on this machine.
