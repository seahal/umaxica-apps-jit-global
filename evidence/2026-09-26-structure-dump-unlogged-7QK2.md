# Structure dumps recorded UNLOGGED persistence

Commit: e423890e7357e1fa7975eac45aeacdb416b3bce9 (worktree had uncommitted changes, including new migrations; the fix itself is uncommitted).

## Observed

- `bin/dev` failed in `20260923170000_create_app_authority_resource_lifecycles`:
  `PG::InvalidTableDefinition: constraints on permanent tables may reference only permanent tables`.
- The committed `db/*structure.sql` files contained `CREATE UNLOGGED TABLE` (e.g. 224 in
  `app_zenith_structure.sql`) and 806 `CREATE UNLOGGED SEQUENCE` statements. These came from dumps
  taken from the test database (`create_unlogged_tables = true` in `config/environments/test.rb`).
  So the development database had unlogged `personas` and `enterprises`.

## Done

- Added `lib/tasks/structure_dump_logged.rake`: it hooks `db:schema:dump` and `db:schema:dump:*` and
  rewrites `CREATE UNLOGGED TABLE|SEQUENCE` to plain `CREATE` in `db/*structure.sql`.
- Rewrote the existing structure files.
- Development database: ran `ALTER SEQUENCE/TABLE ... SET LOGGED` in every primary database. For
  circular foreign key sets (publishing, app/com/org_ticket), the foreign keys were dropped and then
  re-created from `pg_get_constraintdef` inside one transaction. No rows were deleted.
- Then `bin/rails db:prepare` exited 0 and applied all pending migrations. After the dump,
  `grep UNLOGGED db/*structure.sql` found no matches.

## Not verified

- The test suite was not run. When the test database is loaded from structure files, its tables are
  now logged. Only tables created by migrations in the test environment are still unlogged.
