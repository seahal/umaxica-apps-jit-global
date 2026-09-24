# Test boot dependency classification

Date: 2026-09-23
Repository: `seahal/umaxica-apps-jit-global`
HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
Worktree: already contained unrelated and in-progress uncommitted changes; no existing change was reset or discarded.

## Question

Classify the configured `primary` and `valkey-kvs` dependencies as either a repository
configuration defect or an unavailable execution environment. No application, test,
configuration, service, database, or external provider was changed for this check.

## Repository evidence

- `config/database.yml` uses `POSTGRESQL_TEST_HOST` for every test database, including the
  `primary` connection. It does not substitute a development host or loopback address.
- `config/valkey.yml` defines test `cache` as an in-process memory store with reserved logical DB 2.
- `config/environments/test.rb` nevertheless constructs the configured Redis/Valkey-backed store
  for rate limiting and obtains the Auth-state configuration during application boot.
- `test/test_helper.rb` installs the Valkey test isolation support, which cleans rate-limit and
  Auth-state namespaces in the configured KVS service for each test run.
- Therefore `VALKEY_KVS_HOST` is not an accidental application-cache dependency. Removing it,
  replacing it with loopback, or silently falling back would change the existing rate-limit and
  Auth-state test contract.

## Checks performed

With the Valkey and PostgreSQL variables deliberately absent, the repository preflight stopped
before application checks and reported only missing required variable names; no secret values were
printed.

With the explicit local Compose environment file selected, the required preflight succeeded:

```text
PostgreSQL test target: 10.89.0.3/32:5432 admin=db version=17.7 test_databases=646
Valkey rate_limit: valkey-kvs:6379 db=4 ping=PONG version=7.2.4
Valkey auth_state: valkey-kvs:6379 db=6 ping=PONG version=7.2.4
```

Resolver checks in the same Compose-backed process returned addresses for both `primary` and
`valkey-kvs`. `config/credentials/test.key` was confirmed present without reading its contents.

## Decision

**`ENVIRONMENT_UNAVAILABLE` outside the Compose core-service network.**

This is not a confirmed repository configuration bug. The minimum safe execution action is to run
the declared preflight and Rails tests inside the local Compose network with the configured
PostgreSQL and Valkey services available. No localhost fallback, `/etc/hosts` edit, DNS workaround,
fake service, silent rescue, or test weakening is permitted.
