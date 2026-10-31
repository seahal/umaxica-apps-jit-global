# OP stop and RP delivery retry

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting the checked implementation and tests.
- Added a local XDB-22 test that returns HTTP 503 at the outbound RP boundary, observes the OP root and grant remain revoked and the participant remain pending, then makes the participant due and observes an acknowledged retry without restoring OP authority. The test does not contact an external RP.
- The new focused test passed: 1 run, 8 assertions. `PARALLEL_WORKERS=1 bin/rails test test/operations/op_authority_stop_committer_test.rb test/jobs/op_outbox_dispatch_job_test.rb` passed: 22 runs, 193 assertions, no failures or errors.
- `bundle exec rubocop test/jobs/op_outbox_dispatch_job_test.rb --format simple` and `git diff --check -- test/jobs/op_outbox_dispatch_job_test.rb` passed.
- This does not exercise an actual network outage, an independently committed queue failure, or the deployed recurring scheduler.
