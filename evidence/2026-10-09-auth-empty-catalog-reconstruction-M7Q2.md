# Authentication acceptance: empty catalog reconstruction

Verified against commit `809ed57629f03052ba311c8c953f4aa682c93ebf` with uncommitted
authentication repairs and unrelated work present. The worktree was changing during this check;
this record identifies the executed operations rather than claiming a frozen final revision.

Six unfinished Avatar migration drafts were preserved byte-for-byte under
`specs/avatar-organization-ownership/migration-drafts/`, outside Rails discovery. The Avatar spec
already required that these drafts not run. Four were empty generator stubs. This preserves the
paused feature without recording incomplete migrations or bypassing `strong_migrations`.

## Commands and observations

- `bundle exec ruby /tmp/four-create-acceptance-catalog.rb`: created 20 new databases using
  `TEMPLATE template0`, after rejecting existing target names. The first sandbox attempt failed
  DNS resolution; the approved network-enabled execution succeeded. No existing database was
  dropped, reset, rolled back, or used as a template.
- Run identifier: `20261009accept1`; manifest:
  `tmp/acceptance-isolated-20261009accept1.json`. The names use prefix
  `codex_integrity_20261009accept1_`, owner `root`, host `primary`, port `5432`. Database OIDs are
  `656354` through `656373`, in manifest order. Each carries the exact disposable comment required
  by `Umaxica::TestEnvironment::DatabaseSafety`. Manifest SHA-256:
  `387d0e619ef370e1a0fce3f76b61aca6474ed7813047e583bacf7143cd92fd1c`.
- With `RAILS_ENV=test`, `PARALLEL_WORKERS=1`, the run identifier and manifest above,
  `bundle exec ruby -r ./config/application -e 'manifest = Umaxica::TestEnvironment::DatabaseSafety.verify_catalog!; puts manifest.fetch(:test_databases).length'`
  verified all 20 catalog identities, including owner, OID, and comment.
- `bundle exec ruby /tmp/four-reconstruct-acceptance-catalog.rb`: exit 0. This set
  `POSTGRESQL_TEST_PREPARE_DATABASES` to the manifest's complete name list and executed
  `bin/rails db:test:prepare`. All schema construction used the repository's migrations. Test
  configuration disabled automatic tracked schema dumps.
- `bundle exec ruby /tmp/four-inspect-acceptance-catalog.rb`: final execution exited 0 and found
  1,346 migration receipts, 879 public tables, and no pending migrations in any database.
  Its initial diagnostic attempt used a private Rails
  helper and failed; the successful version used public `with_temporary_pool_for_each`.

## Schema comparison

The inspection called Rails `dump_schema` for each writable database, setting `SCHEMA` separately
to `/tmp/four-acceptance-20261009accept1-schemas/<name>_structure.sql`. It did not overwrite tracked
dumps. All 20 generated schemas matched the tracked schemas after these explicit normalizations:

1. Test-only `CREATE UNLOGGED TABLE` and `CREATE UNLOGGED SEQUENCE` became their logged forms.
   `config/environments/test.rb` explicitly enables unlogged tables.
2. HMAC definer role suffixes were normalized by database. The three identifier-maintenance
   migrations derive the suffix from the first 12 hexadecimal SHA-256 characters of
   `current_database()`, so disposable names necessarily produce different role literals.
3. Whitespace in dollar-quoted function bodies was normalized. The remaining app difference was
   the layout of `enforce_client_external_identity_binding_facts`, with the same statements.

Raw byte comparisons were unequal because of these differences. The repository task was then
changed to generate per-database temporary dumps, compare their normalized contents, and retain
its check for unstaged tracked-dump differences. The task now verifies the test catalog before
connecting and validates generated HMAC role suffixes against the actual database name. It uses
`PgQuery.scan` to preserve exact SQL string and quoted-identifier token bytes while comparing
function bodies, rather than collapsing all whitespace inside quoted values.

The actual command, with the test run and manifest environment above,
`bin/rails db:verify_no_schema_drift`, exited 0 and printed
`No schema drift detected in 20 schema dump file(s).` Tracked schema files remained unchanged.
`bundle exec rubocop --cache false lib/tasks/db_verify_no_schema_drift.rake` reported no offenses.
The standalone tooling probe `bundle exec ruby /tmp/four-schema-normalization-probe.rb` exited 0:
format-only function changes compared equal; changes inside a string literal, quoted identifier,
and statement compared unequal; the actual database-derived role suffix was accepted and an
incorrect suffix raised. No environment-construction Minitest or Vitest cases were added.

The SQL parser was initially required at task-file load while its existing Gemfile declaration
belonged only to development/test. That would break production Rake loading. The declaration was
moved to the default group without changing its locked version, and loading is lazy inside schema
normalization. With `BUNDLE_WITHOUT=development:test`, a standalone Bundler/Rake process loaded the
task file without defining `PgQuery`, then successfully performed normalization. `bundle check`
also succeeded. This verifies dependency availability and lazy task loading, not a full production
application boot.

This record proves empty-database reconstruction and schema comparison. It does not prove a
populated historical-schema upgrade or any test-suite result. The earlier disposable catalog
`20261008fix1` was left intact, including its already-applied draft write-lock-counter migration.
