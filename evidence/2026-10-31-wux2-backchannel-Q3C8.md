# Historical A15-7 related back-channel tests

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting this result.
- `PARALLEL_WORKERS=1 bin/rails test test/adapters/oidc_backchannel_logout_client_test.rb test/jobs/op_outbox_dispatch_job_test.rb` passed: 13 runs, 111 assertions, 0 failures, 0 errors, 0 skips. The outbound adapter port suite was also included in the passing run documented in `evidence/2026-10-31-wua14-bl19-secondary-W4P8.md`.
- These tests are partial inputs to the historical A15-7 classification; coverage of every address class and actual external back-channel delivery was not established by this run.
