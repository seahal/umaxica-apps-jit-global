# WU-7 com reset transaction

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; prior and current uncommitted worktree
  changes were present during verification.
- A confirmed com reset locks and revalidates the current row, retires it and creates/signs a
  default replacement in the same setting transaction. Cookies are queued after the transaction;
  a stale JWT cannot retire its referenced row. The legacy retention deadline is extended by the
  30-day grace period. State inventory and the com status diagram describe the current legacy axis.
- `bin/rails test test/integration/anonymous_com_preference_write_journey_test.rb test/controllers/concerns/preference_write_boundary_test.rb`:
  43 runs, 264 assertions, 0 failures, 0 errors, 0 skips. Tests include missing confirmation,
  current and stale tokens, and injected signing failure. An earlier run failed because validating
  a new unpersisted model also checked unrelated attributes; confirmation is now checked directly.
- `bin/rails test test/security/invariants/lifecycle_direct_state_write_invariant_test.rb`:
  2 runs, 4 assertions, 0 failures, 0 errors, 0 skips. RuboCop on the four modified Ruby files passed.
- This is a transition using the existing NOTHING/DELETED representation, not the planned new
  status schema. Concurrency, commit failure, issuance snapshot and cross-database audit atomicity
  remain unverified.
