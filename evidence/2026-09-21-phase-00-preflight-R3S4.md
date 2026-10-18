# Phase 00 preflight and current regression verification

Date: 2026-09-21

## Scope and safety

The check ran from `/home/global/workspace` with
`UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example`. The required test
environment variables were checked for presence without printing their values. The test
credential key was checked for existence without reading its contents. No application source,
test, credential, or external service configuration was changed by the preflight.

## Preflight

Command:

```text
bundle exec ruby -r ./lib/local_environment -e 'LocalEnvironment.load!; load "scripts/test-environment-check"'
```

Result: passed against the isolated test services.

- PostgreSQL test target: `10.89.0.3/32:5432`
- PostgreSQL version: `17.7`
- PostgreSQL test databases discovered: `646`
- Valkey `rate_limit`: `valkey-kvs:6379`, database `4`, `PONG`, version `7.2.4`
- Valkey `auth_state`: `valkey-kvs:6379`, database `6`, `PONG`, version `7.2.4`

The first sandbox-only attempt could not resolve the service hostname. The same check was
rerun with the approved network access needed to reach the already-configured container services;
the successful result above is the authoritative preflight result.

## Focused verification

Command:

```text
PARALLEL_WORKERS=1 bin/rails test \
  test/tooling/database_reconstruction_authority_test.rb \
  test/models/application_record_test.rb \
  test/jobs/retention_purge_job_test.rb \
  test/services/sign_up_artifact_cleanup_test.rb
```

Result: `37 runs, 188 assertions, 0 failures, 0 errors, 0 skips`.

## Full Rails verification

Command:

```text
bin/rails test
```

Result: `11,440 runs, 73,144 assertions, 0 failures, 0 errors, 5 skips`.

The five skips were reported by the existing suite and were not introduced by this change.

## Remaining gate

The current `.git` mount is read-only, so the completed local schema reconstruction slice could
not be committed from this environment. No GitHub or remote write was attempted.

## Current execution attempt

On 2026-09-21, the same preflight was rerun from the current agent environment with the required
`.env.devcontainer.example` export. The credential key existed and the required PostgreSQL/Valkey
variable names were present without printing their values. The preflight did not complete:

```text
PG::ConnectionBad: could not translate host name "primary" to address: Temporary failure in name resolution
```

The focused OIDC transaction test was then attempted with `PARALLEL_WORKERS=1`. Rails stopped
during test-schema maintenance before any test ran, with the same PostgreSQL hostname error. This
is an environment failure in the current execution context, not a test pass. The earlier passing
results above remain historical evidence from the reachable container-service environment and do
not verify changes made after those runs.

## Latest agent-context check

The exact preflight was rerun from the current agent context after explicitly setting
`UMAXICA_ENV_FILE` and `POSTGRESQL_TEST_PREPARE_DATABASES`. After `LocalEnvironment.load!`, all
required variable names were present: `POSTGRESQL_TEST_HOST`, `POSTGRESQL_PORT`,
`POSTGRESQL_USER`, `POSTGRESQL_PASSWORD`, `POSTGRESQL_DATABASE`, `VALKEY_KVS_HOST`,
`VALKEY_KVS_PORT`, and `POSTGRESQL_TEST_PREPARE_DATABASES`. Values were not printed.

`config/credentials/test.key` was present and its contents were not read. `getent hosts primary`
and `getent hosts valkey-kvs` both reported unresolved names. The exact preflight failed before
Valkey checks could run:

```text
/home/global/workspace/vendor/bundle/ruby/4.0.0/gems/pg-1.6.3-x86_64-linux/lib/pg/connection.rb:944:in 'PG::Connection.connect_start': could not translate host name "primary" to address: Temporary failure in name resolution (PG::ConnectionBad)
    from /home/global/workspace/vendor/bundle/ruby/4.0.0/gems/pg-1.6.3-x86_64-linux/lib/pg/connection.rb:944:in 'PG::Connection.connect_to_hosts'
    from /home/global/workspace/vendor/bundle/ruby/4.0.0/gems/pg-1.6.3-x86_64-linux/lib/pg/connection.rb:871:in 'PG::Connection.new'
    from /home/global/workspace/vendor/bundle/ruby/4.0.0/gems/pg-1.6.3-x86_64-linux/lib/pg.rb:88:in 'PG.connect'
    from scripts/test-environment-check:29:in '<top (required)>'
    from -e:1:in 'Kernel#load'
    from -e:1:in '<main>'
```

The `pg.rb` path above was emitted by the installed gem during the check; no credentials were
printed. `podman`, `docker`, and `nerdctl` are unavailable in this agent context, so the agent
could not enter a sibling Compose service. No `/etc/hosts`, Compose, application setting, or
localhost substitution was used. No focused or full Rails test was run after this latest failed
preflight.

## Subsequent reachable-service verification

The exact preflight was subsequently rerun with the approved network access from the reachable
core-service test environment. It passed and confirmed PostgreSQL 17.7 and both Valkey databases
(`rate_limit` database 4 and `auth_state` database 6) with `PONG` responses. Required environment
names and the test credential key were checked without printing values or key contents.

Focused command after the targeted fixes:

```text
PARALLEL_WORKERS=1 bin/rails test \
  test/controllers/concerns/oidc/callback_test.rb \
  test/unit/views/page_title_presence_test.rb \
  test/services/oidc/token_exchange_service_test.rb \
  test/operations/oidc_connection_recorder_test.rb \
  test/models/auth_ceremony_session_test.rb \
  test/services/oidc_authorization_transaction_service_test.rb \
  test/models/concerns/oidc_authorization_transactionable_test.rb \
  test/controllers/auth/app/sign_ins_controller_test.rb \
  test/integration/authentication_flow_test.rb \
  test/integration/oidc_initiated_sign_in_completion_test.rb \
  test/unit/security/identity_authority_inversion_guard_test.rb
```

Result: `182 runs, 899 assertions, 0 failures, 0 errors, 0 skips`.

Full command:

```text
bin/rails test
```

Result: `11,468 runs, 73,279 assertions, 0 failures, 0 errors, 6 skips`.
The skips are existing suite skips; no test was deleted, added as a skip, mocked to bypass an
environment failure, or weakened for this verification.

The targeted fixes covered stale state-context assertions, the missing continuation page title,
surface-writer database-clock test setup, CSRF continuation calls on an already-authenticated
browser, OIDC result-reference collisions with handoff references, test Valkey reference-key
cleanup, route-contract expectations, and database-clock test time injection. No application
configuration, host mapping, shared service configuration, or production data was changed.
