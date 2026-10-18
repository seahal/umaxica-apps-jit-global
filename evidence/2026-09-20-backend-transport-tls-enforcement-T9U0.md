# Backend transport TLS enforcement evidence

- Date: 2026-09-20
- Scope: production Rails PostgreSQL/Valkey configuration guards
- Repository state: existing working-tree changes were preserved; no production or external service
  was contacted; no GitHub write was performed.

## Changes verified

- Production Valkey settings reject `redis://` for `CACHE_REDIS_URL`, `RATE_LIMIT_REDIS_URL`, and
  `AUTH_STATE_REDIS_URL`; development and test retain their existing local topology.
- Production PostgreSQL configuration rejects values other than `verify-full` for the writer and
  reader `NEON_*PGSSLMODE` variables during configuration evaluation.
- ADR, operations documentation, and the existing backend transport backlog now distinguish
  application-side guards from deployment/provider verification.

## TDD and verification

The new Valkey rejection test and the PostgreSQL configuration contract assertions were first run
before the implementation and failed because plaintext Valkey URLs were accepted and the strict
PostgreSQL contract was absent.

After implementation:

- `PARALLEL_WORKERS=1 bin/rails test test/lib/umaxica/valkey/settings_test.rb test/unit/database_password_config_test.rb test/lib/umaxica/valkey/responsibility_urls_test.rb`
  - 15 runs, 106 assertions, 0 failures, 0 errors, 0 skips.
- `bundle exec rubocop lib/umaxica/valkey/responsibility_urls.rb lib/umaxica/valkey/settings.rb test/lib/umaxica/valkey/settings_test.rb test/unit/database_password_config_test.rb`
  - The new test offense was fixed. The command still reports three pre-existing offenses: the
    existing non-ASCII comment in `responsibility_urls.rb` and the existing class-instance-variable
    warnings in `settings.rb`.
- `bin/rails test`
  - 11,405 runs, 72,988 assertions, 0 failures, 0 errors, 5 skips.
- `git diff --check` for the changed tracked paths passed.

## Unverified deployment checks

The current production values, provider certificate support, deployed CA material, and live
PostgreSQL/Valkey TLS handshakes were not inspected or exercised from this environment. They remain
deployment verification items and are not claimed as complete here. No secrets, connection URLs,
certificates, or private keys were recorded.
