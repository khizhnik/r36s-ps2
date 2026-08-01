# Arch-R CI Build Path

Audit date: 2026-07-28

## Repository state

The repository does not contain a `.github/workflows/` directory.

What is present under `.github/`:

- `ISSUE_TEMPLATE/bug-report.md`
- `ISSUE_TEMPLATE/config.yml`
- `release-body.md`

## De facto build path

The build path is described by:

- `Makefile`
- `Dockerfile`
- `scripts/build_distro`
- `scripts/build`

The top-level `Makefile` runs:

```text
PROJECT=ArchR DEVICE=RK3326 ARCH=arm ./scripts/build_distro
PROJECT=ArchR DEVICE=RK3326 ARCH=aarch64 ./scripts/build_distro
```

for the RK3326 world target.

## Dockerfile role

The `Dockerfile` is the canonical host-environment recipe for repo-local builds:

- starts from `archlinux:latest`
- upgrades base packages
- installs build dependencies such as `base-devel`, `git`, `go`, `python`, `rsync`, `dtc`, `xmlstarlet`, `sudo`, and more
- notes that the project builds its own GCC 15.1-based cross-toolchain

## Practical conclusion

For this repo, the source tree itself is the CI reference. There is no checked-in GitHub Actions workflow to inspect or replay.
