# Current runtime revalidation

- Date: 2026-09-22 UTC
- HEAD: `277673d13547d722fc88f830711eee69b923a7e8`
- Worktree: clean before verification; only this evidence record and its plan reference were added afterward
- Scope: Compose-backed Rails preflight, RetentionPurgeJob and three-surface Base Dashboard focused tests, and the full Rails suite
- External writes: none; no GitHub, AWS, Cloudflare, provider, production, shared database, email, or SMS service was contacted

## Environment preflight

The repository's explicit `.env.devcontainer.example` was selected through
`UMAXICA_ENV_FILE`. The required test variables and `config/credentials/test.key` were checked
without printing secret values. `primary` and `valkey-kvs` resolved through the Compose network.

The requested preflight completed successfully:

```text
PostgreSQL test target: 10.89.0.3/32:5432 admin=db version=17.7 (Debian 17.7-3.pgdg12+1) test_databases=646
Valkey rate_limit: valkey-kvs:6379 db=4 ping=PONG version=7.2.4
Valkey auth_state: valkey-kvs:6379 db=6 ping=PONG version=7.2.4
```

## Focused verification

The RetentionPurgeJob, Retainable, hold, cross-database cleanup, anonymizer, and Base app/com/org
Dashboard public-props tests were run with `PARALLEL_WORKERS=1` and the isolated test database
preparation list. Result:

```text
61 runs, 440 assertions, 0 failures, 0 errors, 0 skips
```

## Full Rails verification

The full suite was run after the focused suite with the isolated primary, ticket, queue, and
occurrence test databases:

```text
11503 runs, 73304 assertions, 0 failures, 0 errors, 5 skips
```

The five skips were reported by the existing suite. No test, assertion, skip, coverage threshold,
application code, configuration, or security control was changed to obtain this result. Expected
OmniAuth failure diagnostics and Rails deprecation warnings appeared during tests that exercise
those failure paths; they did not produce failures.

## Additional quality checks

- `bun run test`: 85 test files passed; 1,065 tests passed.
- `bun run check`: formatting, lint, TypeScript, dead-code, OpenAPI lint, and OpenAPI bundle
  verification passed. Knip reported four existing configuration hints and no failure.
- `bin/rubocop`: 4,754 files inspected, no offenses.
- `bin/rails zeitwerk:check` with the explicit test environment: `All is good!`.
- `bin/jobs check` with the explicit test environment: `Solid Queue configuration is valid.`.
- Brakeman 8.0.6 local scan without its wrapper's update-metadata check: 0 errors and 0 security
  warnings. The repository `bin/brakeman` wrapper itself could not complete its forced update
  metadata check because the installed tool returned `nil.date`; no network fallback was used.
- `git diff --check`: passed.

Coverage was intentionally not run or used as a gate for this revalidation.

## Retention disposition

The current RetentionPurgeJob remains `ACCEPTED_AS_EXISTING_IMPLEMENTATION`. Its safety contract is
the explicit model allowlist, finite batch processing, writer-database clock, hold and enforcement
checks, and operational kill switch. No dry-run, preview, simulation API, or dry-run-only schema,
service, command, or audit event was added. Notification delivery, receipt, retry, and permanent
failure remain independent contracts.
