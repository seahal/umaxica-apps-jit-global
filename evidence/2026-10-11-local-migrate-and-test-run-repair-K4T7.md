# Local `db:migrate` and `bin/rails test` repair

- Commit: `a1ec83a7384a424c97671356268ec5c4ad8347d4`, with uncommitted worktree changes (pending migrations under
  `db/org_principals_migrate` and `db/avatars_migrate` are untracked and affected the result).
- Date: 2026-10-11. Scope: local development and test databases only; no repository code changed.

## `bin/rails db:migrate` (development)

- Observed: `psql ... db/search_structure.sql development_search_db` aborted with
  `relation "ar_internal_metadata" already exists`.
- Cause: `development_search_db` and `development_storage_db` held `ar_internal_metadata` but no
  `schema_migrations`, so Rails treated them as uninitialized and reloaded the structure dump.
- Action: created the missing table with `pool.schema_migration.create_table` in both databases.
- Result: `bin/rails db:migrate` exits 0 and applied the 7 pending zenith migrations;
  `db:migrate:status` lists no `down` entries.

## `bin/rails test`

- Observed: aborted with "Migrations are pending" (9 migrations in the zenith and avatar test
  databases). The shell exports `POSTGRESQL_TEST_PREPARE_DATABASES` with only
  `test_primary_db` and the three ticket databases, so `db:test:prepare` never migrates the rest.
- Action: ran `RAILS_ENV=test bin/rails db:test:prepare` once with all 20 test writer databases in
  `POSTGRESQL_TEST_PREPARE_DATABASES`; the 9 migrations applied.
- Result: `bin/rails test` runs to completion: 15036 runs, 127469 assertions, 1 failure, 9 errors,
  0 skips (seed 49324).

## Remaining failures (not addressed)

- 8 errors, `committed tests require run-owned worker receipts`: Avatar concurrency cases in
  `avatar_ownership_transfers_concurrency_test.rb` (5), `avatar_moniker_writer_operation_test.rb`,
  `avatar_transfer_reservation_test.rb`, `avatar_retention_purge_test.rb`. They require an isolated
  fleet (`POSTGRESQL_ISOLATED_TEST_RUN_ID`), which a plain `bin/rails test` does not provide.
- 1 failure, `Security::AcmeRenameInventoryTest`: untracked
  `adr/preference-tld-sharing-and-jwt-lifecycle-reassessment.md:30` contains "Apex-scoped".
- 1 error, `RecoverySecretParallelGetTest` (com): `visitor delegated to visitor_device_session, but
  visitor_device_session is nil` at `app/models/visitor_rp_session.rb:20`; reproduces when the file
  runs alone. Not diagnosed.
- The exported `POSTGRESQL_TEST_PREPARE_DATABASES` was left unchanged, so the pending-migration abort
  will recur when a migration is added outside the four databases it lists.

## Follow-up: devcontainer environment precedence

- Observed: `.devcontainer/compose.yaml` injects `.env.devcontainer.example` as the process
  environment and `LocalEnvironment.load!` never overrides an existing key, so any key present in
  both files takes the example's value. Seven `.env` keys were shadowed, including
  `POSTGRESQL_TEST_PREPARE_DATABASES` and the three diagnostic-surface user names and passwords.
- Change: `.env.devcontainer.example` now lists all 20 test writer databases and sets
  `RAILS_PERFORMANCE_USERNAME`, `COVERBAND_USERNAME` and `SWAGGER_USERNAME` to `admin`. The CI scope
  in `config/ci.rb` and `.github/workflows/ci.yml` was left at four databases.
- Verified with the new value passed explicitly: `RAILS_ENV=test bin/rails db:test:prepare` exits 0,
  and `test/config/test_environment_edge_contract_test.rb` plus
  `test/config/test_environment_isolation_contract_test.rb` pass (28 runs, 0 failures).
- Not verified: the value as delivered by Compose, which requires recreating the container.
- Later change: removed the empty `RAILS_PERFORMANCE_PASSWORD`, `COVERBAND_PASSWORD` and
  `SWAGGER_PASSWORD` lines from `.env.devcontainer.example` so the `.env` values are no longer
  shadowed. Not verified in a recreated container.
