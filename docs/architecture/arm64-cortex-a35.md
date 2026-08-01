# ARM64 and Cortex-A35 Audit

Audit date: 2026-07-27

Target CPU:

- ARM Cortex-A35
- AArch64
- ARMv8-A baseline
- NEON

## 3.1 Architectural baseline

### Where `-march=armv8.1-a` is set

The desktop ARM64 default is set in:

- `cmake/BuildParameters.cmake`

The relevant logic is:

- ARM64 is detected from `CMAKE_SYSTEM_PROCESSOR`
- on non-MSVC ARM64, the build adds `-march=armv8.1-a` unless the user already provided a different `-march` in `CMAKE_CXX_FLAGS`
- the comment in that file explicitly ties the choice to atomic RMW / LSE availability

### Which targets get it

The default applies to the regular desktop ARM64 build path, including the Linux desktop configuration that builds the standalone frontends and the core.

Android is different:

- Android ARM64 uses `-march=armv8-a`
- that is a separate build path, not a proof that the Linux path is equivalent

### Is it a historical choice or a hard code requirement?

It is a build-system choice, not evidence that the core dynarec itself must always emit v8.1-only instructions.

The code comments show why the default exists:

- the host binary uses atomic RMW operations that the project expects to have in the baseline
- the default protects the common desktop ARM64 path from silent SIGILL on ARMv8.0 cores without LSE

### Conditional compilation by ARM architecture level

Yes.

The tree uses:

- `ARCH_ARM64`
- `__aarch64__`
- `_M_ARM64`
- separate `arm64/` source lists
- separate Android ARM64 build decisions

The source set is not identical between Linux ARM64 and Android ARM64.

## 3.2 Used instructions

I did not find evidence that the emulator core unconditionally requires:

- FP16 arithmetic
- dot product
- SVE
- SVE2
- AES
- SHA
- RDM
- ARMv8.2+ as a hard baseline

What I did find:

- the host runtime reports `NEON`, `LSE`, `CRC32`, `SVE`, and `SVE2` when present
- that report is diagnostic and does not prove each feature is mandatory
- VIXL contains support for much richer instruction sets, but the emulator code here does not require the whole catalog

### Host-binary vs generated-code split

1. Host binary requirements:
   - compiler baseline flags
   - libatomic / atomics semantics
   - page-size and cache-line assumptions
   - executable-memory / W^X management
   - instruction cache flushes

2. Runtime-generated code:
   - direct AArch64 EE / IOP / VU dynarec output
   - VIXL-emitted host code

3. Optional optimized paths:
   - NEON helpers
   - SPU2 SIMD backends
   - any feature-detected fast paths in support libraries

4. Unconditional requirement confirmed by source:
   - the desktop Linux ARM64 build default expects `-march=armv8.1-a` unless overridden

## 3.3 Cortex-A35 compatibility

Theoretical target flags:

- `-march=armv8-a`
- `-mcpu=cortex-a35`

This is not yet an endorsed build configuration. It is the compatibility question.

### What looks compatible already

- AArch64 backend code exists directly for EE, IOP, COP0, COP2, FPU, MMI, VIF, VU, and VTLB
- the dynarec does not rely on an x86 host backend
- instruction cache flushes and executable-memory toggling are handled in `common/HostSys.cpp` and `pcsx2/arm64/AsmHelpers.cpp`
- the code has explicit handling for page size and cache line size on Linux ARM64

### What blocks immediate use of `-mcpu=cortex-a35`

Main blocker:

- the default desktop ARM64 build flags request `-march=armv8.1-a`

Additional compatibility risks to check before any actual build:

- host atomics
- compiler-emitted LSE instructions
- page-size assumptions
- runtime cache-line assumptions
- JIT code-cache mapping and W^X behavior
- instruction-cache invalidation
- any hidden use of host extensions through compiler or third-party code

### Table

| Requirement | Cortex-A35 supports it | Mandatory in ARMSX2 | Optional path | Expected change |
| ----------- | ---------------------: | ------------------: | ------------: | --------------- |
| AArch64 + NEON | yes | yes | no | none expected |
| LSE atomics | no | the desktop Linux default assumes them | possible with `-march=armv8-a -moutline-atomics` | build flag override needed |
| ARMv8.1 baseline | no | default on desktop Linux ARM64 | no | build flag override needed |
| FP16 / dot product | generally no | not proven mandatory here | optional fast paths only | none yet proven |
| SVE / SVE2 | no | not proven mandatory here | optional or diagnostic only | none yet proven |
| W^X + icache flush | yes | yes | no | none expected |
| mmap / mprotect / executable memory | yes | yes | no | none expected |
| Cache-line alignment assumptions | yes | yes | no | validate against runtime values |

### Current conclusion

`-march=armv8-a -mcpu=cortex-a35` may be plausible in principle, but it is not yet proven safe for the default Linux desktop build path because that path currently assumes ARMv8.1 atomics.

The backend code itself looks much closer to ARMv8-A than the build default does.
