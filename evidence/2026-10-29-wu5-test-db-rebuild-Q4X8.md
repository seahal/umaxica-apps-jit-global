# WU-5 amendment: base test databases rebuilt from migrations after surviving-connection wipes

- Context: after the WU-5 ticket (evidence/2026-10-29-wu5-com-db-removal-ticket-Q4X8.md) the base
  `test_*` databases were found recreated with complete schemas but **empty `schema_migrations`**
  (6 publishing / ~35 app_zenith etc. migrations imported as schema from the regenerated
  `db/*_structure.sql` dumps, no receipts). `db:test:prepare` therefore re-applied the first pending
  migration and failed with `PG::DuplicateTable` (`relation "publishing_media_files" already exists`).
  All base test DBs showed `schema_migrations = 0` (`SELECT count(*) FROM schema_migrations;` per
  database: test_app_zenith_db 0, test_publishing_db 0, test_avatar_db 0, …).
- Action taken (same authorized destructive class as the recorded WU-5 ticket; local Dev Container
  `primary` on localhost, test databases only):
  - Dropped every `test_%` database on the test host (850 entries listed:
    `SELECT count(*) FROM pg_database WHERE datname LIKE 'test_%'` → 850), including worker clones
    and replicas. No application data existed: test databases hold fixture/test rows only.
  - Recreated the selected base test databases empty (`db:create`) so nothing imports a structure
    dump, then `db:test:prepare` (migrations only, `skip_initialize: true` per the task override in
    `lib/tasks/test_db_prepare.rake`) rebuilt each from migrations.
- Verification: `db:test:prepare` completed for the full migration scope without errors;
  `schema_migrations` counts restored (test_app_zenith_db 424, test_publishing_db 6, test_avatar_db
  90, test_com_setting_db 13, test_occurrence_db 118, test_rp_base_app_db 8; 52 test_* databases
  exist — 26 writers + 26/17 replicas including the nine retained rp cells).
- Missing thickness: the rp-cell test writer/replica databases were created explicitly because
  `config/database.yml` renders them through the `rp_cells` ERB list, so the first empty `db:create`
  pass only created the literal test database names.
- Follow-up: full suite rerun results recorded in the WU-5 convergence evidence.
