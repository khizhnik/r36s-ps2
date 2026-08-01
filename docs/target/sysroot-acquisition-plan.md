# Sysroot Acquisition Plan

This repository does not yet perform a full sysroot sync from the target.

## Recommended Direction

1. Capture a small, read-only runtime baseline from the live R36S.
2. Compare package versions, SONAMEs, and loader paths.
3. Build a reproducible sysroot from package archives or a known rootfs image.
4. Use the live console only as an ABI reference, not as the build environment.

## Candidate Methods

### Live read-only rsync

- High fidelity to the running system
- Higher risk of collecting unwanted user data
- May miss development headers, and on this target it does miss them

### Image extraction

- Reproducible and less disruptive
- Depends on access to the correct image
- May not match the live console exactly

### Package reconstruction

- Best path for headers and build metadata
- Requires package version alignment
- May need extra normalization for absolute symlinks
- Best place to recover `gcc`/`glibc` headers and pkg-config metadata
- Needed because the live console lacks `/usr/include` and `pkg-config`

## Current Status

- The plan is documented only.
- No full sysroot sync has been executed.
- Because `/usr/include` is missing on the live target, package reconstruction or
  image extraction is the safest path for a buildable sysroot.
- Live-target-only rsync is not sufficient for a buildable sysroot.
