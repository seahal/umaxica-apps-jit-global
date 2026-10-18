# Xper retirement test environment blocker

## Revision and worktree

The checks below were performed against full commit
`45ed455caa35c0efc2139c1969f541b5b3fc2242`. The worktree contained uncommitted Step 5 Xper
retirement changes that affected the Rails boot. `one.md` and `two.md` remained unchanged. No
database or network configuration was changed.

## Current observations

- `find /home/global /tmp -type f -name '*isolated*.json' -print` returned no isolated-test
  manifests. The previously cited `tmp/acceptance-isolated-20261010p8b-primary.json` is absent in
  this executor.
- A read-only catalog probe booted Rails with `RAILS_ENV=test`,
  `UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example`, and
  `RUBY_DEBUG_ENABLE=0`, then attempted a PostgreSQL `SELECT` using the configured
  `POSTGRESQL_TEST_HOST=primary`:

  ```sh
  RUBY_DEBUG_ENABLE=0 RAILS_ENV=test UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example bin/rails runner 'require "pg"; connection = PG.connect(host: ENV.fetch("POSTGRESQL_TEST_HOST"), port: Integer(ENV.fetch("POSTGRESQL_PORT"), 10), user: ENV.fetch("POSTGRESQL_USER"), password: ENV.fetch("POSTGRESQL_PASSWORD"), dbname: ENV.fetch("POSTGRESQL_DATABASE"), connect_timeout: 3); rows = connection.exec_params("SELECT datname, oid::text AS oid, pg_get_userbyid(datdba) AS owner, shobj_description(oid, '\''pg_database'\'') AS comment FROM pg_database WHERE datname LIKE $1 ORDER BY datname", ["codex_integrity_20261010p8b_%"]); puts JSON.generate(rows.map(&:to_h)); connection.close'
  ```

  It exited 1 before connecting with `could not translate host name "primary" to address:
  Temporary failure in name resolution`. No SQL was executed and no database state changed.
- `/etc/codex/network-policy.json` was absent, and the cloud environment status tool was not
  available in this executor. This does not establish permission for direct TCP or VPN access;
  no network-policy bypass or escalation was attempted.
- The earlier targeted command, `bin/rails test test/integration/xper_retired_hosts_test.rb`,
  stopped before loading test cases because `POSTGRESQL_TEST_PREPARE_DATABASES` omitted 17 verified
  test databases. No test case ran and no database preparation occurred.

## Step 5 acceptance status

- **AT-014 / REQ-014: PASS.** The development Rails boot and static inventory recorded in
  [`2026-10-13-xper-rails-retirement-Q4V7.md`](2026-10-13-xper-rails-retirement-Q4V7.md) found no
  Xper routes, route file, controller directory, host fields, or frontend/locale registration. In
  this continuation, a route-recognition probe checked six former hosts against eight paths (48
  cases, zero product-surface matches); the retained Base host recognized all eight paths. The
  probe also checked the deleted paths, Xper host-field and registry-slot names, frontend stack and
  locale keys. It exited 0. This was route recognition, not an HTTP integration test.
- **AT-015 / REQ-015: BLOCKED.** Rails boot and production-like host construction passed as recorded
  in the original evidence, but `.devcontainer/compose.yaml` remains read-only and retains the
  three Xper aliases. The required environment-construction scope is therefore incomplete.
- **AT-016 / REQ-016: BLOCKED.** The retired-host integration test and twelve shared regressions
  have not run. Route recognition does not certify request behavior. The test-database and network
  blockers above remain.
- **AT-017 / REQ-017: PASS.** The retirement ADR and supersession notes are present; the scoped diff
  contains no model, database, Preference, authentication, Edge, or Cloudflare configuration
  changes. The ADR preserves the future Web Push requirement and states that no replacement Rails
  surface or data change was introduced.

The route probe command was:

```sh
env -u PUBLIC_XPER_SERVICE_URL -u PUBLIC_XPER_CORPORATE_URL -u PUBLIC_XPER_STAFF_URL \
  -u PRIVATE_XPER_SERVICE_URL -u PRIVATE_XPER_CORPORATE_URL -u PRIVATE_XPER_STAFF_URL \
  RUBY_DEBUG_ENABLE=0 RAILS_ENV=development \
  UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example \
  bin/rails runner /tmp/xper-retirement-probe-20261013.rb
```

## Disposition

The retired-host integration test and twelve shared-test regressions remain unverified. Re-run them
only in an executor with the approved isolated-test manifest and a verified network path, deriving
the preparation list from that manifest and retaining `Umaxica::TestEnvironment::DatabaseSafety`.
Do not use the default `test_*` fleet as a substitute for an owned disposable fleet. Step 5 also
remains incomplete until the three Xper aliases are removed from the read-only
`.devcontainer/compose.yaml` mount.

## Follow-up: requested Xper request test command

This review was performed against full commit
`45ed455caa35c0efc2139c1969f541b5b3fc2242`; the worktree still contains uncommitted Step 5 changes.
The requested command was **not run**.

The `POSTGRESQL_TEST_PREPARE_DATABASES` value in `.env.devcontainer.example` names the ordinary
`test_*` fleet. It is a migration-scope list, not an isolated-database identity check. If Rails
prepares test databases, `lib/tasks/test_db_prepare.rake` first calls `DatabaseSafety.verify_catalog!`
and then runs migrations for the selected writer databases. The application also routes test schema
preparation through `db:test:prepare` using `MigrationFailurePropagation`.

The current process has neither `POSTGRESQL_ISOLATED_TEST_RUN_ID` nor
`POSTGRESQL_ISOLATED_TEST_MANIFEST`. A read-only `getent hosts primary` check returned no address;
the earlier catalog probe recorded above also failed DNS resolution before connecting. The proposed
command would therefore not be a verified isolated run, and it could migrate the shared `test_*`
fleet if the host became reachable. No test case or database command was executed for this request;
the targeted request test remains unverified. Resume only in an approved isolated test environment
with its manifest and reachable configured database host.
