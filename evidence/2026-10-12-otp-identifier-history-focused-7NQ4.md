# Focused OTP and identifier verification

- Revision: `a1ec83a7384a424c97671356268ec5c4ad8347d4`
- Worktree: pre-existing staged, unstaged, and untracked changes were preserved; this check ran without resetting or cleaning them.
- Environment: run-owned disposable PostgreSQL fleet `20261010p3d2`, Rails test environment, four workers.
- Command:

```text
RAILS_ENV=test PARALLEL_WORKERS=4 POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p3d2 POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p3d2-primary.json POSTGRESQL_TEST_PREPARE_DATABASES=<20 manifest databases> bundle exec rails test test/models/otp_failure_retention_test.rb test/models/ceremony_otp_operation_isolation_test.rb test/models/ceremony_owned_otp_concurrency_test.rb test/models/live_identifier_creation_concurrency_test.rb test/lib/realm_identifier_digest_test.rb test/lib/identifier_history_fingerprint_verifier_test.rb test/security/invariants/dead_identifier_history_visibility_invariant_test.rb
```

- Result: `103 runs, 1103 assertions, 0 failures, 0 errors, 0 skips`.
- Scope: OTP failure retention and ceremony isolation, concurrent ceremony verification, live identifier create concurrency, realm HMAC separation, history fingerprint verification, and history visibility.
- Limitation: this is focused evidence only. It does not prove completion of the full nine.md implementation, legacy schema retirement for every database, independent committed-transaction coverage for every isolation level, Avatar cutover, or the remaining identifier and authentication shape work.
