# Org control plane release-candidate baseline

This record freezes the verified state. Nothing was committed: the work is uncommitted on top of
commit `e423890e7357e1fa7975eac45aeacdb416b3bce9`, mixed with the user's own pre-existing staged and
unstaged changes, so there is no single commit SHA for the candidate. It is identified instead by:

- base commit: `e423890e7357e1fa7975eac45aeacdb416b3bce9`
- `git diff HEAD --binary | sha256sum`: `1b5f2876699b174868333303b3acb2e7fb5d0cb506b35ccf1dba1ccd1bd95725`
- untracked files (61, sorted, concatenated) `sha256sum`:
  `87b4c8fe8e313c5a3a853599a183c4f70a98db6b998919013496104c232fc8d6`

A commit SHA can be recorded once the user decides how to commit this work separately from their own
changes.

## Verified at this state

Results from `evidence/2026-09-26-org-control-plane-convergence-R8M3.md`, re-read, not re-run:

- `bundle exec rails test`: 11812 runs, 75485 assertions, 0 failures, 0 errors, 2 skips (both in
  files this work did not touch).
- Vitest: 87 files, 1054 tests, all passed.
- Real Step-Up ceremony end to end, capability → Step-Up → mutation → audit, realm separation,
  Enforcement partial-failure behavior, explicit audit actor, continuity-guard concurrency,
  browser-condition CSRF, Membership read-only, fresh-chain migration with up/down/up.
- Frontend typecheck exits non-zero on one pre-existing error in
  `src/pages/base/org/avatars/show.tsx`; the changed admin files have no type errors.
