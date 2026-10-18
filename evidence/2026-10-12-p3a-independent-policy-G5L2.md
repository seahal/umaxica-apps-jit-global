# P3a independent Email and Telephone policy check

Date: 2026-10-12

Repository: `/home/global/workspace`

Branch: `feature`

Code HEAD: `ccceabd05d2e3a8f923ce398046f99d026a5b78e`

The worktree was already dirty and was preserved. No reset, clean, stash, worktree, push,
production operation or shared database operation was used. The focused test used the run-owned
manifest `tmp/acceptance-isolated-20261010p8b-primary.json`, primary PostgreSQL and four workers.

Command:

```text
POSTGRESQL_TEST_PREPARE_DATABASES="<the 20 names from tmp/acceptance-isolated-20261010p8b-primary.json>" \
POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p8b \
POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p8b-primary.json \
POSTGRESQL_TEST_HOST=primary POSTGRESQL_DATABASE=postgres RAILS_ENV=test PARALLEL_WORKERS=4 \
bundle exec rails test test/models/otp_failure_retention_test.rb
```

Observed result: `33 runs, 458 assertions, 0 failures, 0 errors, 0 skips` in 2.706 seconds.
The test covers Client/Visitor/Operator Email and Telephone rows, zero/one/MAX−1/MAX/MAX+1
failure boundaries, issuance and resend retention, expired/cancelled proof retention, explicit
successful-consumption reset, explicit Telephone issuance timestamps, retired identifier-proof
schema/method absence and the absence of the superseded shared stateful policy. A read-only
PostgreSQL follow-up reported zero run-owned worker databases and zero active sessions.

This supports the P3a policy subcondition for the current dirty worktree. It does not close the
separate full ceremony-purpose/realm/concurrency matrix or the remaining P3d schema/fixture/
constraint inventory.
