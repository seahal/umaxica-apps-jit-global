# Passkey Flow deadline clock test investigation

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree had uncommitted changes affecting the inspected test and implementation.
- The running full suite reported 201 instead of 409 in both at-deadline and after-deadline Flow-lock wait tests. The suite was still running at this observation; these failure blocks are not a completed comparison.
- Source inspection: the registration writer reads `ClientSignUpFlow.database_now` after obtaining the Flow lock. The test stubs `OpBaseAppRecord.database_now`. Other tests directly stub `ClientSignUpFlow.database_now`.
- In the installed Minitest `stub` implementation, restoring an inherited singleton method creates an alias on the child. An isolated `bundle exec ruby -rminitest/mock` probe stubbed an inherited child clock and then its parent; the parent returned the new stub while the child returned the original method. This establishes an order-dependent mechanism, not that it caused the recorded full-suite failures.
- The actual Flow tests and any change have not yet been rerun; the full suite owns the shared test database.
- After the full suite ended, `PARALLEL_WORKERS=1 bin/rails test test/jobs/sign_up_expiry_job_test.rb test/concurrency/sign_up_passkey_termination_http_test.rb:281 --seed 54824` reproduced both deadline failures: 10 runs, 109 assertions, 2 failures.
- Changed the deadline test to stub the Flow class's clock directly, which is the clock read by the registration writer. The same command passed afterward: 10 runs, 141 assertions, 0 failures, 0 errors, 0 skips. This establishes the test-order clock issue in that local sequence; it does not independently prove all deadline races or deployed behavior.
