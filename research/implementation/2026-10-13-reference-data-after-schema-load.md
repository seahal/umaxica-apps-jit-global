# Reference Data After a Schema Load: Investigation Notes

## Context

- Original plan/spec: none. This started as a diagnosis of a full `bin/rails test` run that reported
  796 errors and 50 failures, most of them `ActiveRecord::InvalidForeignKey`.
- Related decisions/docs/plans: `docs/operations/db-workflow.md`, `lib/tasks/test_db_prepare.rake`,
  the header comment of `db/seeds.rb`, `adr/reference-table-discipline.md`. The repair itself is
  recorded in `evidence/2026-10-13-test-database-reference-rows-T9K3.md`.
- Date: 2026-10-13, against commit `45ed455caa35c0efc2139c1969f541b5b3fc2242` with unrelated
  uncommitted work in the tree.
- Status: no application or task code was changed. The owner decided on 2026-10-13 not to implement
  a permanent fix now. This note preserves the reasoning so the question does not have to be
  re-derived.

## What Went Wrong

Reference rows (status, state and kind lookup rows) are inserted by migrations. Every
`db/*_structure.sql` dump carries `schema_migrations` rows, so loading a dump marks all migrations
as applied and none of their `INSERT` statements run. A database built from a dump has the tables
and the foreign keys but not the rows the foreign keys point at.

On 2026-10-13 the PostgreSQL server restarted and all `test_*` and `development_*` databases were
rebuilt from the dumps. The command that rebuilt them was not observed; `bin/dev` and `bin/setup`
both call `bin/rails db:prepare`.

## How the Rails Tasks Behave Here

Checked against the installed Rails source (`ActiveRecord::Tasks::DatabaseTasks`):

- `db:prepare` is not overridden. For a missing or empty database it loads the structure dump; for
  a database that already has tables it runs pending migrations. It runs `db/seeds.rb` only when
  the primary database was newly initialized.
- `db:migrate` calls the same `initialize_database` first, so on an empty database it also loads
  the dump and then finds nothing pending. It does not run seeds. Replacing `db:prepare` with
  `db:migrate` in `bin/setup` therefore fixes nothing and loses the seeds that do run.
- `db:reset` and `bin/setup --reset` load the dump as well.
- `db:migrate:reset` is `db:drop`, `db:create`, `db:schema:dump`, `db:migrate`. It does run every
  migration, but it first dumps the empty databases, and because
  `config.active_record.dump_schema_after_migration` is `false` in every environment nothing dumps
  again afterwards. All 20 `db/*_structure.sql` files were left as 448-byte empty dumps. Run in
  development it also dropped and recreated the test writer databases without migrating them.
  After using it, restore the dumps (`git restore -- db/*.sql`, or `bin/rails db:schema:dump`) and
  rebuild the test databases.
- `db:test:prepare` is overridden to call `DatabaseTasks.migrate(skip_initialize: true)`. It is the
  only task that replays the migration files, and it requires the databases to be empty.

`docs/operations/db-workflow.md` presents `bin/rails db:migrate:reset` as the correct reset
procedure without mentioning the emptied dumps. That guidance is incomplete.

## Current Sources of Reference Rows

Three mechanisms coexist:

- Migration `INSERT`s. Counted in the development databases immediately after
  `db:migrate:reset`: 105 tables hold rows. 80 have only `id` and timestamp columns; 25 carry
  further columns (11 status tables with one extra column, 12 `publishing_*_vocabularies` tables,
  `avatar_lifecycle_states`, `chronicle_retention_policies` and `jwt_occurrences` with 198 rows).
- `db/seeds.rb`, which re-inserts a hand-listed subset (`ClientStatus`, `OperatorStatus` and
  similar) and replays the JWT occurrence catalogue through the migration's own writer.
- `config/initializers/preference_reference_defaults.rb`, which fills preference reference tables
  at boot. The setting databases held no rows after `db:migrate:reset`, consistent with this.

`ReferenceRecord` does not identify the full set. 167 models include it and all of those define
`DEFAULTS`; a dozen or so preference option models define `DEFAULTS` and `ensure_defaults!` without
including it; others, such as `OperatorSecretCredentialStatus`, have only constants. The helper
common to all of them is `ApplicationRecord.insert_missing_fixed_ids!`.

`adr/reference-table-discipline.md` does not state that migrations own reference rows. That claim
appears only in the `db/seeds.rb` header comment.

## Options Considered

- **Keep migration `INSERT`s and extend `db/seeds.rb` to all 105 tables, idempotently.** Closes
  the gap for `db:prepare`, `db:setup` and `db:reset` with no change to `bin/setup` or `bin/dev`.
  Costs: the 25 tables with extra columns need their values written in two places, and each new
  reference value must be added to both. Seeds do not run when only a non-primary database is
  rebuilt, or after `db:migrate` on an empty database; `bin/rails db:seed` covers those cases.
  Tests are unaffected because `db:test:prepare` replays migrations.
- **Add a development task that replays migrations on empty databases**, as `db:test:prepare`
  does, and call it from both `bin/setup` and `bin/dev`. No list of tables and no duplicated
  values; slower first build.
- **Move seeding out of migrations entirely.** Rejected: existing databases receive new values
  only through migrations, and `db/seeds.rb` returns early in production.
- **Replace reference tables with constants plus CHECK constraints or enums.** Removes the problem
  at its root but rewrites the foreign keys of well over a hundred tables.
- **Strip `schema_migrations` rows from the dumps.** Makes every build replay all migrations and
  departs from standard Rails behavior.

The working conclusion was that inserting reference rows in migrations is correct for moving an
existing database forward, and that the missing piece is a statement of what an empty database must
contain. Either of the first two options supplies it.

## Follow-up Not Done

- No permanent fix was implemented.
- The list of 105 tables came from row counts, not from reading each migration. A table whose rows
  are inserted by a migration and later deleted by another would not appear.
- A comparison of row counts between a dump-built and a migration-built database would detect
  missing seeds mechanically; it was not built.
- Whether the committed dumps match a fresh migration build was not checked
  (`bin/rails db:verify_no_schema_drift`).
- `docs/operations/db-workflow.md` was not corrected.
