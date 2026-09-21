# Step-Up atomic consumption evidence

- Date: 2026-09-20
- Scope: token-bound Step-Up completion across app, com, and org session models
- Repository state: existing working-tree changes were preserved; no production/external service or
  GitHub write was performed.

## Finding and fix

The pre-change flow loaded the pending Step-Up row before entering the writing transaction, issued
the signed result, and then destroyed the row. Two concurrent requests could therefore both pass
the in-memory/session checks before either destroy committed.

The three surface-local models now share a public `consume_pending!` operation. It locks the row in
PostgreSQL, rechecks pending/expiry state, executes result issuance inside the transaction, and
destroys the row before commit. A second worker observes no pending row and receives no result.

## TDD and verification

- RED: `PARALLEL_WORKERS=1 bin/rails test test/models/step_up_session_consumption_concurrency_test.rb`
  failed because `ClientStepUpSession.consume_pending!` did not exist.
- GREEN focused run:
  `PARALLEL_WORKERS=1 bin/rails test test/models/step_up_session_consumption_concurrency_test.rb test/controllers/auth/app/verification/totps_controller_test.rb test/controllers/auth/app/verification/emails_controller_test.rb`
  - 32 runs, 285 assertions, 0 failures, 0 errors, 0 skips.
- The concurrency test used independent PostgreSQL connections and committed rows; exactly one
  consumer returned the session result and the row was removed.
- `bundle exec rubocop app/models/concerns/step_up_session_consumable.rb app/models/client_step_up_session.rb app/models/visitor_step_up_session.rb app/models/operator_step_up_session.rb app/controllers/concerns/sign_verification_step_up_lifecycle.rb test/models/step_up_session_consumption_concurrency_test.rb`
  - 6 files inspected, no offenses.
- `bin/rails test`
  - 11,406 runs, 72,993 assertions, 0 failures, 0 errors, 5 skips.

## Limits

The operation serializes the Step-Up ticket row. It does not make separate database connections or
signed result transport an all-database transaction; existing ceremony result consumption remains
the authoritative downstream replay boundary.
