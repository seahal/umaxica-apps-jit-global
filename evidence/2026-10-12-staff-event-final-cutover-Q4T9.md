# Staff identity audit-event bigint cutover evidence

Date: 2026-10-12

Repository HEAD at verification start: `ccceabd05d2e3a8f923ce398046f99d026a5b78e`.
The worktree contained pre-existing staged, unstaged and untracked changes; no reset, clean,
stash, rebase, push, GitHub edit or worktree operation was used. The verification database was
the run-owned disposable manifest `tmp/acceptance-isolated-20261010p8b-primary.json` on the
local PostgreSQL test server. No production or shared test data was used by the controlled
rehearsal.

## Checks performed

- The consumer inventory found no application reader or writer for the model-less
  `staff_identity_audit_events`/`staff_identity_audits` catalogue pair beyond the persisted audit
  reference. The old string key was therefore retained only as a correspondence value.
- `20261012100000_cut_over_staff_identity_audit_event_bigint_keys.rb` was applied after the
  additive mapping migration. It installed a temporary bigint foreign key and non-null checks,
  promoted the mapped bigint to the event primary key, renamed the audit reference, reattached
  the final foreign key and removed the temporary mapping columns.
- `20261012100100_validate_staff_identity_audit_event_bigint_foreign_key.rb` validated the checks
  and foreign key, made `legacy_id`, `legacy_event_id` and `event_id` required, and removed only
  the transitional checks.
- A synthetic event/reference pair was exercised through validation down, structural down,
  structural up and validation up. The bigint identity and both legacy codes were preserved; the
  synthetic rows were deleted after the rehearsal. No row was copied from or exposed as raw
  sensitive data.
- The final run-owned catalog showed `staff_identity_audit_events.id` as a non-null bigint
  primary key, `staff_identity_audits.event_id` as a non-null bigint foreign key, required
  `legacy_id`/`legacy_event_id`, and no `id_bigint`, `event_id_bigint` or old string foreign key.
  The fixed catalogue has no automatic sequence.

Focused command:

```text
POSTGRESQL_TEST_PREPARE_DATABASES=<manifest databases> POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p8b POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p8b-primary.json POSTGRESQL_TEST_HOST=primary POSTGRESQL_DATABASE=postgres RAILS_ENV=test PARALLEL_WORKERS=4 bundle exec rails test test/models/staff_identity_audit_event_bigint_transition_test.rb test/operations/staff_identity_audit_event_bigint_backfill_operation_test.rb
```

Result: `5 runs, 39 assertions, 0 failures, 0 errors, 0 skips`.

Targeted style command:

```text
bundle exec rubocop app/operations/staff_identity_audit_event_bigint_backfill_operation.rb test/models/staff_identity_audit_event_bigint_transition_test.rb test/operations/staff_identity_audit_event_bigint_backfill_operation_test.rb db/org_principals_migrate/20261012100000_cut_over_staff_identity_audit_event_bigint_keys.rb db/org_principals_migrate/20261012100100_validate_staff_identity_audit_event_bigint_foreign_key.rb
```

Result: five files inspected, no offenses.

The final ORG schema dump was regenerated with the run-owned manifest and exited zero. The
repository `db:verify_no_schema_drift` command still exits 1 because eleven intentionally dirty
structure dumps are present in this uncommitted worktree, including `db/org_zenith_structure.sql`;
this is recorded as schema-drift evidence, not treated as a clean committed-schema gate.

## Gate 2 after the slice

The current four-worker full Rails command completed with `15148 runs, 128275 assertions, 0
failures, 0 errors, 0 skips` in 335.118 seconds. `bun run test` completed with `99 files, 1140
tests` in 12.83 seconds. CI, Podman, production services, external providers and shared/production
database validation were not used.

The result verifies the current dirty worktree and disposable schema only. It does not establish
full ID-1 completion, D-11 committed-transaction isolation for every required case, Avatar P10b or
P12b cutover/write-barrier completion, host Alloy runtime verification, or a privacy-retention
decision.

## Unprefixed local development command

One migration command was initially started without the isolated-manifest environment prefix while
diagnosing the tool invocation. It targeted the local `development_org_zenith_db`, not a production
or shared test database, and applied the same reviewed migration set. A read-only follow-up found
zero rows in both staff audit tables and confirmed migration versions `20261012085039`,
`20261012100000` and `20261012100100`. This was not used as acceptance evidence; the controlled
rehearsal and all reported test results use the run-owned disposable manifest above.
