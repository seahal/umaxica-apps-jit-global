# P3d runtime OTP retirement verification

Date: 2026-10-10

Repository HEAD: \`2a1644f73238839ed7ed513bd4681ea393a86682\`

The worktree was already dirty before this slice. Existing staged, unstaged and untracked changes
were preserved; no reset, clean, stash, commit, push or worktree operation was performed.

## Scope

This slice removed identifier-owned HOTP lifecycle methods and withdrawal writes from the six
Email/Telephone identifier models. The ceremony-owned proof paths remain authoritative. The legacy
physical columns remain as transitional structural data until a complete reader, fixture and
constraint inventory authorizes a forward schema retirement; no new random identifier secret or
legacy fallback was added.

## Red/Green evidence

- Red: \`test/models/otp_failure_retention_test.rb\` initially failed for all six models because
  \`store_otp\` was still exposed.
- Green: \`test/models/otp_failure_retention_test.rb\` — 32 runs, 408 assertions, 0 failures,
  0 errors, 0 skips.
- Green: \`test/operations/withdrawal_personal_data_anonymizer_test.rb\` — 10 runs, 93 assertions,
  0 failures, 0 errors, 0 skips.
- Green: the affected neighboring selection (OTP policy, six identifier models, Email/Telephone
  concerns, withdrawal and sign-in security) — 221 runs, 739 assertions, 0 failures, 0 errors,
  0 skips.
- Green after the final assertion wording/strengthening — \`test/controllers/auth/app/in/emails_controller_security_test.rb\`
  — 14 runs, 48 assertions, 0 failures, 0 errors, 0 skips.

## Full gates

The complete Rails gate was run with \`/tmp/run-p9-full.sh\` over all 42 isolated disposable
PostgreSQL batches, using \`PARALLEL_WORKERS=1\` as required by the repository's isolated-database
safety guard:

- 15,317 runs
- 128,571 assertions
- 3 failures
- 0 errors
- 0 skips

All application batches passed. The three failures were confined to
\`test/tooling/database_reconstruction_authority_test.rb\`, which checks tracked
\`db/*_structure.sql\` dumps that are empty or header-only in the existing dirty worktree. They are
schema-dump/worktree evidence failures, not failures in the P3d runtime slice.

Vitest was run with \`/tmp/run-p9-vitest.sh\`:

- 99 test files passed
- 1,140 tests passed
- exit status 0

\`git diff --check\` passed. Focused RuboCop over the changed production and test files passed with
15 files inspected and no offenses.

A later attempt to repeat the full Rails gate after a test-only assertion wording change stopped
before completion at batch 023 and is not counted as a passing full gate. The changed test itself
was rerun successfully as recorded above.

## Remaining verification

This evidence does not certify complete OTP ownership migration or schema retirement. A later
slice must inventory all remaining readers, fixtures and constraints before dropping the legacy
columns, then repeat the required full gates.
