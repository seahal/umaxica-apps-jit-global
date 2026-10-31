# Identity-stop retry enqueue refusal

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained substantial uncommitted changes affecting the implementation and tests.
- A focused test injected an unavailable OP and a retry enqueue returning `false`. Before the change, the expected enqueue error was not raised: 1 run, 1 assertion, 1 failure.
- `OpIdentityEventInvalidator.deliver` now raises `ActiveJob::EnqueueError` when the retry job is refused instead of returning `:enqueued`. In the test the Zenith event remained, no OP receipt existed at refusal, and the existing sweep subsequently applied it and revoked the old root.
- `PARALLEL_WORKERS=1 bin/rails test test/operations/op_identity_event_invalidator_test.rb test/jobs/op_identity_event_sweep_job_test.rb test/services/administrative_access_lock_test.rb test/services/oidc_access_token_authenticator_test.rb`: 33 runs, 172 assertions, no failures, errors or skips. Scoped RuboCop passed.
- The queue refusal was injected and the sweep was invoked synchronously. An actual queue outage, scheduler behavior, user-facing HTTP mapping and the full suite were not verified.
