# Retention, notification, and RP route revalidation

- Date: 2026-09-22 UTC
- HEAD: `277673d13547d722fc88f830711eee69b923a7e8`
- Worktree: uncommitted implementation and documentation changes were preserved; no unrelated
  changes were staged, committed, reverted, or discarded.
- External writes: none; no GitHub, AWS, Cloudflare, provider, production, shared database, email,
  or SMS service was contacted.

## Focused verification

The focused repository contract set was run against the Compose-backed PostgreSQL test services
with the explicitly selected test environment:

```text
env UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example \
RAILS_ENV=test \
POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db \
PARALLEL_WORKERS=1 \
bin/rails test \
  test/jobs/retention_purge_job_test.rb \
  test/jobs/retention_purge_legal_hold_test.rb \
  test/jobs/retention_hold_purge_test.rb \
  test/services/retention/cross_database_child_purge_test.rb \
  test/services/retention_cross_database_child_purge_test.rb \
  test/models/concerns/retainable_test.rb \
  test/jobs/processor_erasure_notification_job_test.rb \
  test/models/processor_erasure_notification_state_test.rb \
  test/integration/routes/core_route_contract_test.rb
```

Result: `59 runs, 374 assertions, 0 failures, 0 errors, 0 skips`.

The run covers the revised retention safety contract, active/released holds, enforcement blocks,
kill-switch behavior, bounded child cleanup, anonymization, notification retry-window behavior,
terminal notification protection, and the canonical Core `/sign/callback` route contract.

## Static verification

- Ruby syntax checks for the changed notification job, state concern, and tests: passed.
- Targeted RuboCop for the changed notification files: `4 files inspected, no offenses detected`.
- `git diff --check`: passed after removing two documentation trailing-space errors.
- Frozen Plan validator: 70 canonical source rows and 70 FREQ rows, zero mapping or closure
  errors, `result: PASS`.
- The latest complete Rails result including the notification retry-window slice remains recorded
  in `evidence/2026-09-22-processor-notification-retry-window-H4J5.md`: `11,505 runs, 73,310
  assertions, 0 failures, 0 errors, 5 skips`.

## Disposition

Retention remains `ACCEPTED_AS_EXISTING_IMPLEMENTATION`; absence of a dry-run or preview API is
not a defect. Notification provider delivery, receipt, retry exhaustion, and permanent-failure
semantics remain the independent `CF-011` contract. External RP registrations, production worker
topology, and the unresolved Auth/Base authority handoff remain outside this local verification.
