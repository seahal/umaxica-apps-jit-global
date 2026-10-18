# Processor notification terminal-state revalidation

- Date: 2026-09-22 UTC
- Repository HEAD: `ab4746f9d403021b3ea5fff53a0a6ae4b4e68ec9`
- Worktree: pre-existing uncommitted changes were present; this check was performed without
  resetting, staging, committing, or reverting unrelated work.
- Scope: preserve the existing processor-notification contract that `NOTIFIED` and `SKIPPED`
  rows are terminal and remain unchanged.

## Adversarial reproduction

Before the fix, the public `mark_failed!` and `mark_notified!` methods did not re-check
`terminal?` while updating a row. A persisted `NOTIFIED` row could therefore be changed to
`FAILED` and then back to `NOTIFIED`, changing `failed_at`, retry metadata, and the notification
timestamp. The regression test reproduced this behavior with a persisted notification and both
terminal statuses.

## Change

`ProcessorErasureNotificationState#mark_failed!` and `#mark_notified!` now take a row lock, re-read
the current row, and return unchanged when the row is already `NOTIFIED` or `SKIPPED`. Non-terminal
`PENDING`/`FAILED` transitions retain their existing behavior. No provider adapter, delivery
receipt, retry-exhaustion policy, permanent-failure state, or external integration was added.

## Verification

- RED: focused state test failed because a `NOTIFIED` row's failure and notification metadata were
  overwritten.
- GREEN focused command:
  `env RAILS_ENV=test UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db PARALLEL_WORKERS=1 bin/rails test test/models/processor_erasure_notification_state_test.rb test/jobs/processor_erasure_notification_job_test.rb test/models/model_only_line_coverage_test.rb`
- Focused result: 36 runs, 314 assertions, 0 failures, 0 errors, 0 skips.
- Full command:
  `env RAILS_ENV=test UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db,test_queue_db,test_occurrence_db bin/rails test`
- Full result: 11,502 runs, 73,299 assertions, 0 failures, 0 errors, 5 skips.
- Static checks: targeted RuboCop reported no offenses; Ruby syntax checks and `git diff --check`
  passed.

## Remaining boundary

This closes only the terminal-row overwrite defect. CF-011 remains open because concrete processor
delivery, provider receipt, bounded retry/exhaustion, and permanent-failure semantics are still not
defined or implemented. No external processor or provider was contacted.
