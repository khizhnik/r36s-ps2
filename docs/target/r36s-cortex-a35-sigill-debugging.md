# R36S Cortex-A35 SIGILL Debugging

This document records the first real `SIGILL` localized on the R36S target
while running `pcsx2-eerunner` in `--mkstate` mode.

The goal is not to explain the final fix. The goal is to preserve a
reproducible investigative path that another developer can repeat from scratch:

deployment problem
-> runtime startup
-> SIGILL
-> process and thread identification
-> `strace -f -i`
-> `strace -f -k`
-> runtime PC
-> PIE offset
-> `addr2line` / `nm` / `objdump`
-> decoding the unknown opcode with `+lse`
-> exact `CASL` instruction
-> Cortex-A35 incompatibility

## Incident Summary

- Target: R36S
- SoC: RK3326
- CPU: Cortex-A35
- OS: Arch-R
- Architecture: AArch64
- Executable: `pcsx2-eerunner`
- Test mode: `--mkstate`
- ISO: already deployed on target
- Dynamic dependencies: resolved correctly
- `pcsx2-eerunner --version`: successful
- BIOS loading: not reached
- Savestate creation: not reached

The crash only appeared once the runner moved from startup into real VM /
runtime initialization. It did not happen during `--version`, which exits
before the VM starts.

## Environment

The runtime environment used for the failing launch was:

```bash
PWD=/storage/ports/pcsx2-eerunner-smoke
HOME=/storage/ports/pcsx2-eerunner-smoke/.home
XDG_CONFIG_HOME=/storage/ports/pcsx2-eerunner-smoke/.config
XDG_CACHE_HOME=/storage/ports/pcsx2-eerunner-smoke/.cache
XDG_DATA_HOME=/storage/ports/pcsx2-eerunner-smoke/.local/share
LD_LIBRARY_PATH=/storage/ports/pcsx2-eerunner-smoke/lib
```

The deployed bundle had already been staged successfully at:

```text
/storage/ports/pcsx2-eerunner-smoke
```

and `ldd ./bin/pcsx2-eerunner` reported no missing shared libraries.

## Confirmed Facts

### Target identity

The pre-deploy device snapshot recorded:

- `HW_DEVICE="RK3326"`
- `HW_CPU="Rockchip RK3326"`
- `HW_ARCH="aarch64"`
- `/proc/cpuinfo` `CPU part: 0xd04`
- `/proc/cpuinfo` `Features: fp asimd evtstrm aes pmull sha1 sha2 crc32 cpuid`

That matches the Cortex-A35 / RK3326 target class and shows no LSE feature in
the reported feature set.

Relevant evidence:

- [`artifacts/r36s-recompiler-tests-cortex-a35/pre-deploy-device-info.log`](../../artifacts/r36s-recompiler-tests-cortex-a35/pre-deploy-device-info.log)

### Early startup was healthy

The runner started far enough to print the normal boot logs:

- Program Path
- AppRoot Directory
- Resources Directory
- DataRoot Directory
- CPU detection
- controller mappings
- directory initialization

The last visible messages before the crash were still in early runtime setup.

Relevant evidence:

- [`artifacts/pcsx2-iso-smoke/20260729T170709Z/mkstate-launch.log`](../../artifacts/pcsx2-iso-smoke/20260729T170709Z/mkstate-launch.log)

### The failure was not storage or deployment

The original `No space left on device` issue was a separate deployment-stage
blocker. After storage migration, deployment succeeded and the launcher reached
runtime startup. The later `SIGILL` was therefore not caused by the old storage
problem.

### The failure was not missing shared libraries

`ldd` on the target resolved the bundle-local and system libraries correctly.
There was no `not found` entry left in the dependency chain.

### The failure was not `timeout`

The `timeout` wrapper reported that its child dumped core. The faulting process
was `pcsx2-eerunner`, not `timeout`.

## Diagnostic Command

The corrected runtime command used for the failing launch was:

```bash
cd /storage/ports/pcsx2-eerunner-smoke
export HOME="$PWD/.home"
export XDG_CONFIG_HOME="$PWD/.config"
export XDG_CACHE_HOME="$PWD/.cache"
export XDG_DATA_HOME="$PWD/.local/share"
export LD_LIBRARY_PATH="$PWD/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
timeout 30s ./bin/pcsx2-eerunner \
  --set EmuCore/EnableFastBoot=false \
  --mkstate /storage/ports/r36s-recompiler-tests-cortex-a35-smoke/states/first-boot.p2s \
  --frames 600 \
  --iso "/storage/ports/pcsx2-eerunner-smoke/.config/ARMSX2/discs/Grand Theft Auto - Vice City (Europe) (En,Fr,De,Es,It) (v3.00).iso"
```

This command is the one to reproduce when investigating the crash.

## Investigation Trail

### Stage 1: `strace -f -i`

The first trace used:

