# PostgreSQL structure dump regeneration

Date: 2026-09-21

## Scope and safety

The configured test PostgreSQL target was the isolated target recorded during Phase 00. No
database reset, drop, truncate, migration reset, external service access, or business-data write
was performed. The standard schema dump command was used only to read the current database schema
and update repository artifacts:

```text
export UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example
RAILS_ENV=test bin/rails db:schema:dump
```

## Results

All 20 configured `db/*_structure.sql` files were populated from the test database fleet. The
generated artifacts contain schema metadata and `schema_migrations` bookkeeping only; a scan found
no business-data `INSERT` statements. A second `db:schema:dump` produced identical SHA-256 values
for all 20 files, so the dump operation was deterministic during this run.

At the time of this first dump-only check, `RAILS_ENV=test bin/rails db:verify_no_schema_drift`
exited non-zero because every regenerated structure file was intentionally different from the
previously committed empty stub. That result was recorded as worktree drift, not as a successful
clean-drift check.

## Remaining verification

The follow-up reconstruction was performed on the explicitly verified isolated test target and is
recorded in the Phase 09 evidence. This file remains the historical record of the earlier
dump-only run; it must not be read as the final reconstruction result.
