# Enforcement appeal decision and reconciliation audit

- Date: 2026-09-21 UTC
- Repository: `seahal/umaxica-apps-jit-global`
- Branch: `feature`
- HEAD observed: `ab4746f9d403021b3ea5fff53a0a6ae4b4e68ec9`
- Worktree: pre-existing user and implementation changes were preserved; this audit did not
  reset, clean, stage, commit, or write to GitHub or an external service.

## Contract checked

FREQ-0063 requires the EnforcementAppeal decision, Case state, restriction/recovery side effects,
and Chronicle audit to have one authoritative decision point, an explicit cross-database commit
order, and retryable convergence without claiming distributed atomicity.

## Repository evidence

- `app/models/concerns/enforcement_appeal.rb:38-65` locks and commits the appeal resolution before
  invoking Case-ending or Chronicle side effects. An approved appeal requires the Case to be
  in-force while the Case row is locked. A reviewer cannot be the applying or approving operator.
- `app/operations/enforcement_case_end_operation.rb:31-65` commits the Case end and effect closure
  before releasing principal access or writing the audit event. `reconcile` retries only the
  convergent work and does not reopen the Case.
- `app/jobs/enforcement_reconciliation_job.rb:20-80` processes bounded batches across all three
  realms. Persisted approved appeals rediscover the Case-ending/release work; submitted, approved,
  and rejected appeals rediscover their matching Chronicle event.
- `db/app_zenith_migrate/20260729120000_create_app_enforcement_appeals.rb:5-24`, with equivalent
  `com_zenith` and `org_zenith` migrations, uses a non-null foreign key and a unique index on the
  Case reference. This prevents concurrent submissions from creating multiple appeals for one
  Case.
- `adr/unified-enforcement.md:520-564` explicitly documents the three-database boundary, the
  committed-decision-before-side-effect order, reconciliation, and the accepted non-atomic
  Chronicle durability limit. It does not claim distributed exactly-once delivery.
- `test/models/enforcement_appeal_test.rb:108-163` verifies that approved/rejected decisions remain
  committed when release or audit side effects fail. Existing controller tests verify reviewer
  separation and the public review boundary.

## Adversarial result

No Critical or High implementation defect was found in the inspected paths. The lock order is
appeal then Case for approval; Case-ending paths lock the Case and do not acquire the appeal lock,
so the inspected paths do not introduce an inverse lock order. A failed release or Chronicle write
leaves a durable decision and a discoverable convergence condition rather than reporting full
recovery.

The Chronicle check-then-insert interval is not distributed exactly-once. That is an explicitly
documented residual limitation, not a hidden guarantee. No new outbox or cross-database transaction
was introduced because the accepted ADR rejects that design for this storage topology.

## Verification

Static checks completed:

```text
ruby -c app/models/concerns/enforcement_appeal.rb                         Syntax OK
ruby -c app/jobs/enforcement_reconciliation_job.rb                        Syntax OK
ruby -c app/operations/enforcement_case_end_operation.rb                  Syntax OK
ruby -c app/controllers/base/org/support/enforcement_cases/appeal_reviews_controller.rb
                                                                           Syntax OK
bundle exec rubocop [six inspected files]                                  6 files inspected, no offenses
git diff --check [inspected paths]                                          passed
```

The focused Minitest command was attempted with the repository-supported environment file and
single worker:

```text
UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example \
POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db \
PARALLEL_WORKERS=1 bin/rails test test/models/enforcement_appeal_test.rb test/jobs/enforcement_reconciliation_job_test.rb
```

It was blocked before test execution because this shell cannot resolve the Compose hostname:

```text
ActiveRecord::DatabaseConnectionError: There is an issue connecting with your hostname: primary.
PG::ConnectionBad: could not translate host name "primary" to address: Temporary failure in name resolution
```

No assertion count or runtime pass is claimed for this current shell. Earlier connected core-service
results are retained in their own evidence and are not substituted for this attempt.

## Disposition

FREQ-0063: repository implementation is present and structurally satisfies the frozen contract;
runtime re-execution is `UNVERIFIED` in the current shell because PostgreSQL is unreachable. No
production code, migration, or new schema was changed by this audit.
