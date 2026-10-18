# Retention acceptance rebaseline

- Date: 2026-09-21 UTC
- Scope: Frozen Plan FREQ-0064 retention-purge acceptance interpretation
- HEAD: `ab4746f9d403021b3ea5fff53a0a6ae4b4e68ec9`
- Worktree: pre-existing user and implementation changes were preserved; no application code,
  test, migration, schema, or external-service configuration was changed for this rebaseline.
- External writes: none; no GitHub, AWS, Cloudflare, provider, production, shared database, email,
  or SMS service was contacted.

## Previous ambiguity

The previous FREQ-0064 acceptance criterion required that retention purge honor all holds with
`dry-run/bounded deletion`. The slash made dry-run appear to be a co-equal mandatory capability,
although the repository already had an explicit allowlist, bounded batch processing, writer-database
retention clocks, hold and enforcement checks, a kill switch, and model-specific purge/anonymization
behavior.

## Revised contract

The generated Frozen Plan now defines retention safety as:

- explicit allowlisted model/scope processing;
- bounded batch/scope operations using the existing job behavior;
- retention eligibility evaluated during execution;
- retention holds and enforcement restrictions respected;
- an operational kill switch that stops the job before destructive work;
- preservation of rows required by the existing retention/hold/enforcement contract; and
- no raw secret or blanket `expires_at` purge behavior.

`preview`, `dry_run`, simulation APIs, dry-run-only audit events, and dry-run-only schema are not
required by FREQ-0064 and must not be added solely to satisfy this criterion. Provider receipt,
delivery, retry, and permanent-failure semantics remain a separate notification contract.

## Repository evidence

`app/jobs/retention_purge_job.rb` contains the explicit `RETAINABLE_MODELS` allowlist, the default
`batch_size: 500`, writer-database clock lookup per model, `in_batches` processing, the operational
kill switch, Client/Visitor hold and enforcement checks, and Operator enforcement-aware deletion.
`test/jobs/retention_purge_job_test.rb` covers anonymization versus physical deletion, idempotence,
allowlist registration, enforcement blocking, kill-switch catch-up, and sign-up artifact cleanup.
Related retention-hold tests cover active and released holds.

The current worktree could not rerun Rails tests in this shell because `primary` and `valkey-kvs`
were not resolvable. The complete error was a PostgreSQL connection failure before schema setup:
`PG::ConnectionBad: could not translate host name "primary" to address: Temporary failure in name
resolution`. Existing Compose-backed evidence recorded the relevant retention tests passing with
`24 runs, 116 assertions, 0 failures, 0 errors, 0 skips`, and the full suite passing with
`11479 runs, 73335 assertions, 0 failures, 0 errors, 6 skips`.

## Plan validation

The source ledger and generated plan were regenerated with:

```text
ruby /tmp/umaxica-frozen-plan/make_plan.rb
ruby /tmp/umaxica-frozen-plan/validate_plan.rb
```

Result: 70 canonical source rows, 70 FREQ rows, zero mapping errors, `result: PASS`.
The generated plan contains no mandatory dry-run/preview requirement; the only remaining mentions
explicitly state that these features are not required and that provider delivery semantics remain
separate.

## Current execution revalidation

The earlier unavailable-service note above is historical for this rebaseline. In the current
Compose-backed environment, the retention focused suite was rerun with the test service variables
explicitly selected:

```text
PARALLEL_WORKERS=1 bin/rails test \
  test/jobs/retention_purge_job_test.rb \
  test/jobs/retention_purge_legal_hold_test.rb \
  test/jobs/retention_hold_purge_test.rb \
  test/services/retention_cross_database_child_purge_test.rb \
  test/services/retention/cross_database_child_purge_test.rb
```

Result: `23 runs, 88 assertions, 0 failures, 0 errors, 0 skips`.

The current full Rails suite also completed with `11,491 runs, 73,435 assertions, 0 failures,
0 errors, 5 skips`. No retention code, test, schema, or configuration was changed to obtain these
results.

## Status

`Retention blocker: CLOSED` for the dry-run interpretation. Notification delivery/receipt/retry/
permanent-failure remains an independent blocker and is not closed by this record.
