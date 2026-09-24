# CF-007 existing Side JP host source

- Date: 2026-09-23
- Repository HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Worktree: contains pre-existing uncommitted changes; no commit, push, or external write was performed.

## Change

The regional RP matrix now derives Side JP URI bindings from the existing canonical
`HostFamilyValues` Side host (`side_service`, `side_corporate`, or `side_staff`). It does not create
new host values. Side US still requires an explicit regional source and continues to fail closed when
that source is absent.

## Verification

Passed:

- Ruby syntax checks for the changed value and test files.
- Targeted RuboCop for the changed value and test files: no offenses.
- `git diff --check`.

Not run / blocked:

- Rails tests were not run because the required local preflight still cannot resolve `primary` or
  `valkey-kvs` from this process. The exact failure is recorded in
  `evidence/2026-09-23-cf007-private-key-jwt-boundary-Q1R2.md`.

The Side US host and all regional audience values remain intentionally undefined. No registry entry,
credential, arbitrary host, or audience derived from a client ID was added.
