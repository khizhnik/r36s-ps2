# Test Inputs

Audit date: 2026-07-27

This file keeps the test ladder legally clean.

## Existing test surfaces in upstream

Confirmed sources:

- `tests/ctest/core/recompilers/`
- `tests/ctest/core/recompilers/harness/`
- `pcsx2-vurunner/Main.cpp`
- `pcsx2-eerunner/Main.cpp`
- `pcsx2-gsrunner/Main.cpp`

## What does not require BIOS

- `pcsx2-vurunner` with `.vucap` fixtures
- synthetic runner modes in `pcsx2-eerunner`
- compile-only checks on the host
- codegen dump / divergence modes that use saved state or synthetic captures

## What does require BIOS or personal content

- real BIOS boot in the full VM
- disc-based full boot
- real game replay
- most meaningful `pcsx2-sdl` boot testing

## Synthetic test classes

### EE synthetic tests

Available through `pcsx2-eerunner` modes such as:

- `--selfcheck`
- `--localize`
- `--repro`
- `--stepdiff`
- `--contmem`
- `--speedhackdiff`

These modes are intended to work from state-based or generated data rather than protected game content.

### VU synthetic tests

Available through `pcsx2-vurunner`:

- `.vucap` captures
- diff mode
- benchmark mode
- disassembly / dump modes

The runner expects capture data produced by another PCSX2/ARMSX2 runtime.

### GS dump tests

Available through:

- GS dump replay machinery
- `pcsx2-gsrunner`
- `pcsx2-eerunner --gsdump` / related live-run capture paths

## Fixtures in tree

The code tree already contains the harness and runner code.

What it does not contain:

- BIOS blobs
- ROMs
- ISO/CHD game images
- memory cards
- firmware dumps

## Can we create a minimal payload ourselves?

Yes, but not in this stage.

Possible legal ladders:

- host compile probes
- ARM64 unit tests
- EE synthetic tests
- VU synthetic tests
- runner fixtures
- open-source PS2 homebrew
- personal BIOS
- personal game dump

The repo should stay on the left side of that ladder until the owner explicitly decides otherwise.

## Can full-system runtime load ELF without BIOS?

The code has ELF override and fast boot support, but BIOS-free full-system boot is not the same thing as “no BIOS required”.

In the current upstream, BIOS is still loaded for ordinary VM boot paths.

## Personal BIOS boundary

The personal BIOS becomes necessary for:

- authentic BIOS boot
- any claim about true console startup behavior
- final validation of BIOS-dependent code paths

It should not be stored in the repository.
