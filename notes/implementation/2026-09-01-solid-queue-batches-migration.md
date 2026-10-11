# Solid Queue Batches Migration Implementation Notes

## Context

- Original plan/spec: none. The work came from a repeated deprecation warning in
  `log/development.log` --
  `SolidQueue::Dispatcher::Maintenance#warn_once_about_pending_batch_migrations` reporting that
  Solid Queue 1.7.0 has a pending migration that becomes required at 2.0.
- Related decisions/docs/plans: `.agents/harnesses/rules/generic/migrations.mdc`,
  `config/initializers/strong_migrations.rb`, `config/initializers/postgresql_timestamptz.rb`.
- Implementation date: 2026-09-01

## Decisions Made During Implementation

- Decision: build the `solid_queue_jobs.batch_id` index with `algorithm: :concurrently` under
  `disable_ddl_transaction!`, instead of the inline `add_index` the gem's template emits.
  - Why: `solid_queue_jobs` is the busiest table in the queue database, and this repository's
    migration timestamp is past `StrongMigrations.start_after`, so an inline index build is both
    rejected by StrongMigrations and a real production lock. Every statement keeps the template's
    `if_not_exists:` guard, so losing the surrounding transaction does not make a partial run unsafe
    to repeat.
  - Alternatives considered: `safety_assured { ... }` around the template as written. Rejected -- it
    silences the check without addressing the lock it is reporting.
  - Follow-up needed: none.

- Decision: declare the migration as `ActiveRecord::Migration[8.2]` rather than the template's
  `[7.1]`.
  - Why: the application is on `config.load_defaults(8.2)` and 904 of the repository's migrations
    are already `[8.2]`; the migration uses no statement whose behaviour differs between the two
    compatibility layers. `t.datetime` resolves to `timestamptz` either way because
    `config/initializers/postgresql_timestamptz.rb` sets `self.datetime_type = :timestamptz`, which
    is what `db/queues_migrate/20260309000001_convert_timestamps_to_timestamptz.rb` established for
    this database.
  - Alternatives considered: keeping `[7.1]` as generated. Rejected as gratuitous drift.
  - Follow-up needed: none.

## Deviations From Plan

- Change: `db/queue_structure.sql` was left untouched.
  - Why: `bin/rails db:schema:dump:queue` produced a correct 992-line dump, but all 21
    `db/*_structure.sql` files at HEAD are identical 18-line stubs containing only session settings
    and no objects, and all three environments set
    `config.active_record.dump_schema_after_migration = false`. Populating one dump would have made
    it the only non-stub file in the directory. Historic commits that added migrations did update
    populated dumps, so the stubs are a state the repository moved into later, not a convention this
    change should partially reverse.
  - Risk: the committed dumps cannot rebuild any database. `maintain_test_schema!` already fails
    closed on this -- running the test suite with the migration unapplied raised "Migrations are
    pending" rather than loading an empty schema -- so the gap is visible rather than silent, but it
    means every environment's queue database has to be migrated by hand.
  - Follow-up: decide whether `db/*_structure.sql` should be regenerated repository-wide or removed
    outright. Leaving 21 stub files that look like schema dumps but are not is the worst of the
    three options.

## Review Notes

- Tests run: `bin/rails test test/security/invariants/umaxica_architecture_guard_test.rb` (7 runs,
  14 assertions, 0 failures); `bin/rails test test/integration/solid_queue_test.rb` (7 runs, 15
  assertions, 0 failures); `bin/rubocop` on the new migration (no offenses).
  `SolidQueue::Batch.migrated?` returns `true` in development after the migration, which is the
  exact condition the deprecation warning was reporting.
- Tests not run: the full suite. No rollback was executed against the queue database: reversibility
  rests on `add_column`, `add_index`, and `create_table` all being invertible inside `change`, and a
  live `solid-queue-dispatcher` process is connected to the development queue database, where
  dropping the tables under it would produce misleading errors.
- Documentation promotion needed: the `db/*_structure.sql` question above.
