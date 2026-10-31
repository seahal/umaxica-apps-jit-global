# Social audit delivery past failures

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes, including the implementation and tests.
- A conflicting Chronicle UUID previously prevented a later Social audit from being acknowledged. The job now leaves failures pending, reports each one, scans bounded pages through the captured upper ID, and raises after the scan for retry.
- `PARALLEL_WORKERS=1 bin/rails test test/jobs/social_audit_delivery_job_test.rb` passed: 5 runs, 24 assertions, no failures or errors. A batch-size-1 conflict case verified that the later event was delivered while the conflicting event remained unacknowledged.
- Secret audit delivery was not changed in this slice.
