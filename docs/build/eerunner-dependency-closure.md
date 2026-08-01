# pcsx2-eerunner Dependency Closure

Audit date: 2026-07-27

Status: not build-verified on this host.

## Why this file exists

This is the place where the actual build graph for `pcsx2-eerunner` will be recorded once CMake configure is possible.

## Current source-level expectation

From source inspection only:

- `pcsx2-eerunner` links `PCSX2_FLAGS` and `PCSX2`
- it does not link Qt directly
- it does not link SDL3 directly
- it can request the Null renderer
- it still pulls in the shared core, so the core renderer sources may still compile unless future build flags exclude them

## Not yet known

- whether Vulkan sources compile in the same graph even when runtime Null is requested
- whether OpenGL sources compile in the same graph even when runtime Null is requested
- whether any renderer headers remain mandatory in the minimal target
- whether a true Null-only dependency closure can be expressed with CMake options alone

## Blocker

The host currently lacks `cmake`, so no build graph was generated.
