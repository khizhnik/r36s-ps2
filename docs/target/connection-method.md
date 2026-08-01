# Connection Method

The approved SSH access path for the R36S is the local helper script:

```bash
tools/connect-r36s-wifi.sh
```

Observed behavior:

- Uses `sshpass` and an embedded password value.
- Connects as the `root` user by default.
- Uses a private LAN host value from the script or `R36S_WIFI_HOST` if set.
- Accepts new host keys with `StrictHostKeyChecking=accept-new`.
- Passes additional arguments through to `ssh`, so it supports remote commands.
- Does not itself write to the target filesystem.

Safety notes:

- The script is read-only from the target system's perspective.
- The host, password, and any host-key state are treated as local connection
  details and are not repeated here.
- The script is the only approved SSH path for this investigation stage.
