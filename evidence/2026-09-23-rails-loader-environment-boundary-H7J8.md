# Rails loader environment boundary evidence

Date: 2026-09-23
Repository: `seahal/umaxica-apps-jit-global`
HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
Worktree: already contained unrelated and in-progress uncommitted changes; no existing change was reset or discarded.

## Scope

This record covers a Rails loader check and the environment boundary encountered while attempting
the CF-011 database-backed regression tests. It does not claim PostgreSQL or Valkey acceptance.

## Observations

With the repository's explicit environment file, the first loader check failed before reaching the
application's database-backed verification because the vendored `debug` gem attempted to bind its
UNIX socket:

```text
Operation not permitted - bind(2) for /home/global/workspace/tmp/rdbg-1000/rdbg-2 (Errno::EPERM)
Bundler::GemRequireError: There was an error while trying to load the gem 'hotwire-spark'.
```

Repository inspection showed that `.env.devcontainer.example` contains `RUBY_DEBUG_OPEN=false`.
The installed `debug` 1.11.1 configuration treats `RUBY_DEBUG_OPEN` as an untyped value, so the
non-empty string `"false"` is truthy and requests the UNIX debug socket. This diagnosis is based on
the vendored gem source and does not require changing repository configuration.

The loader check was then rerun with a process-local `RUBY_DEBUG_ENABLE=0` override:

```text
RUBY_DEBUG_ENABLE=0 \
UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example \
RAILS_ENV=test bundle exec bin/rails zeitwerk:check
```

Result:

```text
Hold on, I am eager loading the application.
All is good!
```

No application source, test, configuration, environment file, database, Valkey service, or
external service was changed.

## Database-backed test boundary

The focused CF-011 test was attempted with the same explicit environment and a single worker:

```text
RUBY_DEBUG_ENABLE=0 \
UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example \
POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db \
PARALLEL_WORKERS=1 bundle exec bin/rails test \
  test/models/processor_erasure_notification_state_test.rb
```

It failed before test execution because this process cannot resolve the configured PostgreSQL
service:

```text
ActiveRecord::DatabaseConnectionError: There is an issue connecting with your hostname: primary.
PG::ConnectionBad: could not translate host name "primary" to address: Temporary failure in name resolution
```

`getent hosts primary` and `getent hosts valkey-kvs` produced no records in this process. The
database-backed CF-011 regression tests therefore remain `UNVERIFIED` here. The required next
step is to rerun the same focused test in the Compose core service network, followed by the full
Rails suite; no localhost fallback, test weakening, skip, mock, or service reconfiguration is
permitted.

The exact repository preflight was also rerun with the debugger disabled only for that process:

```text
RUBY_DEBUG_ENABLE=0 \
UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example \
POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db \
bundle exec ruby -r ./lib/local_environment -e 'LocalEnvironment.load!; load "scripts/test-environment-check"'
```

It still failed at the configured PostgreSQL hostname before Valkey verification:

```text
PG::ConnectionBad: could not translate host name "primary" to address: Temporary failure in name resolution
```

The test Solid Queue configuration validator does not require a live database and passed:

```text
RUBY_DEBUG_ENABLE=0 UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example \
RAILS_ENV=test bundle exec bin/jobs check
# Solid Queue configuration is valid.
```

The corresponding development check reached the configured recurring-task model loading and then
failed while connecting to PostgreSQL at `primary`; it is therefore not evidence of an invalid
queue configuration, worker execution, or production topology. No fallback host was supplied.

## Boot-dependency classification

The hostname lookup is `ENVIRONMENT_UNAVAILABLE`, not a confirmed configuration bug.

Evidence:

- `config/environments/test.rb` intentionally selects an in-process `MemoryStore` for
  `Rails.cache`.
- The same file intentionally constructs a namespaced Redis/Valkey rate-limit store from
  `Umaxica::Valkey::Settings.current.rate_limit.url`.
- `config/valkey.yml` maps test `rate_limit` to logical DB 4 and test `auth_state` to logical DB 6,
  both using `VALKEY_KVS_HOST` / `VALKEY_KVS_PORT`.
- `test/test_helper.rb` installs `ValkeyTestIsolation`, cleans rate-limit and auth-state keys for
  every test, and therefore requires the live KVS service even though application cache is memory-
  backed.
- `config/database.yml` requires `POSTGRESQL_TEST_HOST` for the test primary connection, and the
  Rails preflight reaches the configured `primary` hostname rather than a repository-generated
  fallback.

Removing the KVS initialization would change the existing test isolation and auth-state contract;
changing either hostname to loopback would point tests at an unverified service and could target the
wrong database. The minimum safe local action is therefore to run inside the Compose core service
network with the declared PostgreSQL and Valkey services available. No repository configuration or
application code was changed to hide the missing services.
