# Occurrence catalog seed reconstruction

- Date: 2026-09-21
- Repository: `seahal/umaxica-apps-jit-global`
- Branch: `feature`
- HEAD: `ab4746f9d403021b3ea5fff53a0a6ae4b4e68ec9`
- Worktree: dirty before and after this slice; unrelated user and prior-agent changes were
  preserved.
- Scope: close the current JWT anomaly catalog reconstruction gap without deleting historical
  occurrence rows or changing the structure-dump contract.

## Change

`db/occurrences_migrate/20260918150000_insert_current_jwt_anomaly_reference_data.rb` now exposes
an idempotent writer that receives the target occurrence connection explicitly. This prevents a
migration invocation from accidentally inspecting the primary database. `db/seeds.rb` invokes the
writer through `OccurrenceRecord.lease_connection` after schema-only loads, skips only when both
occurrence tables are absent during pre-migration bootstrap, and fails loudly for a partial schema.

No schema migration, production configuration, credential, external service, or GitHub resource was
changed. Historical legacy occurrence rows are intentionally retained; the fresh reconstruction
target is the current runtime catalog.

## Red/green evidence

The pre-change standard seed read from `test_occurrence_db` showed zero current
`AUTH_CLIENT_*`, `AUTH_OPERATOR_*`, and `AUTH_VISITOR_*` catalog rows despite migration marker
`20260918150000` being present. The existing migration writer also failed when invoked while the
occurrence model was connected because it used the primary migration connection.

After the change, the standard test seed and its immediate rerun produced:

```text
current_context_rows=78
total_jwt_occurrences=198
status_rows=5  # fixed IDs 0..4
current_context_rows_after_rerun=78
total_jwt_occurrences_after_rerun=198
```

The isolated migration path used a uniquely named temporary test database, applied every migration
under `db/occurrences_migrate`, and produced:

```text
migration_path_statuses=5
migration_path_current_catalog=78
```

The isolated schema-load path loaded `occurrence_structure.sql` into a uniquely named temporary
test database, verified no business rows before seeding, ran the occurrence seed writer twice, and
produced:

```text
schema_load_before_statuses=0
schema_load_before_current_catalog=0
schema_load_after_statuses=5
schema_load_after_current_catalog=78
schema_load_after_rerun_current_catalog=78
```

The temporary databases were dropped with `WITH (FORCE)`. A catalog check afterward found no
remaining `test_occurrence_rebuild_*` database.

## Verification

- Focused Rails tests: 34 runs, 205 assertions, 0 failures, 0 errors, 0 skips.
- Post-change full Rails suite: 11,500 runs, 73,294 assertions, 0 failures, 0 errors, 5 skips.
- Scoped RuboCop for the migration and seed: passed with no offenses.
- `git diff --check` for the changed migration and seed: passed.
- Coverage was not run and was not used as a release gate, per the task instruction.

The full suite's five skips are existing suite skips; no skip, assertion weakening, or test deletion
was introduced for this slice. The separate notification delivery/receipt/retry/permanent-failure
contract remains outside this reconstruction result.
