# Sysroot Recommendation

## Source fact

Arch-R already provides a build-time cross sysroot and toolchain under the build directory.

## Recommended strategy

1. Use the Arch-R build tree as the primary source for headers, pkg-config files, and CMake metadata.
2. Use the live R36S only as an ABI/runtime reference for loader, SONAME, device, and vendor graphics behavior.
3. Reproduce runtime libraries from the Arch-R source tree and matching package definitions.
4. Treat `libmali` and GPU switching as runtime-sensitive artifacts that may need both build output and live validation.

## What to take from where

- Best headers source: Arch-R build sysroot
- Best runtime libraries source: Arch-R package outputs
- Best Mali vendor files source: Arch-R package outputs, with live target only as a validation reference
- Best pkg-config/CMake metadata source: Arch-R build sysroot

## What not to do

- do not build a sysroot from live R36S alone
- do not assume standard Arch Linux ARM package archives are interchangeable with Arch-R
- do not copy runtime overlays as if they were generic SDK content

## Next practical step

A downstream ARMSX2 toolchain file should point at an Arch-R-generated sysroot once the actual package export phase is identified and validated.

