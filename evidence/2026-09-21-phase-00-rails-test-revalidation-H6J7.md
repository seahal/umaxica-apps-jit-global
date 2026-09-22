# Phase 00 Rails test revalidation

- Date: 2026-09-21 UTC
- Working directory: `/home/global/workspace`
- Code/config/test changes during this verification: none
- External writes: none
- Secrets: `config/credentials/test.key` was checked for presence only; its contents were not read or recorded.

## Preflight

The requested environment was selected explicitly with `UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example` and the requested `POSTGRESQL_TEST_PREPARE_DATABASES` value.

The required environment names were present without printing their values:

- `POSTGRESQL_TEST_HOST`
- `POSTGRESQL_PORT`
- `POSTGRESQL_USER`
- `POSTGRESQL_PASSWORD`
- `POSTGRESQL_DATABASE`
- `VALKEY_KVS_HOST`
- `VALKEY_KVS_PORT`
- `POSTGRESQL_TEST_PREPARE_DATABASES`

Command:

```text
bundle exec ruby -r ./lib/local_environment -e 'LocalEnvironment.load!; load "scripts/test-environment-check"'
```

Result: PASS. PostgreSQL 17.7 was reachable at the configured test target. Valkey 7.2.4 responded with `PONG` on the configured `rate_limit` and `auth_state` databases. `primary` and `valkey-kvs` resolved in the current execution context.

## Focused test

Command:

```text
PARALLEL_WORKERS=1 bin/rails test test/controllers/auth/token_csrf_test.rb
```

Result: `1 runs, 3 assertions, 0 failures, 0 errors, 0 skips`.

## Full suite

Command:

```text
bin/rails test
```

Result: `11473 runs, 73294 assertions, 0 failures, 0 errors, 6 skips`.

The suite emitted expected authentication-provider diagnostics and existing warnings during tests; they did not produce test failures. No skip, assertion, mock, or production behavior was changed to obtain this result.

## Latest Compose-backed revalidation

- Date: 2026-09-21 UTC
- HEAD: `ab4746f9d403021b3ea5fff53a0a6ae4b4e68ec9`
- Worktree: uncommitted changes were present and preserved; no reset, clean, commit, or external write was performed.
- Coverage: not run; this verification intentionally did not add a coverage-only gate.

The exact preflight was rerun after explicitly selecting `.env.devcontainer.example`. The
credential key remained present, and all required environment variable names were present after
`LocalEnvironment.load!`; values and key contents were not printed. `getent hosts primary` and
`getent hosts valkey-kvs` both resolved. PostgreSQL 17.7 was reachable, and Valkey 7.2.4 returned
`PONG` for the configured `rate_limit` and `auth_state` databases.

Focused command:

```text
PARALLEL_WORKERS=1 bin/rails test test/controllers/concerns/oidc/callback_test.rb
```

Result: `20 runs, 102 assertions, 0 failures, 0 errors, 0 skips`.

Full command:

```text
bin/rails test
```

Result: `11486 runs, 73378 assertions, 0 failures, 0 errors, 6 skips`.

The six skips were reported by the existing suite. No test, application code, configuration,
CSRF control, mock boundary, or external service configuration was changed to obtain this result.
