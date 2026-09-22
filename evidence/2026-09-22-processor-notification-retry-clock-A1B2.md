# Processor notification retry decision clock

- Date: 2026-09-22 UTC
- HEAD: `ab4746f9d403021b3ea5fff53a0a6ae4b4e68ec9`
- Worktree: pre-existing user and implementation changes were preserved; the change in this
  evidence is limited to the processor notification state concern and its public regression test.
- External writes: none; no processor, email, SMS, AWS, Cloudflare, production, shared database, or
  GitHub service was contacted.

## Finding and RED

`ProcessorErasureNotificationState#mark_failed!(now:)` accepted a decision time for `failed_at`
but calculated `next_retry_at` with a fresh `Time.current`. A regression test using a fixed decision
time failed before the fix because the retry timestamp was based on the current wall clock.

## Change

The existing 15-minute retry interval is now calculated as `now + 15.minutes`. No processor is
allowlisted, no `NOTIFIED` transition was broadened, and no delivery or receipt contract was added.

## Verification

Focused command:

```text
env RAILS_ENV=test UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db PARALLEL_WORKERS=1 bin/rails test test/models/processor_erasure_notification_state_test.rb test/jobs/processor_erasure_notification_job_test.rb test/models/model_only_line_coverage_test.rb
```

Result: `35 runs, 312 assertions, 0 failures, 0 errors, 0 skips`.

Targeted `bundle exec rubocop` reported no offenses for the changed model concern and test. Ruby
syntax checks and `git diff --check` passed. The processor adapter, provider receipt, delivery,
bounded retry exhaustion, and permanent-failure contracts remain unimplemented and are still tracked
by CF-011.

The subsequent full Rails command, run with the same explicit test environment selection, passed
with `11,501 runs, 73,297 assertions, 0 failures, 0 errors, 5 skips`. The five skips were not
introduced by this change. Coverage was not used as a release gate, and no coverage threshold,
assertion, or skip was changed.
