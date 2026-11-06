# Signup cleanup stale-binding lock-order verification

- Date: 2026-11-04
- Commit: `b30345216886c98af1f04cbd434f067f12decf01`
- Worktree: extensively uncommitted; results include only the scoped changes described here.
- Database scope: configured test databases only. No development or production database was
  accessed.

## Change

`SignUpArtifactCleanup` now detects when a Flow instance read with a blank principal is bound before
its OP Flow lock is acquired. It raises an internal error inside `ClientSignUpFlow#with_cycle_lock`,
allowing the Flow's `requires_new` savepoints to roll back and release the OP row lock before
reloading and retrying through the actor-first branch. The independent-connection regression runs
cleanup inside an outer OP transaction, holds the Client lock, and proves the Flow row is available
to `FOR UPDATE NOWAIT` while the worker waits for the Client lock. The lock-order inventory records
this tested path as repaired and remains explicitly incomplete.

## Verification

- `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/concurrency/sign_up_cleanup_principal_lock_test.rb test/concurrency/sign_up_secret_lock_order_test.rb test/services/sign_up_artifact_cleanup_test.rb test/services/sign_up_artifact_cleanup_atomicity_test.rb`
  — **21 runs, 103 assertions, 0 failures, 0 errors, 0 skips**.
- `bin/rubocop app/errors/sign_up_cleanup_stale_principal_binding_error.rb app/services/sign_up_artifact_cleanup.rb test/concurrency/sign_up_cleanup_principal_lock_test.rb`
  — passed, 3 files, no offenses.
- `bin/rails test test/security/invariants/lifecycle_direct_state_write_invariant_test.rb` — **2
  runs, 4 assertions, 0 failures, 0 errors, 0 skips**.
- `PARALLEL_WORKERS=1 bin/rails test test/integration/base_rp_contact_registration_refusal_test.rb`
  — **2 runs, 36 assertions, 0 failures, 0 errors, 0 skips**; current refusal/no-mutation behavior
  remains verified.
- `PARALLEL_WORKERS=1 bin/rails test test/controllers/base/app/avatar_ownership_transfers_controller_test.rb test/integration/step_up_authentication_test.rb`
  — **50 runs, 229 assertions, 3 failures, 0 errors**. The valid Q-1 downgrade still returns 422
  before step-up verification because the RP local session has no `current_session_token`; email
  registration completion and the sensitive-action test's expected 401 both receive the interim 503.
  These are existing owner-boundary gaps and were not changed here.
- `git diff --check` on the changed implementation, regression test and lock-order inventory —
  passed.

The first scoped RuboCop invocation reported one `Metrics/AbcSize` offense in
`SignUpArtifactCleanup#call`; extracting the lock snapshot and locked cleanup steps brought the
final scoped run to zero offenses. This evidence does not establish the complete O-10 lock graph or
commit-boundary contract.

During refinement, removing the early return for an already-completed synthetic Flow caused
`test_returns_completed_cycles_unchanged` to reach actor locking with a deliberately absent Client
and raise `ActiveRecord::RecordNotFound`. The completed-cleanup fast path was restored; the final
focused suite above then passed.
