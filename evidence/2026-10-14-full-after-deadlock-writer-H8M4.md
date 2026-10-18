# Full Rails regression after sign-out and Browser RP fixes

Recorded 2026-10-14 against commit `aa92265b7e63bf874fddd0aa8f278d5ed19de6b5` on
`feature`. The worktree had 1,056 changed or untracked paths; the result therefore includes
the existing dirty tree. `one.md` and `two.md` were unchanged and retained their frozen hashes.

Command:

```text
env -u POSTGRESQL_ISOLATED_TEST_RUN_ID RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test
```

The run used the ordinary Rails test database manifest only. It completed in 971.755168 seconds:

```text
15274 runs, 129162 assertions, 3 failures, 14 errors, 0 skips
```

The 14 errors are the committed Avatar concurrency/history cases that intentionally require
run-owned worker receipts. They fail at
`ParallelTestDatabaseCloner.verify_owned_worker_execution!`; providing an isolated or disposable
worker database would violate the user's standard-DB-only constraint, so these remain blocked.

The three failures are the existing `DatabaseReconstructionAuthorityTest` checks. Every committed
`db/*_structure.sql` dump contains only PostgreSQL session settings and the dump footer, with no
`CREATE TABLE` definition. Reconstructing or rewriting those dumps requires the unavailable
isolated migration/reconstruction environment and was not attempted.

The previously observed Recovery Secret parallel GET error is absent, and no sign-out/refresh
deadlock is present. Focused regressions for both fixes were green before this run. No isolated
test-run identifier was set, and no database reset, bulk mutation, or destructive operation was
performed.

Source log: `/tmp/umaxica-full-after-two-fixes.log`.
