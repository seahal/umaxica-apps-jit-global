# P12a identifier transition evidence

Date: 2026-10-12

Repository: `/home/global/workspace`

Branch: `feature`

Code HEAD at the start of this slice: `ccceabd05d2e3a8f923ce398046f99d026a5b78e`

The worktree was already dirty. The slice preserved the existing staged, unstaged and untracked
changes; the starting status contained 119 paths. No reset, clean, stash, worktree, push or
production/shared-database operation was performed.

## Scope

This record covers two independent P12a schema stages on the run-owned PostgreSQL manifest
`tmp/acceptance-isolated-20261010p8b-primary.json` (`10.89.2.3`, PostgreSQL 17.7):

- the four owned preference/Client Passkey `public_id` columns becoming `NOT NULL`;
- additive bigint mapping columns for the legacy string key in
  `org_zenith.staff_identity_audit_events` and its `staff_identity_audits.event_id` references.

It does not claim a real-data cutover, final staff-event PK/FK replacement, complete identifier
classification, production/shared-database application or global identifier acceptance.

## Staff-event Red/Green and migration checks

Before the additive migration was implemented, the public transition test failed as expected with
one missing `id_bigint` column. After the migration and bounded operation were added, the focused
command was:

```text
RAILS_ENV=test PARALLEL_WORKERS=1 POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p8b \
POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p8b-primary.json \
POSTGRESQL_TEST_HOST=primary POSTGRESQL_DATABASE=postgres \
POSTGRESQL_TEST_PREPARE_DATABASES=codex_integrity_20261010p8b_app_zenith,\
codex_integrity_20261010p8b_com_zenith,\
codex_integrity_20261010p8b_org_zenith \
bundle exec rails test \
test/models/staff_identity_audit_event_bigint_transition_test.rb \
test/operations/staff_identity_audit_event_bigint_backfill_operation_test.rb
```

Observed result: `4 runs, 28 assertions, 0 failures, 0 errors, 0 skips`.

The run-owned migration was reversed and reapplied with `db:migrate:down:org_zenith` and
`db:migrate:up:org_zenith` for version `20261012085039`; both commands exited 0. The rehearsal
removed and recreated the three additive columns and their indexes. The synthetic operation test
preserved the old event code, assigned one bigint mapping, mapped one audit reference and returned
zero assignments on repeat. No real event contents were recorded here.

The ORG structure dump was generated with `db:schema:dump:org_zenith` using the same run-owned
manifest and `PARALLEL_WORKERS=1`; it exited 0. The dump contains the additive columns and reviewed
B-tree indexes while retaining the original string primary key and foreign key.

The current run-owned dry run was also executed through Rails:

```text
StaffIdentityAuditEventBigintBackfillOperation.call(dry_run: true, batch_size: 100)
```

It returned `events_assigned: 0`, `audit_references_assigned: 0`, `events_missing: 0`,
`audit_references_missing: 0` and `unresolved_audit_references: 0`. This is an aggregate disposable
catalog result, not a claim about any shared or production database.

## Full verification gate after this schema slice

Rails was run with four workers against all twenty run-owned databases using the repository's
manifest and `bundle exec rails test`. Observed result: `15096 runs, 128108 assertions, 0 failures,
0 errors, 0 skips` (exit 0).

Vitest was run with `bun run test`. Observed result: `99 files passed, 1140 tests passed` (exit 0).

Targeted RuboCop for the new operation and tests reported no offenses. The initial schema-dump
attempt without the repository-required `PARALLEL_WORKERS` variable failed during the safety
initializer; it was not treated as a product result, and the same dump command was rerun with the
required isolated settings and passed.

## Limits

The current isolated catalog has no production or shared rows for this staff-event rehearsal. The
additive mapping is therefore proven on synthetic rows and schema state only. The original string
key remains authoritative. A later cutover still requires consumer inventory, complete mapping
reconciliation, forward recovery and separately authorized data application. Schema-drift
verification against committed dumps remains a repository-state check until the intentional dump
changes are committed by their owner.
