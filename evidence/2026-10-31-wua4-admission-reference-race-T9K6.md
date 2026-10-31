# Base Step-Up admission reference race

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree had extensive uncommitted changes, including the code tested here.
- In a nontransactional test with two connections, one holds the first parent while admission waits; the session reference is synthetically changed to another parent before the first lock is released. Admission refuses with `session_binding_mismatch`; the replacement reference and both pending parent states remain unchanged. Synthetic records were removed.
- The first two test attempts timed out while observing the lock: the test query reused a cached wait observation. The polling was changed to uncached `pg_blocking_pids`, and the related existing Email lock race received the same polling correction.
- `PARALLEL_WORKERS=1 bin/rails test test/concurrency/base_step_up_admission_reference_race_test.rb test/operations/base_step_up_admission_issuer_test.rb test/concurrency/step_up_email_lock_order_test.rb` passed: 18 runs, 275 assertions, 0 failures, 0 errors, 0 skips.
- The competing reference update was synthetic; the test does not establish a production writer that performs it or prove the entire lock inventory. The full suite was not run.