```bash
strace -f -i -e signal=all -o /storage/ports/pcsx2-eerunner-smoke/logs/mkstate.strace \
  timeout 30s ./bin/pcsx2-eerunner \
  --set EmuCore/EnableFastBoot=false \
  --mkstate /storage/ports/r36s-recompiler-tests-cortex-a35-smoke/states/first-boot.p2s \
  --frames 600 \
  --iso "/storage/ports/pcsx2-eerunner-smoke/.config/ARMSX2/discs/Grand Theft Auto - Vice City (Europe) (En,Fr,De,Es,It) (v3.00).iso"
```

What this proved:

- the `SIGILL` was delivered to `pcsx2-eerunner`
- the signal happened in a runtime-created worker thread
- the crashing thread was named `MTVU`
- `timeout` was only the wrapper that reported the child crash
- `dmesg` is not guaranteed to contain a helpful record for a userspace
  `SIGILL`

The trace showed the faulting thread receiving:

- `signal: SIGILL`
- `si_code: ILL_ILLOPC`
- `si_addr: 0xaaaabbd72e98`

### Stage 2: `strace -f -k`

The second trace used:

```bash
strace -f -k -e signal=all -o /storage/ports/pcsx2-eerunner-smoke/logs/mkstate-k.strace \
  timeout 30s ./bin/pcsx2-eerunner \
  --set EmuCore/EnableFastBoot=false \
  --mkstate /storage/ports/r36s-recompiler-tests-cortex-a35-smoke/states/first-boot.p2s \
  --frames 600 \
  --iso "/storage/ports/pcsx2-eerunner-smoke/.config/ARMSX2/discs/Grand Theft Auto - Vice City (Europe) (En,Fr,De,Es,It) (v3.00).iso"
```

This trace gave the decisive user-space backtrace:

```text
Threading::WorkSema::WaitForWorkWithSpin()
VU_Thread::ExecuteRingBuffer()
Threading::Thread::ThreadProc()
libc
```

The crashing thread was explicitly named:

```text
MTVU
```

The `strace -k` output localized the fault to:

- `Threading::WorkSema::WaitForWorkWithSpin()`
- caller: `VU_Thread::ExecuteRingBuffer()`
- source file: `upstream/armsx2/common/Semaphore.cpp`
- crashing operation: `std::atomic::compare_exchange_weak(...)`

Relevant trace evidence:

- `prctl(PR_SET_NAME, "MTVU") = 0`
- `SIGILL {si_signo=SIGILL, si_code=ILL_ILLOPC, si_addr=0xaaaabbd72e98}`
- backtrace into `WaitForWorkWithSpin()+0x34`

## Binary-Level Verification

### PIE / offset conversion

The target binary is a PIE executable:

- `readelf -Wl build/armsx2-eerunner-clang/bin/pcsx2-eerunner`
- ELF type: `DYN (Position-Independent Executable file)`
- first executable `LOAD` segment has virtual address `0x0`

This means the runtime virtual address has to be converted into a PIE-relative
offset before it can be mapped back to symbols and source lines.

The crash address was:

```text
0xaaaabbd72e98
```

The PIE-relative offset was:

```text
0x632e98
```

The load base is therefore:

```text
0xaaaabb740000
```

That is the base that makes:

```text
0xaaaabb740000 + 0x632e98 = 0xaaaabbd72e98
```

### Symbol lookup

The relevant symbol table entries were:

- `WaitForWorkWithSpin()` at `0x632e64`
- `ShortSpin()` at `0x627184`
- `UpdatePauseTime()` at `0x6271e4`
- `GetTickFrequency()` at `0x63def8`
- `GetCPUTicks()` at `0x63df00`

The `addr2line` / `llvm-addr2line` lookup for `0x632e98` resolved to:

```text
compare_exchange_weak
.../bits/atomic_base.h:536
```

The same binary lookup for `0x632e64` resolved to:

```text
WaitForWorkWithSpin()
upstream/armsx2/common/Semaphore.cpp:63
```

### Disassembly

The exact faulting instruction bytes at `0x632e98` were:

```text
6a fd a9 88
```

Without AArch64 LSE enabled, the disassembler reported the opcode as:

```text
<unknown>
```

With `+lse` enabled, the same 32-bit opcode decodes as:

```text
casl w9, w10, [x11]
```

That is the key technical result: a normal C++ atomic compare-exchange in the
host code path was lowered to an ARMv8.1 LSE atomic instruction.

Relevant commands used:

```bash
llvm-nm -n build/armsx2-eerunner-clang/bin/pcsx2-eerunner
llvm-addr2line -e build/armsx2-eerunner-clang/bin/pcsx2-eerunner -f -C 0x632e98
llvm-objdump -d --triple=aarch64 --start-address=0x632e90 --stop-address=0x632ea8 \
  build/armsx2-eerunner-clang/bin/pcsx2-eerunner
llvm-objdump -d --triple=aarch64 --mattr=+lse ...
```

