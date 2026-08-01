# pcsx2-eerunner Smoke Bundle

This bundle is a minimal Arch-R runtime payload for the first safe launch
check of `pcsx2-eerunner` on the R36S.

Contents:

- `bin/pcsx2-eerunner`
- `lib/` with the runtime libraries used by the binary, copied from the Arch-R
  sysroot so the first smoke test can run without relying on the device's
  package set:
  - `libSDL3.so.0`
  - `libplutovg.so.1`
  - `libplutosvg.so.0`
  - `libudev.so.1`
  - `libdbus-1.so.3`
  - `libcurl.so.4`
  - `libwebp.so.7`
  - `libfreetype.so.6`
  - `libjpeg.so.8`
  - `libpng16.so.16`
  - `libz.so.1`
  - `libzstd.so.1`
  - `libpcap.so.1`
  - `libstdc++.so.6`
  - `libm.so.6`
  - `libgcc_s.so.1`
  - `libc.so.6`
- `launch.sh`
- `diagnostic.sh`

The first launch target is `--help`, which does not boot a game, require BIOS,
or create a savestate.

## Safe first launch

```bash
./launch.sh --help
```

## Diagnostic pass

```bash
./diagnostic.sh
```

## R36S copy sketch

When you are ready to move this bundle to the console, copy it to:

```text
/storage/ports/pcsx2-eerunner-smoke
```

The exact transfer command sketch should use the approved
`tools/connect-r36s-wifi.sh` connection method and should not alter system
libraries:

```bash
tar -C deploy/r36s-pcsx2-eerunner-smoke -cf - . | \
  tools/connect-r36s-wifi.sh 'mkdir -p /storage/ports/pcsx2-eerunner-smoke && tar -C /storage/ports/pcsx2-eerunner-smoke -xf -'

tools/connect-r36s-wifi.sh 'chmod +x /storage/ports/pcsx2-eerunner-smoke/launch.sh /storage/ports/pcsx2-eerunner-smoke/diagnostic.sh'

tools/connect-r36s-wifi.sh '/storage/ports/pcsx2-eerunner-smoke/launch.sh --help'

tools/connect-r36s-wifi.sh 'tar -C /storage/ports/pcsx2-eerunner-smoke -cf - logs' > pcsx2-eerunner-smoke-logs.tar
```

After running the smoke test on R36S, retrieve logs the same way with
`tools/connect-r36s-wifi.sh` and `tar`, without touching `/usr` or any system
library directories.
