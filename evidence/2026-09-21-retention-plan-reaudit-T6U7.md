# Retention Frozen Plan re-audit

- Date: 2026-09-21 UTC
- Scope: FREQ-0064 / retention purge acceptance criteria and the related tracked backlog row
- HEAD: `ab4746f9d403021b3ea5fff53a0a6ae4b4e68ec9`
- Worktree: pre-existing user and implementation changes were preserved; this re-audit did not
  change application code, tests, migrations, schema, configuration, or external services.
- External writes: none; no GitHub, AWS, Cloudflare, provider, production, shared database, email,
  or SMS service was contacted.

## Original ambiguity

The earlier retention planning wording used `dry-run/bounded deletion`, and the tracked backlog
used `Phase 5/6 audit and dry-run slices.` The slash and the slice name made a dry-run capability
look like a co-equal implementation requirement beside the safety property of bounded deletion.
The plan did not state whether `bounded` applied to each batch/scope operation or to the total
job invocation. It also allowed `required unarchived data` to be read as a request for a new
archive or preview subsystem.

## Adversarial findings and adjudication

- `RET-ADV-001` — ACCEPTED. Dry-run capability and bounded destructive processing were conflated.
  The Frozen Plan now states that retention safety is a property of the existing operation and
  explicitly excludes a new preview, simulation, or dry-run interface.
- `RET-ADV-002` — ACCEPTED. `required unarchived data` was under-specified. It now means data
  protected by an already approved model-specific retention, hold, enforcement, or archive rule;
  no new archive policy or archive subsystem is inferred.
- `RET-ADV-003` — ACCEPTED. `bounded` now means each deletion/anonymization operation is limited
  by an explicit batch/scope. Multiple bounded batches in one scheduled invocation are allowed;
  a total-run preview or total-run cap is not part of this contract.
- `RET-ADV-004` — ACCEPTED. The kill-switch acceptance is limited to the current contract: the
  job checks it at the start of each execution and performs no destructive work when suspended.
  A new mid-batch interruption protocol is not required by this correction.
- `RET-ADV-005` — NON-BLOCKING FOLLOW-UP. `RETAINABLE_MODELS` uses `safe_constantize` and can
  silently omit a misspelled allowlist entry. The current registry test verifies that loaded
  Retainable models are listed, but not the reverse direction. This pre-existing hardening gap is
  unrelated to dry-run semantics and was not changed in this plan-only phase.

## Revised retention acceptance contract

Retention deletion/anonymization MUST:

- use an explicit allowlisted model/scope set;
- process each deletion/anonymization operation in an explicit bounded batch/scope;
- evaluate eligibility using the writer-database retention clock at the operation's decision
  point;
- respect applicable retention holds and enforcement blocks;
- stop before destructive work when the operational kill switch is enabled; and
- preserve data required by the currently approved model-specific retention, hold, enforcement,
  or archive rules.

The contract does not require `RetentionPurgeJob.preview`, `perform(dry_run: true)`, a dry-run-only
service or command, a dry-run-only audit event, or a dry-run-only schema. These MUST NOT be added
solely to satisfy FREQ-0064. Notification provider receipt, delivery, retry, and permanent-failure
semantics remain a separate contract.

## Repository evidence

`app/jobs/retention_purge_job.rb:22-43` defines the explicit model allowlist. Lines 55-79 apply the
operational kill switch, run bounded `in_batches(of: batch_size)` scopes with a default batch size
of 500, and obtain a writer-database clock per model. Lines 88-100 apply the operator-specific
bounded path and enforcement exclusion. Lines 124-151 re-evaluate client/visitor holds and
enforcement before anonymization. `app/services/sign_up_artifact_cleanup.rb:18-63` has its own
explicit bounded cleanup loop with `FOR UPDATE SKIP LOCKED`.

`test/jobs/retention_purge_job_test.rb:10-93` covers eligibility, keep behavior, lifecycle
separation, idempotence, and artifact cleanup. Lines 142-155 cover allowlist registration;
lines 157-216 cover enforcement blocks; and lines 218-252 cover kill-switch suspension and safe
catch-up. `test/jobs/retention_hold_purge_test.rb:9-63` and
`test/jobs/retention_purge_legal_hold_test.rb:8-43` cover active/released holds. The cross-database
retention test at `test/services/retention/cross_database_child_purge_test.rb:9-35` confirms that
non-audit children are removed while chronicle audit data is retained.

`adr/retainable-concern-and-retention-purge.md:134-151` already describes the same allowlist,
writer-clock, batch, hold/enforcement, kill-switch, and model-specific contract and explicitly
states that dry-run/preview/simulation is not required. No ADR change was necessary.

The tracked plan now also contains an explicit scope clarification: source-owner/data-transformation
dry runs and the unrelated optional unsubscribe preview remain separate requirements and cannot be
read as RetentionPurgeJob capabilities.

## Verification performed

The focused retention command was run with isolated test database names and `PARALLEL_WORKERS=1`:

```text
env UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example \
POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db \
PARALLEL_WORKERS=1 bin/rails test \
  test/jobs/retention_purge_job_test.rb \
  test/jobs/retention_purge_legal_hold_test.rb \
  test/jobs/retention_hold_purge_test.rb \
  test/services/retention_cross_database_child_purge_test.rb \
  test/services/retention/cross_database_child_purge_test.rb
```

Result: `23 runs, 88 assertions, 0 failures, 0 errors, 0 skips`.

The first network-isolated attempt stopped before schema preparation because `primary` could not
resolve. It was treated as an environment result, not as a code result; the same focused command
with the test services reachable completed as recorded above. No application workaround was used.

The Frozen Plan was regenerated and validated with:

```text
ruby /tmp/umaxica-frozen-plan/make_plan.rb
ruby /tmp/umaxica-frozen-plan/validate_plan.rb
```

Result: 70 canonical source rows, 70 FREQ rows, zero mapping errors, `result: PASS`.
`git diff --check -- plans/backlog/2026-09-17-integrated-hardening-plan.md` also passed.

## Status

`Retention blocker: CLOSED` for the dry-run interpretation. Retention purge disposition is
`ACCEPTED_AS_EXISTING_IMPLEMENTATION`; the existing implementation satisfies the revised
retention-safety contract as evidenced above, and absence of a dry-run API is not a defect.

Notification delivery/receipt/retry/permanent-failure, and any unapproved legal-retention or
archive policy, remain independent dependencies and are not closed by this record.

The generated Frozen Plan source and artifact currently live under `/tmp/umaxica-frozen-plan/` and
are not tracked repository files. The tracked backlog row was updated with the durable acceptance
wording; preserving the generator/ledger as a repository artifact is a separate plan-maintenance
concern, not a retention safety blocker.
