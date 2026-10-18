# Occurrence catalog reconstruction gap

- Date: 2026-09-21
- Repository: `seahal/umaxica-apps-jit-global`
- Branch: `feature`
- HEAD: `ab4746f9d403021b3ea5fff53a0a6ae4b4e68ec9`
- Worktree: dirty; unrelated changes were preserved.
- Scope: verify whether the current JWT anomaly reference catalog is reproduced by the occurrence
  database reconstruction and standard seed boundary.

## Observed state

The standard preparation command was run only for the isolated occurrence test database:

```text
env UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example \
  POSTGRESQL_TEST_PREPARE_DATABASES=test_occurrence_db \
  bin/rails db:test:prepare
```

It completed successfully. A read-only Rails runner using `OccurrenceRecord.lease_connection`
reported:

```text
migration_present=true
current_context_rows=0
active_current_context_rows=0
```

The migration marker is therefore present without the current authentication-context catalog rows
in that database. The focused subscriber tests still pass because their tests create representative
rows as test data.

## Reuse attempt

The existing idempotent migration inserter was loaded and called inside an
`OccurrenceRecord.connected_to(role: :writing)` block. It failed before any insert with:

```text
ActiveRecord::MigrationError: JWT anomaly reference tables must exist before current catalog data is inserted
```

The migration's connection was not the occurrence connection, so this is not an approved seed
integration. No monkey patch, connection override, or application change was made.

## Current conclusion

`CF-013` remains unverified/open for the clean occurrence schema-load/seed contract. The missing
catalog is a data-reconstruction concern, not a subscriber verification failure. Resolving it
requires an explicit ownership decision for occurrence reference seeding and a test-database
verification of both migration and schema-load paths. No production, development, shared database,
external service, or GitHub resource was modified. No application code was changed in this check.
