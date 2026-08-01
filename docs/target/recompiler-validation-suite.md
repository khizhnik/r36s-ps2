# Recompiler Validation Suite

This document defines the first Cortex-A35 validation suite for
`recompiler_tests`.

Scope:

- BIOS-free only
- EE JIT only
- no ISO, no ELF boot, no VM boot, no SPU/GPU workloads
- no IOP/VU suites

The suite intentionally mixes:

- `Run()` tests, which execute the ARM64 EE JIT and compare against the interpreter
- a few `RunJitNoDiff()` tests, which exercise JIT-specific behavior that is not well represented by a JIT-vs-interpreter diff

The selected tests all live under `tests/ctest/core/recompilers/` and use
`EeRecTestHarness` or its harness helpers. They are BIOS-free by construction
because they run against `RecompilerTestEnvironment`, not `VMManager` boot
paths.

## Selection Criteria

- small enough to run regularly on RK3326
- covers the main EE JIT categories
- avoids duplicate tests that probe the same semantic in only a slightly
  different form
- prefers deterministic workloads
- prefers tests whose behavior is visible from source without BIOS or game data

## Recommended Suite

| Filter | Mode | Representative opcodes | Coverage | Why it is included |
| --- | --- | --- | --- | --- |
| `EeRecHarnessValidation.TestOne_SetsRegisterToKnownPoison` | `Run()` | `NOP` | harness sanity, no-op baseline | proves the harness executes a JITed program and preserves a seeded GPR value |
| `EeRecHarnessValidation.MultipleRunsInSameTestAreIdempotent` | `Run()` | `ADDU` | repeated run in one harness | confirms `Run()` is stable across repeated invocations in the same process |
| `EeRecAlu.AddiuSignExtend` | `Run()` | `ADDIU` | integer immediate arithmetic | basic sign extension and scalar ALU codegen |
| `EeRecShift.SllSignExtendsHighBit` | `Run()` | `SLL` | shifts, sign extension | checks a canonical bit-shift result that crosses the sign bit |
| `EeRecBranch.BeqTaken` | `Run()` | `BEQ` | taken branch | verifies branch target and delay-slot handling on the taken path |
| `EeRecBranch.BeqNotTaken` | `Run()` | `BEQ` | not-taken branch | verifies the opposite control-flow path |
| `EeRecBranchInDelay.InnerJalInDelaySlotIsSquashed` | `RunJitNoDiff()` | `JR`, `JAL` in delay slot | branch-in-delay squashing | covers a JIT-specific corner case that the diff harness does not model as directly |
| `EeRecJump.JalrLinkRegisterExplicitSeparateFromJumpTarget` | `Run()` | `JALR`, `NOP` | call/return, link register | verifies `JALR` link semantics and target capture |
| `EeRecLoadStore.LwrLwlPairUnalignedWordLoad` | `Run()` | `LWR`, `LWL` | unaligned memory access | exercises the paired `LWR`/`LWL` reconstruction path |
| `EeRecMulDiv.DivSimple` | `Run()` | `DIV` | divide, HI/LO | minimal HI/LO-producing arithmetic path |
| `EeRecCop0.Mtc0ThenMfc0Roundtrip` | `Run()` | `MTC0`, `MFC0` | COP0 | checks scalar coprocessor round-trip without BIOS side effects |
| `EeRecFpu.Mtc1MovesGprBitsToFpr` | `Run()` | `MTC1` | GPR/FPR move | verifies raw bit transfer into COP1 state |
| `EeRecFpu.AddSInteger` | `Run()` | `ADD_S` | scalar FPU arithmetic | simple, deterministic single-precision arithmetic |
| `EeRecFpuGuardBit.SubMasksOneGuardBit` | `RunJitNoDiff()` | `SUB_S` | FPU guard-bit masking | JIT-specific guard-bit path that is more explicit than a generic arithmetic test |
| `EeRecMmi.MaddAccumulates32Bit` | `Run()` | `MADD` | MMI / HI/LO accumulation | exercises the integer multiply-accumulate path and low-half writeback |
| `EeRecTraps.TeqTakenInDelaySlotSetsCauseBdAndBranchEpc` | `Run()` | `BEQ`, `TEQ`, `ADDIU` | exception path, BD/EPC | validates trap behavior in a delay slot, which is stricter than a plain taken trap |
| `EeRecMultiblock.ThreeBlockChainExecutesInOrder` | `Run()` | `ADDIU`, `J`, `NOP` | multi-block chaining | ensures sequential block chaining and dispatch order work correctly |
| `EeRecPinnedGpr.ScalarReadsOfPinnedRegs` | `Run()` | `OR`, `ADDIU`, `DADDU`, `SLTI`, `DSLL` | pinned GPR residency | exercises pinned-register reads/writes and the live-mirror path |
| `EeRecTimeoutLoop.SelfLoopWithAluBodyIsNotSkipped` | `Run()` | `ADDIU`, `BNE`, `NOP`, `J` | loop residency, timeout-loop guard | makes sure a self-loop with real work is not optimized away |
| `EeRecSmc.TriggerSmcHelperRewritesMemory` | `Run()` | `LW` | self-modifying code | validates memory rewrite + recompile discipline |

