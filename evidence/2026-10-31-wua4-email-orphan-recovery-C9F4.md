# APP signup Email orphan recovery inventory

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting the inspected implementation, tests and documentation.
- Inspected the APP Email signup writer: the candidate creator commits the pending Client and Email on the Zenith writer before the controller obtains or creates and binds its OP Flow. `SignUpArtifactCleanup.cleanup_pending!` selects existing terminal Flow rows; `RetentionPurgeJob` separately invokes the read-only stuck-registration query. The current runbook explicitly says that `flow_missing` has no safe release entry point. This differs from two.md XDB-15's requested recovery of orphaned unfinished candidates.
- With `PARALLEL_WORKERS=1`, ran `bin/rails test test/operations/email_sign_up_candidate_creator_test.rb test/queries/sign_up_stuck_registration_report_query_test.rb`: 6 runs, 58 assertions, no failures or errors. These tests do not inject an independent OP failure or exercise a new orphan cleanup path.
- Updated the runbook's obsolete APP/COM report scope to match the current APP-only job and query. `git diff --check -- docs/operations/stuck-sign-up-registration-runbook.md` passed. No candidate or persisted data was retired or deleted by this check.
