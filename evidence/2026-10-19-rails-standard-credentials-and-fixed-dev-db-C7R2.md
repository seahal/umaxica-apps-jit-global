# Rails-standard credentials and fixed Dev Container database settings

Date: 2026-10-19. Commit: `ff58ff28125fafe405dc76809f6498b64d69e627`, with a dirty worktree that
also carries the uncommitted three.md cycle; that work was preserved and did not affect these
checks.

Decision: user decision in conversation on 2026-10-19, recorded as the amendment in
`adr/runtime-secret-isolation-deferred.md`.

## Change

- Removed the per-role credentials selection from `config/application.rb`,
  `RuntimeRole.credentials_paths`, `database_login`, `ROLE_CONNECTIONS`, `connections_for` and
  `FLAG_*`, and `lib/tasks/runtime_roles.rake`.
- Deleted `config/credentials/development/` (21 tracked `*.yml.enc`, 21 untracked `*.key`).
  `ls config/credentials` now lists only `development.key`, `development.yml.enc`, `production.key`,
  `production.yml.enc`, `test.key`, `test.yml.enc`.
- `config/database.yml` development and test use literal `primary`/`replica`, port 5432,
  `root`/`development`. Production is unchanged (`NEON_*`).
- `Umaxica::TestEnvironment::DatabaseSafety` checks the same literals instead of
  `POSTGRESQL_TEST_HOST`/`PORT`/`USER`/`PASSWORD`/`DATABASE`. The isolated-run variables and
  `POSTGRESQL_TEST_PREPARE_DATABASES` are still read from the environment.
- Removed the PostgreSQL connection variables from `.env.container.devcontainer`.

## Observed

- `bin/rails runner` as `shared`: credentials path `config/credentials/development.yml.enc`; 32
  writer configurations on `primary:5432` as `root`, 30 replica configurations on `replica:5432`.
- `bin/rails runner` as `op-base-app`: same credentials path; `select current_user` on the OP store
  returned `root`.
- `bin/rails db:drop`, then `DROP ROLE` for all 21 `umaxica_role_*` logins (0 remain), then
  `bin/rails db:create db:migrate`: `db:migrate:status` shows 1517 `up`, 0 `down`.
- Focused tests (`test_environment_edge_contract_test`, `database_password_config_test`,
  `local_environment_coverage_test`, `runtime_role_route_guard_test`,
  `runtime_role_route_ownership_test`, `op_client_admission_gate_test`): 41 runs, 220 assertions, 0
  failures, 0 errors.
- `avatar_concrete_ownership_period_test` and the palm OIDC callback test: 20 runs, 0 failures, 5
  errors. All 5 are `committed tests require run-owned worker receipts`, the existing guard for
  committed-transaction tests outside an isolated worker run; not caused by this change.
- RuboCop on the 8 edited Ruby files: no offenses.

## Not passed / limits

- `bin/rails db:verify_no_schema_drift` fails with
  `HMAC definer role does not match database development_com_zenith_db`. The tracked
  `db/com_zenith_structure.sql` at HEAD already names `umaxica_com_*_hmac_definer_269d72da14b2`, the
  hash of the isolated database `codex_integrity_20261017c1a2_com_zenith`. That dump predates this
  change.
- The shell that ran these checks still exported stale `POSTGRESQL_*` variables from an older
  container, including a `POSTGRESQL_TEST_PREPARE_DATABASES` that lists removed `*_ticket_db`
  databases. Commands were run with that one variable unset; the others are no longer read.
- CI (`.github/workflows/ci.yml`) was out of scope. It still connects to `127.0.0.1`, so the test
  job will fail against the fixed `primary` host.
