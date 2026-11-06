# WU-A2 sign-up Back and Secret cleanup recheck

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`; the worktree had uncommitted changes.
- Ran
  `bin/rails test test/integration/sign_up_phase_regression_app_test.rb test/jobs/client_secret_lifecycle_job_test.rb:52`
  with `.env.container.devcontainer` loaded into the process.
- Result: 13 runs, 153 assertions, 0 failures, 0 errors, 0 skips. The selected sign-up tests
  exercise reloading the current OTP step, refusal of stale/missing phase bindings, phase mutation
  refusal and preservation of canceled Secret allocations.
- This does not verify a completed registration protected from a later OP Cancel or every
  §10.5/§10.6 race. The completion-receipt contract in §12.4 is still awaiting approval. The full
  suite was not run.
