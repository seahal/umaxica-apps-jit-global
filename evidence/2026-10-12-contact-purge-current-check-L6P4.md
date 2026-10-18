# Contact purge and dead-history current check

Date: 2026-10-12

This check followed nine.md Section 14.2 after the current P11b recheck. The worktree was already
dirty at HEAD `ccceabd05d2e3a8f923ce398046f99d026a5b78e`; unrelated staged, unstaged and untracked
changes were preserved. The Rails command used the run-owned disposable PostgreSQL manifest
`tmp/acceptance-isolated-20261010p8b-primary.json`, host `primary`, and four workers. No CI,
Podman, production service, external provider or shared/production database was used.

The selected public-boundary collection covered the six realm/channel dead-history models,
schema/visibility invariants, protected and held purge refusal, repeated salted history, physical
reuse, duplicate-purge behavior, independent-connection purge/reuse races, OTP failure retention,
realm/channel HMAC rotation and maintenance isolation, and realm encryption rotation.

Command:

```text
POSTGRESQL_TEST_PREPARE_DATABASES=<manifest databases> POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p8b POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p8b-primary.json POSTGRESQL_TEST_HOST=primary POSTGRESQL_DATABASE=postgres RAILS_ENV=test PARALLEL_WORKERS=4 bundle exec rails test test/models/dead_identifier_history_contract_test.rb test/models/dead_identifier_destroy_test.rb test/operations/dead_identifier_purge_test.rb test/operations/dead_identifier_purge_concurrency_test.rb test/security/invariants/dead_identifier_history_visibility_invariant_test.rb test/jobs/dead_identifier_retention_test.rb test/models/otp_failure_retention_test.rb test/services/realm_identifier_hmac_rotation_test.rb test/services/identifier_hmac_maintenance_boundary_test.rb test/integration/identifier_encryption_rotation_drill_test.rb
```

Result: `109 runs, 1046 assertions, 0 failures, 0 errors, 0 skips`.

This is current focused evidence, not a claim that every CONTACT-4/5 public ceremony route or
every cross-database failure campaign is complete. In particular, source/fixture inventories and
remaining ceremony proof/legacy-retirement gaps in CONTACT-4/5 remain separately reviewable. No
production data was purged and no dead-history lookup authority was added.
