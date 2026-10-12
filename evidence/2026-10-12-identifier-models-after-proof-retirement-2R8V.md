# Identifier model verification after proof retirement cleanup

- Revision: `a1ec83a7384a424c97671356268ec5c4ad8347d4` plus the local model cleanup in this worktree.
- Test environment: run-owned disposable PostgreSQL fleet `20261010p3d2`, Rails test environment, four workers.
- Focused command:

```text
RAILS_ENV=test PARALLEL_WORKERS=4 POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p3d2 POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p3d2-primary.json POSTGRESQL_TEST_PREPARE_DATABASES=<20 manifest databases> bundle exec rails test test/models/otp_failure_retention_test.rb test/models/live_identifier_creation_concurrency_test.rb test/controllers/auth/app/in/emails_controller_test.rb test/controllers/auth/com/up/emails_controller_test.rb test/controllers/base/org/identity/emails/registrations_controller_test.rb
```

- Result: `124 runs, 1433 assertions, 0 failures, 0 errors, 0 skips`.
- Change verified: the six live identifier models no longer declare ignored columns for retired identifier-owned OTP proof fields; ceremony transactions remain the proof owner.
- Limitation: this does not complete sign-up signed binding strengthening, staff audit-event primary-key normalization, Avatar cutover, or the remaining full acceptance gates.
