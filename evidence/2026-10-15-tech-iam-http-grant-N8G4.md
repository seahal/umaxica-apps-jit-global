# Tech IAM HTTP grant and audit

Recorded 2026-10-15 UTC against commit `7d4e2d941f4eb576eb77076c2c2a4e54badfa847`, with uncommitted
tests and documentation present.

Applied the existing authenticated IAM grant success case to tech.access instead of the previous
support capability representative. The real Base IAM POST retains its existing explicit Step-Up
facts and browser credential setup; it delegates to another Operator and verifies the persisted
granter, recipient capability and Chronicle succeeded result tied to the operation UUID and grant
public ID. Existing refusal, self-grant and bootstrap-only IAM cases remain unchanged. No production
authorization or audit implementation was changed.

Executed
`env -u POSTGRESQL_ISOLATED_TEST_RUN_ID RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/controllers/base/org/iam/grants_controller_test.rb`:
8 runs, 48 assertions, 0 failures, 0 errors, 0 skips. Targeted RuboCop inspected one file without
offenses; scoped diff check passed. Only standard Rails test databases were used. This is local
HTTP/audit acceptance, not a production grant or a real-browser Step-Up ceremony.
