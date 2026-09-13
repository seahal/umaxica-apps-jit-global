# 2026-09-10 Neon production_primary_db

## Goal

Create the Rails `primary` database on Neon and apply `db/migrate/` (Flipper).

`config/database.yml` production `primary` is `production_primary_db` with
`migrations_paths: db/migrate`. That database was missing after the 2026-09-04
imaging, which loaded Flipper into the old name `production_platform_db`.

## Steps

1. `CREATE DATABASE production_primary_db OWNER neondb_owner` on the Neon
   primary (`neondb`).
2. Development boot + `DatabaseTasks.with_temporary_connection` to
   `production_primary_db`; ran `20260807000000 CreateFlipperTables`.
3. `ar_internal_metadata.environment` was written as `development` by that
   boot; updated to `production` to match the other Neon databases.

## Result

`production_primary_db` public tables: `ar_internal_metadata`,
`flipper_features`, `flipper_gates`, `schema_migrations`.
`schema_migrations` has `20260807000000`. Replica reports
`pg_is_in_recovery() = t` and 1 migration row without a separate write.

`production_platform_db` was not dropped.
