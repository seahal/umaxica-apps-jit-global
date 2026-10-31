# WU-A5 Passkey audit delivery across pages

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Staged, unstaged and untracked worktree
changes affected the run. Local test databases were used; production and Neon were not targeted.

The existing failure test passed with the default batch, but failed when the failing event was
placed at the end of the first batch: the following event remained unacknowledged. The local app
test database contained 26 unrelated pending outbox rows, so the test set its page size to the
existing pending count plus one; it did not delete or alter those rows outside the test transaction.

The delivery job now walks pending rows in ascending-ID pages through the highest pending ID
observed at the start of each source scan. It reports each failed event, keeps the first exception
for the final job failure, leaves the failed row unacknowledged and proceeds to later pages.
Newer IDs wait for another run, so a continuously growing queue does not make a scan unbounded.
The targeted case passed: 1 run, 7 assertions.

`PARALLEL_WORKERS=1 bin/rails test test/jobs/passkey_audit_delivery_job_test.rb
test/operations/passkey_mutation_authorization_test.rb` passed: 11 runs, 103 assertions,
no failures, errors or skips. RuboCop reported no offenses in the changed Ruby files and scoped
`git diff --check` passed. This is one WU-A5 slice; passkey slot migration and other acceptance
remain unverified.
