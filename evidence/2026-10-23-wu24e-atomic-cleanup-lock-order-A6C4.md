# WU-24e atomic principal cleanup and Flow-first lock order

- Date: 2026-10-23.
- Commit: `6e4d70d0b0799a4ef9bd9fc4cea2c21d4b3eca72`.
- Worktree: pre-existing cycle and unrelated changes plus uncommitted WU-24e changes. This
  record precedes the subsequent WU-24b implementation and does not certify the whole cycle.
- Contract: `two.md` 6.1 / 6.2, D-131 and D-143; cases A24-7, A35-2 and A35-3.

## Changes and observations

- Cleanup requires a terminal main Flow, holds its lock, then re-reads the principal under the
  Zenith writer lock. Contact, Passkey, their audit outbox and actor retention share one principal
  savepoint/transaction. The actor is updated last. Real actor-retention failure rolls all
  preceding writes back; a retry sees the pending data and completes it.
- All five APP Secret sign-up entry points acquire the Flow before the principal. Telephone
  Passkey saving takes its Flow lock before its actor lock and reservation issuer.
- The old worker test used a fake row without a main lifecycle. It was replaced with a real
  CANCELLED Flow and observable tenth-attempt completion; no assertion was weakened to hide a bug.
- Baseline: the full intake run had 146 failures and 24 errors; none of the affected cleanup or
  reservation test identities was in that list. See `authentication-cycle-baseline-F6B2`.

## Executed checks

- Initial Red: `bin/rails test test/services/sign_up_artifact_cleanup_atomicity_test.rb
  test/concurrency/sign_up_secret_lock_order_test.rb`: 7 runs, 18 assertions, 5 failures.
  Four reproduced APP/COM partial deletion and nonterminal cleanup. The fifth was an observation
  defect in the new lock test: PostgreSQL's cached statistics snapshot hid its wait.
- Corrected lock observation, production code unchanged: `bin/rails test
  test/concurrency/sign_up_secret_lock_order_test.rb`: 1 run, 2 assertions, 1 failure;
  the worker was observed waiting on the Flow while incorrectly holding the principal lock.
- First Green: atomicity, legacy cleanup, lock order and reservation issuer files:
  19 runs, 324 assertions, no failures/errors/skips.
- Regression: those four files plus `test/services/sign_up_termination_idempotence_test.rb`,
  `test/services/sign_up_expiry_race_test.rb`, `test/services/sign_up/cancellation_test.rb`,
  `test/jobs/sign_up_expiry_job_test.rb`,
  `test/controllers/auth/sign_up_checkpoint_cancellation_test.rb`,
  `test/controllers/auth/app/up/telephones_controller_test.rb`:
  93 runs, 1328 assertions, no failures/errors/skips.
- `bin/rails test test/concurrency/sign_up_cleanup_principal_lock_test.rb
  test/controllers/auth/app/up/checkpoint_passkeys_controller_test.rb
  test/controllers/auth/com/sign/up/check/telephone/checkpoint_flow_test.rb`:
  20 runs, 413 assertions, no failures/errors/skips. APP/COM workers actually wait on the principal
  lock; registration committed during that wait survives cleanup. These race cases were added
  after the implementation; no Red chronology is claimed for them.
- Lifecycle direct-write, CSRF strategy, standard CSRF, identity-authority and WebAuthn invariant
  guards: 25 runs, 137 assertions, no failures/errors/skips.
- RuboCop on the 3 production and 4 changed/new cleanup test files: 7 files, no offenses.
- Scoped `git diff --check`: passed.

## Remaining acceptance

- A24-7 and A35-3 have direct passing coverage. A35-2 has a real retirement/Flow contention test
  and HTTP regression coverage, but not the separate request race of Passkey saving against
  termination; it remains partially verified.
- Translation namespace guard first attempted concurrently with another test process was refused
  by the test database lock before tests ran. It then passed in the serialized WU-24b combined
  run (1602 runs, 47 pre-existing failures and 1 pre-existing error; none in the selected guards
  or cleanup/lock tests). See `wu24b-effective-entry-intent-I4B6`.
- No post-change full-suite or production check is claimed here. The cycle remains implementing.
