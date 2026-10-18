# Database consistency dependency retirement

Date: 2026-09-20

## Completed scope

The runtime and CI dependency on `database_consistency` was removed from the Gemfile, lockfile,
CI task comments, and the current test-tooling documentation. Historical ADRs and completed
reference/evidence documents that describe past use were retained as historical records.

No database configuration, ownership boundary, migration path, schema dump, or external service
was changed by this slice.

## Verification

```text
bundle install --local
Bundle complete! 122 Gemfile dependencies, 365 gems now installed.

bundle check
The Gemfile's dependencies are satisfied

PARALLEL_WORKERS=1 bin/rails test \
  test/models/client_totp_credential_test.rb \
  test/consumers/totp_window_consumer_test.rb
27 runs, 68 assertions, 0 failures, 0 errors, 0 skips

rg -n -i "database_consistency|database consistency" Gemfile Gemfile.lock config/ci.rb docs/test.md
no current execution dependency found
```

The broader Phase 09 schema reconstruction, populated structure dumps, and replacement PostgreSQL
regression inventory remain separate and are not claimed as completed by this record.
