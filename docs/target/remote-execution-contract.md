# Remote Execution Contract

The approved SSH helper is `tools/connect-r36s-wifi.sh`.

## Confirmed Behavior

- The helper runs `sshpass` locally and then execs `ssh`.
- The target user is `root`.
- The helper preserves stdin.
- The helper does not create files on the target.
- The helper accepts a single remote command string as one argument.
- The helper also works with `stdin -> sh -s` for multiline scripts.

## Clean Probes

### Probe A

```bash
tools/connect-r36s-wifi.sh 'printf "%s\n" PROBE_A'
```

Result:

```text
PROBE_A
```

### Probe B

```bash
tools/connect-r36s-wifi.sh 'printf "%s\n" "alpha beta" "literal:\$HOME"'
```

Result:

```text
alpha beta
literal:$HOME
```

### Probe C

```bash
cat <<'REMOTE' | tools/connect-r36s-wifi.sh sh -s
set -eu
printf '%s\n' PROBE_C
for value in one two three; do
    printf '<%s>\n' "$value"
done
REMOTE
```

Result:

```text
PROBE_C
<one>
<two>
<three>
```

### Probe D

Direct split argv is unsafe for space-bearing arguments:

```bash
cat <<'REMOTE' | tools/connect-r36s-wifi.sh sh -s -- arg1 'arg two'
set -eu
printf '<%s>\n' "$1"
printf '<%s>\n' "$2"
REMOTE
```

Result:

```text
<arg1>
<arg>
```

Fallback with a single quoted remote command string preserves the space:

```bash
cat <<'REMOTE' | tools/connect-r36s-wifi.sh 'sh -s -- arg1 "arg two"'
set -eu
printf '<%s>\n' "$1"
printf '<%s>\n' "$2"
REMOTE
```

Result:

```text
<arg1>
<arg two>
```

## Safe Forms

- Preferred multiline form:

```bash
cat <<'REMOTE' | tools/connect-r36s-wifi.sh sh -s
set -eu
printf '%s\n' HELLO
REMOTE
```

- Single remote command string for one-liners:

```bash
tools/connect-r36s-wifi.sh 'printf "%s\n" HELLO'
```

## Unsafe Forms

- `tools/connect-r36s-wifi.sh bash -lc '...'`
- `tools/connect-r36s-wifi.sh sh -c '...'`
- Split argv with embedded spaces, for example:

```bash
tools/connect-r36s-wifi.sh sh -s -- arg1 'arg two'
```

## Notes

- The contract above is read-only.
- No files were created on the target during the probes.
