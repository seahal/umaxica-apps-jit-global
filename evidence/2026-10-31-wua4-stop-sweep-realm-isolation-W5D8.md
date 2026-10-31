# Identity-stop recovery across realm database failure

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Substantial uncommitted worktree changes affected the tested implementation.
- A focused test created pending APP and ORG stops and injected an APP OP receipt-read connection failure. Before the change the exception aborted the job before ORG was processed: 1 run, 0 assertions, 1 error.
- The sweep now reports an Active Record error at the affected realm boundary and proceeds to the next realm. The test observes APP still pending and ORG applied, then removes the injected failure and verifies that a later sweep applies APP and revokes its old root.
- `PARALLEL_WORKERS=1 bin/rails test test/jobs/op_identity_event_sweep_job_test.rb test/operations/op_identity_event_invalidator_test.rb test/services/administrative_access_lock_test.rb test/services/oidc_access_token_authenticator_test.rb`: 34 runs, 183 assertions, no failures, errors or skips. Scoped RuboCop passed after formatting.
- The connection failure was injected; actual outage and scheduler behavior, failures in other locations or classes, and the full suite were not verified.
