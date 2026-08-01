# recompiler_tests smoke bundle

This bundle is for a BIOS-free runtime smoke test of `recompiler_tests` on the
R36S Arch-R target.

Contents:
- `bin/recompiler_tests`
- `lib/libSDL3.so`, `lib/libSDL3.so.0`, `lib/libSDL3.so.0.2.6`
- `lib/libplutovg.so.1`
- `lib/libplutosvg.so.0`
- `launch-jit-smoke.sh`
- `diagnostic.sh`
- `MANIFEST.txt`
- `host-isa-scan.txt`

Safe first command on target:

```bash
./launch-jit-smoke.sh
```

The launcher runs:

```bash
recompiler_tests --gtest_filter=EeRecHarnessValidation.TestOne_SetsRegisterToKnownPoison --gtest_color=no
```

It captures stdout, stderr, exit code, and a small preflight log under
`logs/<timestamp>/`.

The diagnostic script is separate and does not start the test binary:

```bash
./diagnostic.sh
```
