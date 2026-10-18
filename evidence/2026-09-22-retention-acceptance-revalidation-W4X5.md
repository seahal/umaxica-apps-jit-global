# Retention acceptance revalidation

- Date: 2026-09-22 UTC
- HEAD: `ab4746f9d403021b3ea5fff53a0a6ae4b4e68ec9`
- Worktree: pre-existing user and implementation changes were preserved; no retention code,
  tests, migrations, schema, or configuration were changed in this revalidation.
- External writes: none; no GitHub, AWS, Cloudflare, provider, production, shared database, email,
  or SMS service was contacted.

## Verification

The focused retention safety suite was run with the repository's Compose-backed test services and
explicit test environment selection:

```text
env RAILS_ENV=test UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db PARALLEL_WORKERS=1 bin/rails test test/jobs/retention_purge_job_test.rb test/jobs/retention_purge_legal_hold_test.rb test/jobs/retention_hold_purge_test.rb test/models/concerns/retainable_test.rb test/services/retention/cross_database_child_purge_test.rb test/services/retention_cross_database_child_purge_test.rb test/operations/withdrawal_personal_data_anonymizer_test.rb
```

Result: `42 runs, 173 assertions, 0 failures, 0 errors, 0 skips`.

The direct `RetentionPurgeJob` file contributed `12 runs, 53 assertions, 0 failures, 0 errors,
0 skips`. The broader set covers Retainable eligibility, active/released holds, enforcement
blocking, kill-switch behavior, bounded child cleanup, and anonymization.

A read-only Rails inspection of the explicit `RETAINABLE_MODELS` allowlist found no allowlisted
model with archive-specific columns, state, or instance methods. This verifies the current
repository boundary, not a future archive/legal-retention policy. Such a policy remains a separate
approval gate; its absence is not converted into an implicit purge permission.

The Frozen Plan validator and `git diff --check` also passed. The latest full Rails suite is
`11,503 runs, 73,303 assertions, 0 failures, 0 errors, 5 skips` from the current Compose-backed
revalidation.

## Disposition

`ACCEPTED_AS_EXISTING_IMPLEMENTATION`. Retention safety is expressed through the explicit
allowlist, bounded batch/scope execution, writer-database clock, hold and enforcement checks, and
kill switch. A dry-run, preview, simulation API, dry-run-only command/service/event/schema is not
required and was not added. Notification delivery/receipt/retry/permanent-failure remains a
separate contract.
