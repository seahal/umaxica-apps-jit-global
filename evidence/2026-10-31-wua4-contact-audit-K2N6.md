# Contact audit delivery past failures

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes, including the implementation and tests.
- A conflicting Chronicle UUID prevented a later Contact source event from being acknowledged before the fix. The job now retains and reports failures, continues through bounded pages and raises after the scan.
- `PARALLEL_WORKERS=1 bin/rails test test/jobs/contact_audit_delivery_job_test.rb` passed: 6 runs, 48 assertions, no failures or errors. The added conflict case uses batch size 1 and verifies that the later event is delivered while the conflicting event remains unacknowledged.
- Social and Secret audit delivery were not changed in this slice.
