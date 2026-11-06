# Step-Up lock-order and post-switch regression rerun

- Commit: `b30345216886c98af1f04cbd434f067f12decf01`
- Worktree: extensively uncommitted; results cover the checked-out working tree.
- Date: 2026-11-04.

## Checks performed

`RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/concurrency/sign_up_cleanup_principal_lock_test.rb test/concurrency/sign_up_secret_lock_order_test.rb`
passed **11 runs, 51 assertions, 0 failures, 0 errors and 0 skips**. These public-boundary tests
cover selected Secret and Email actor-first lock paths and bound-flow cleanup. They do not establish
the complete reverse-lock graph, the stale blank-flow cleanup interleaving, or O-10 commit ordering.

`PARALLEL_WORKERS=1 bin/rails test test/controllers/base/app/avatar_ownership_transfers_controller_test.rb test/integration/step_up_authentication_test.rb`
completed with **50 runs, 229 assertions, 3 failures, 0 errors and 0 skips**. The remaining failures
are the valid Q-1 mode transition refusing with 422 because the RP-local request has no
`current_session_token`, plus two O-11 contact-registration requests receiving the interim 503.
These are recorded failures, not waived expectations.

## Scope and limits

The Rails runner used the configured test database catalog. No development or production database
operation was requested or performed. No application implementation or schema was changed during
these checks. O-9 remains disconnected pending design review. Q-1, O-11 and the complete O-10 lock
inventory remain incomplete.
