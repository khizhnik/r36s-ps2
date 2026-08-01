# Artifact Run Audit

Only the clean run `artifacts/target-environment/20260727T180305Z/` is trusted
as a source of baseline facts.

| Run | Clean | Shell errors | Unexpected root-home output | Usable files | Status |
| --- | ----: | -----------: | --------------------------: | ------------ | ------ |
| `20260727T173132Z` | No | Yes | No evidence in the stored files | Some, but not trusted | `SUPERSEDED` |
| `20260727T173255Z` | No | Yes | No evidence in the stored files | Some, but not trusted | `SUPERSEDED` |
| `20260727T173521Z` | No | Yes | No evidence in the stored files | Some, but not trusted | `SUPERSEDED` |
| `20260727T180305Z` | Yes | No | No | Yes | `VALID` |

## Notes

- The earlier runs were produced while remote quoting was still broken.
- They remain on disk for inspection, but they are superseded by the clean
  run and should not be used as evidence for target ABI decisions.
- The clean run has a `COMPLETE` marker and per-group stdout/stderr files.
