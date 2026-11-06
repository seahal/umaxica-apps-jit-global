# OP Step-Up Support Case lock-order implementation evidence

Date: 2026-11-05

HEAD: `b30345216886c98af1f04cbd434f067f12decf01`.

The worktree was extensively uncommitted. The scoped Ruby implementation, tests and lock inventory
were changed during this work; unrelated existing changes were preserved.

## Checks performed

- `ruby -c` on the changed operation, model concern, controller, error and regression-test files:
  all returned `Syntax OK`.
- Scoped RuboCop on 10 changed Ruby files: passed with no offenses.
- Scoped `git diff --check`: passed.
- `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/operations/enforcement_case_apply_failure_test.rb test/operations/enforcement_case_apply_authority_test.rb test/operations/enforcement_case_apply_concurrency_test.rb test/operations/enforcement_case_end_missing_principal_test.rb`:
  **14 runs, 58 assertions, 0 failures, 0 errors, 0 skips**.
- `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/controllers/base/app/avatar_ownership_transfers_controller_test.rb test/integration/step_up_authentication_test.rb test/integration/base_rp_contact_registration_refusal_test.rb`:
  **52 runs, 265 assertions, 3 failures, 0 errors, 0 skips**. The remaining failures were one Q-1
  valid Security Mode downgrade returning 422 and two APP contact-registration expectations
  receiving the intentional 503 refusal.
- The combined Support Case, Q-1 and contact-registration command returned **86 runs, 349
  assertions, 22 failures, 1 error**. Support Case controller requests returned 401 before reaching
  the changed actions. The controller test file does not provide `X-Client-Assertion`, which
  `AvatarAuthorityApiEndpoint#authenticate_avatar_caller!` requires.

Only configured test databases were used. The operation regression test cleans only rows created by
its own examples. No production or development data was accessed.

## Limits

The passing operation tests do not establish independent-connection lock-winner ordering for every
changed Case writer. The Support Case controller behavior was not verified because its requests
failed during authentication. Q-1 and contact registration remain gated by their unapproved
request/persistence contracts. O-9 endpoints remain disconnected. The global O-10 interprocedural
lock graph remains incomplete.
