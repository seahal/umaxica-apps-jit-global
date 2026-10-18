# CF-011 local processor-notification contract recheck

- Date: 2026-09-23
- Repository: `seahal/umaxica-apps-jit-global`
- HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Worktree: pre-existing changes were preserved; no reset, cleanup, commit, push, or external
  service access was performed.

## Scope

This recheck only examined the existing local processor-notification boundary. It did not invent
an adapter, provider authentication, receipt protocol, retry-exhaustion rule, permanent-failure
state, or manual-recovery contract.

The current implementation keeps `SUPPORTED_PROCESSORS` empty. An unsupported processor is recorded
as `processor_unavailable` and is not marked `NOTIFIED`. Row-locked state transitions protect
terminal `NOTIFIED` and `SKIPPED` records from later failure or notification transitions. The retry
window is checked using the model's database clock, and a due retry records another failed attempt
without claiming delivery.

The existing tests cover these local contracts:

- unsupported app and com processor requests fail closed;
- unsupported requests do not emit a `processor_erasure.notified` occurrence;
- terminal notifications remain unchanged by later transition attempts;
- a retry scheduled in the future is not processed;
- a due retry is processed and remains a failure when no processor adapter exists.

## Verification

Command:

```text
set -a && . /home/global/workspace/.env.devcontainer.example && set +a
export UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example
export POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db,test_app_zenith_db
export RAILS_ENV=test
PARALLEL_WORKERS=1 bin/rails test test/jobs/processor_erasure_notification_job_test.rb test/models/processor_erasure_notification_state_test.rb
```

Result: `8 runs, 23 assertions, 0 failures, 0 errors, 0 skips`.

## Decision

This is repository-side evidence for the current fail-closed boundary only. It does not satisfy
CF-011's Frozen Plan acceptance condition, which still requires an approved processor adapter,
authenticated and idempotent receipts, transient/permanent failure classification, bounded retry
exhaustion, an immutable permanent-failure state, audit semantics, and manual recovery. Forged
receipt, duplicate delivery, retry exhaustion, permanent failure, and recovery tests cannot be
written without those approved contracts.

CF-011 therefore remains **OPEN — DECISION REQUIRED**. No production or provider success was
claimed, and no implementation change is justified by this recheck.
