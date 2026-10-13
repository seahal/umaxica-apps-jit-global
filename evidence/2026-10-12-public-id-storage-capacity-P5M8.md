# Public ID generation and storage capacity

## Scope

This slice separates the standard issuer length from the compatibility storage capacity in the
shared `PublicId` concern. It was performed against the local dirty worktree at
`7576ff7cbc6787f7f80f1f42bfa538914ace6de1`; unrelated existing changes were preserved.

## Change

`PublicId.generate` remains NanoID-21. The concern now validates a maximum of 25 characters for an
explicit existing value, while values longer than 25 are rejected before persistence. Database
column bounds remain authoritative for columns that are narrower than 25; no schema migration,
truncation or case conversion was added.

## Verification

- Red: the new 25-character compatibility case failed because the concern enforced a 21-character
  maximum.
- Focused public-ID/capacity collection, including the APP, COM and ORG preference regressions:
  `122 runs, 337 assertions, 0 failures, 0 errors, 0 skips`.
- Targeted RuboCop for the five changed Ruby files:
  `5 files inspected, no offenses detected`.
- Ruby syntax checks for the changed Ruby files: all `Syntax OK`.
- `git diff --check`: passed.
- `scripts/check-repository-knowledge`: passed (`Knowledge structure passed: 8 Skills/adapters,
  67 documents, 0 evidence records.`).
- Gate 2 Rails full suite, run after the final test correction, with four workers and the existing
  run-owned twenty-database manifest:
  `15203 runs, 128507 assertions, 0 failures, 0 errors, 0 skips` in `340.175416s`.
- Gate 2 Vitest full suite: `99 files passed, 1140 tests passed` in `12.95s`.

This is implementation evidence for the current dirty worktree, not independent acceptance. The
full gates were run against the dirty worktree at HEAD
`7576ff7cbc6787f7f80f1f42bfa538914ace6de1`; unrelated existing changes were preserved. The first
post-change Rails run exposed three stale preference test expectations for a 22-character value;
the tests were corrected to exercise the documented 26-character rejection, and the complete gate
was rerun successfully. No application acceptance investigation, CI, Podman, production, shared
destructive operation or remote synchronization was used.
