# Secret audit delivery past failures

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes, including the implementation and tests.
- A conflicting Chronicle UUID previously prevented a later Secret audit event from being delivered. The job now reports and retains failed rows, advances through bounded ID pages, and raises after attempting later rows. A run still acknowledges at most its configured batch size.
- `PARALLEL_WORKERS=1 bin/rails test test/jobs/client_secret_audit_delivery_job_test.rb` passed: 10 runs, 100 assertions, no failures or errors. Its batch-size-1 case checks delivery after a conflict, and the existing lifecycle test checks the one-success limit and retention behavior.
- The lifecycle test now grants fresh target-bound Step-Up before Secret revocation, consistent with the changed management contract.
