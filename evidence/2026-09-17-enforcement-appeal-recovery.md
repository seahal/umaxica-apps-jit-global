# Enforcement appeal recovery verification

- Date: 2026-09-17 (UTC)
- Branch: `feature`
- Source before this slice: `9753c42ca0f95f1c2a5d190f732f3e958d1b9dff`
- Worktree: pre-existing `README.md` modification, `misc.md`/`refactor.md` deletions, and unrelated
  browser-block notification files were preserved.

## Static inspection

Confirmed in the current source that `EnforcementAppeal#resolve!` previously wrapped the appeal
decision, `EnforcementCaseEndOperation`, and the appeal Chronicle write in one transaction. The Case
end operation itself commits its Case/effect state before access-lock release and Chronicle
delivery. This made a later side-effect exception capable of rolling back an already-completed
appeal decision through the outer transaction.

The implementation now commits the appeal row first, rechecks an approved appeal under the appeal
and Case row locks, and lets `EnforcementReconciliationJob` rediscover submitted, approved, and
rejected appeals. Ended Cases have a separate reconciliation scope. Chronicle event existence is
checked on the writer connection while the source Case row is locked; no transactional audit outbox
or cross-database atomicity claim was added.

## Commands and results

- `ruby -c` for the changed models, operation, job, and tests: passed.
- `bundle exec rubocop` for the eight changed Ruby files: passed; 8 files inspected, no offenses.
- `git diff --check`: passed.
- Focused Rails tests:
  `VALKEY_TEST_HOST=127.0.0.1 VALKEY_TEST_PORT=6379 CACHE_REDIS_URL=redis://127.0.0.1:6379/3`
  `RATE_LIMIT_REDIS_URL=redis://127.0.0.1:6379/4 AUTH_STATE_REDIS_URL=redis://127.0.0.1:6379/5`
  `VALKEY_NAMESPACE_RUN_ID=enforcement-appeal-20260917 bundle exec rails test` with
  `test/models/enforcement_appeal_test.rb`, `test/jobs/enforcement_reconciliation_job_test.rb`,
  `test/operations/enforcement_case_apply_failure_test.rb`, and
  `test/models/app_enforcement_case_test.rb`: blocked before assertions by
  `ActiveRecord::DatabaseConnectionError`; PostgreSQL host `primary` could not be resolved.

The Rails test result is unverified, not a pass. No migration, queue worker, production datastore,
or external notification was executed.

## Remaining limitation

The source Case database and Chronicle database remain separate. The writer-side existence check
prevents the normal crash-after-commit duplicate on retry, but a process crash between the check and
Chronicle insert is still within the accepted non-atomic audit durability limit. The implementation
does not claim distributed exactly-once audit delivery.

## Follow-up verification

- Date: 2026-09-17 UTC
- The available isolated surface databases and explicit loopback test Valkey URLs supported the
  focused Rails run.
- The complete focused enforcement set, including `EnforcementAppealTest` and
  `EnforcementReconciliationJobTest`, passed with 53 runs / 182 assertions.
- The earlier audit-side-effect test used an instance stub that did not reach the reloaded Case
  association. It now injects failure at `EnforcementEvent.create!`, the actual Chronicle event
  persistence boundary, and confirms the appeal decision remains committed.
- No migration, queue worker, production/shared datastore, or external notification was executed.

The separate Chronicle database and the accepted crash gap remain unchanged; this follow-up does not
claim distributed exactly-once audit delivery.
