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

`RAILS_ENV=test bin/rails db:verify_no_schema_drift` exited non-zero because every regenerated
structure file is intentionally different from the previously committed empty stub. That result
is recorded as expected worktree drift, not as a successful clean-drift check. The clean migration
reconstruction and schema-load equivalence checks have not yet been run.

## Remaining verification

The populated dumps do not prove that a new empty database can be reconstructed from the current
migrations, nor that loading a dump and running the required seeds produces the same shape. Those
checks require an explicitly verified isolated database target and remain open for Phase 09.
