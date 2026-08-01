# recompiler_tests smoke bundle

This bundle is for a BIOS-free, first-step EE recompiler smoke test.

Contents:
- `bin/recompiler_tests`
- `lib/libSDL3.so.0`
- `lib/libSDL3.so.0.2.6`
- `lib/libplutovg.so.1`
- `lib/libplutosvg.so.0`
- `launch-jit-smoke.sh`
- `diagnostic.sh`
- `MANIFEST.txt`

The intended first command on target is:

```bash
./launch-jit-smoke.sh
```

Default test workload:

```bash
recompiler_tests --gtest_filter=EeRecHarnessValidation.TestOne_SetsRegisterToKnownPoison --gtest_color=no
```

This bundle does not include BIOS, ISO images, or any gameplay content.
