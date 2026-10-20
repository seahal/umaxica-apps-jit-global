# Test suite compatibility with Rails revision 182206b65670

Date: 2026-10-20 HEAD: `87c15e1e5d89344db7dcaaa85ebb1f6972c0c829` Worktree: `Gemfile.lock` had been
changed outside this work. It moved Rails from `72ffadb2073a` (HEAD lockfile) to `182206b65670`
while `rails-erd` and `ruby-graphviz` were added to `Gemfile`. Neither file was changed here. Other
uncommitted database_consistency work was present
(`evidence/2026-10-20-model-validation-and-check-constraints-V5T3.md`).

## Findings and changes

- `bin/rails test` could not boot: `config/initializers/schema_migration_if_not_exists.rb` called
  `connection.internal_string_options_for_primary_key`, which 182206b removed. Rails' own
  `SchemaMigration#create_table` now writes `t.string :version, primary_key: true`, and the
  PostgreSQL adapter at 72ffadb returned exactly `{ primary_key: true }`. The initializer now passes
  that literal, and `test/initializers/schema_migration_if_not_exists_test.rb` expects it instead of
  a mocked adapter collation.
- 28 Secret tests failed only under 182206b, for example `ClientSecretIssuancePersistenceTest`
  expecting ReadonlyAttributeError and receiving RecordInvalid. In 182206b, generated attribute
  writers call `@attributes.write_from_user` instead of `_write_attribute`, so the
  `_write_attribute` guards in `ClientSecretIssuance` and `ClientSecretCredential` no longer ran on
  `update!`. Each guarded fact now also defines its own writer that runs the same check.
- The existing tests served as characterization: the same 219 Secret test runs passed under both
  revisions before and after the change. A temporary copy of the HEAD Gemfile and lockfile was used
  for the old revision, then deleted.

## Test database note

A full run after a reverted bulk experiment had about 2900 fixture-load foreign key errors under
both Rails revisions. Committed rows left by non-transactional tests broke later fixture loads.
`db:test:load_schema` removed those rows, but it rebuilds from the dumps and leaves out rows that
migrations seed, such as `OpAppProtocolEpoch` id 1. The test databases were dropped, created and
migrated with `DatabaseTasks.migrate(skip_initialize: true)`.

## Result

Full `bin/rails test` under 182206b65670: 18110 runs, 2 failures, 18 errors. These are exactly the
20 known baseline failures (Avatar committed-concurrency receipts, Inertia `clearHistory`,
`inertia_rails/devtools` routes).
