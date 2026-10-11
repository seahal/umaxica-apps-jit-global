# Avatar retention deferral

Verified on 2026-10-10 against commit `2a1644f73238839ed7ed513bd4681ea393a86682` with unrelated
working-tree changes preserved. The check used the disposable PostgreSQL manifest
`tmp/acceptance-isolated-20261009social3.json` and `PARALLEL_WORKERS=1`.

`bundle exec rails test test/jobs/avatar_retention_purge_test.rb test/jobs/retention_purge_job_test.rb`
completed with 19 runs, 79 assertions, zero failures, errors, or skips.

The focused test proves that a due Avatar with concrete ownership history remains present, its
history remains present, and repeated `RetentionPurgeJob` runs keep one `ownership_history`
deferral while incrementing the observation count. Existing history-free Avatar purge behavior
also remained green. This does not decide the unresolved personal-data retention period.