## Root Cause

The first real `SIGILL` is in host code, not generated PS2 code.

The execution path is:

```text
main
-> mkstate runtime startup
-> VM startup
-> MTVU thread creation
-> VU_Thread::ExecuteRingBuffer()
-> Threading::WorkSema::WaitForWorkWithSpin()
-> std::atomic::compare_exchange_weak(...)
-> casl w9, w10, [x11]
```

This is a host-side ARMv8.1 LSE atomic instruction. The RK3326 / Cortex-A35
target reports only:

```text
fp asimd evtstrm aes pmull sha1 sha2 crc32 cpuid
```

in `/proc/cpuinfo` for each processor, which is consistent with a Cortex-A35
baseline and does not provide the LSE feature needed to execute `CASL`.

So the process receives `SIGILL` before:

- BIOS loading
- ELF startup
- savestate creation
- replay / `stepdiff`
- any generated EE runtime code becomes relevant

## Hypotheses Considered

### Ruled out by evidence

- Storage / deployment:
  - the original `No space left on device` failure was fixed by storage
    migration and was not the later SIGILL
- Incomplete ISO copy:
  - the ISO was already present on target and its path was verified
- `LD_LIBRARY_PATH`:
  - bundle-local libraries resolved correctly once the launcher was fixed
- Missing shared libraries:
  - `ldd` on target reported no `not found`
- `timeout` as the crashing executable:
  - `strace` showed the child `pcsx2-eerunner` thread faulting first
- BIOS content:
  - BIOS loading was not reached
- ISO / CDVD parsing:
  - no evidence that the boot path reached BIOS handoff or disc parsing
- Savestate serialization:
  - no savestate was created
- Generated EE JIT code:
  - no BIOS handoff or ELF boot was reached; the crash occurred in the
    host MTVU worker thread before the PS2 guest runtime was active

### Not yet part of this crash path

- Renderer initialization
- Input initialization beyond the startup mapping logs
- BIOS menu boot
- Replay / `stepdiff`

## Why `--version` Worked

`pcsx2-eerunner --version` succeeded because it exits early.

It does not create the VM, does not open the MTVU worker, and does not enter
`WaitForWorkWithSpin()`.

That means the incompatible `casl` instruction stays hidden during `--version`
but becomes visible as soon as the real VM startup path runs.

In other words:

- `--version`: parse-only startup, no MTVU thread, no host LSE crash
- `--mkstate`: real VM startup, MTVU thread created, host LSE crash exposed

## Reusable Debugging Procedure

This incident can be reproduced and localized on other ARM64 ports with the
same sequence:

1. Confirm executable startup separately from the failing runtime mode.
2. Separate wrapper failure from child-process failure.
3. Capture the signal address with `strace -f -i`.
4. Capture the user-space stack with `strace -f -k`.
5. Identify the crashing thread name.
6. Convert runtime virtual address to PIE-relative offset.
7. Use `readelf`, `nm`, and `addr2line` on the binary.
8. Disassemble the exact opcode with `objdump` or `llvm-objdump`.
9. Retry the decode with the correct ISA feature set, such as `+lse`.
10. Map the instruction back to CPU capabilities before changing build flags.

The important rule is to prove the crashing instruction class first. Do not
assume JIT, BIOS, or the guest code is responsible until the host instruction
has been identified.

## Lessons Learned

- A userspace `SIGILL` on ARM64 can come from ordinary C++ atomics, not only
  from JIT output.
- The `MTVU` worker thread is part of the real runtime startup path for
  `--mkstate`.
- `strace -f -i` and `strace -f -k` are sufficient to localize a host-side
  illegal instruction without changing code.
- A standard disassembler may hide the instruction as `<unknown>` until the
  right ISA features are enabled.
- The target CPU feature set matters as much as the guest emulator logic.

## Relevant Files

- `upstream/armsx2/common/Semaphore.cpp`
- `upstream/armsx2/common/HostSys.cpp`
- `upstream/armsx2/common/Linux/LnxMisc.cpp`
- `upstream/armsx2/pcsx2/MTVU.cpp`
- `build/armsx2-eerunner-clang/bin/pcsx2-eerunner`

## Artifacts

- `artifacts/r36s-recompiler-tests-cortex-a35/pre-deploy-device-info.log`
- `artifacts/pcsx2-iso-smoke/20260729T170709Z/target-preflight.log`
- `artifacts/pcsx2-iso-smoke/20260729T170709Z/mkstate-launch.log`
- `artifacts/pcsx2-iso-smoke/20260729T170709Z/diagnostic-launch.log`

Target-side trace files preserved during investigation:

- `/storage/ports/pcsx2-eerunner-smoke/logs/mkstate.strace`
- `/storage/ports/pcsx2-eerunner-smoke/logs/mkstate-k.strace`