## Excluded Tests

Excluded from the first official suite:

- `RunInterpOnly()` tests, because they do not execute the ARM64 JIT
- broader `RunJitNoDiff()` variants that duplicate coverage already exercised by a nearby `Run()` test
- IOP and VU suites, because this suite is specifically for ARM64 EE JIT validation
- the harness tautology test `EeRecHarnessValidation.DiffJitVsInterpIsTautologicalUnderDelegatingHarness`, because it is not a meaningful end-user validation workload

## Risk Levels

- Level 1: harness sanity and scalar ALU
- Level 2: branches, jumps, delay slots
- Level 3: memory and unaligned accesses
- Level 4: multiply/divide, COP0, FPU, MMI
- Level 5: traps and delay-slot exceptions
- Level 6: multi-block chaining, pinned registers, loop residency, SMC

## Full Filter String

One test per line:

```text
EeRecHarnessValidation.TestOne_SetsRegisterToKnownPoison
EeRecHarnessValidation.MultipleRunsInSameTestAreIdempotent
EeRecAlu.AddiuSignExtend
EeRecShift.SllSignExtendsHighBit
EeRecBranch.BeqTaken
EeRecBranch.BeqNotTaken
EeRecBranchInDelay.InnerJalInDelaySlotIsSquashed
EeRecJump.JalrLinkRegisterExplicitSeparateFromJumpTarget
EeRecLoadStore.LwrLwlPairUnalignedWordLoad
EeRecMulDiv.DivSimple
EeRecCop0.Mtc0ThenMfc0Roundtrip
EeRecFpu.Mtc1MovesGprBitsToFpr
EeRecFpu.AddSInteger
EeRecFpuGuardBit.SubMasksOneGuardBit
EeRecMmi.MaddAccumulates32Bit
EeRecTraps.TeqTakenInDelaySlotSetsCauseBdAndBranchEpc
EeRecMultiblock.ThreeBlockChainExecutesInOrder
EeRecPinnedGpr.ScalarReadsOfPinnedRegs
EeRecTimeoutLoop.SelfLoopWithAluBodyIsNotSkipped
EeRecSmc.TriggerSmcHelperRewritesMemory
```

## Future Coverage Gaps

Still unproven by this first validation suite:

- deeper FPU full-mode edge cases
- FPU guard-bit matrix variants beyond one representative
- larger MMI coherence chains
- regalloc coupling microcases beyond the chosen pinned-GPR test
- IOP recompiler correctness
- VU recompiler correctness
- BIOS boot, ISO boot, and full VM integration
