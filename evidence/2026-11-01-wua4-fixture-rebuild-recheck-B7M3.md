# WU-A4 local App Zenith fixture rebuild and recheck

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`.
- The worktree contained pre-existing uncommitted changes; they were preserved. No commit was
  created. This evidence records local test-database work only.
- Before rebuilding, the local `test_app_zenith_db` contained the orphaned
  `client_authority_locks.client_id=980190963` row that blocked fixture restoration. A custom
  PostgreSQL dump was saved before the rebuild:
  `/tmp/test-app-zenith-before-wua4-fixture-rebuild-20261101.dump` (564,003 bytes; SHA-256
  `ae993584805f98c1308f7c080dd98169131b7337471d91074d3f1b1485bf27d2`; `pg_restore --list`
  succeeded). Recovery command:
  `pg_restore --clean --if-exists --no-owner --no-acl --dbname=test_app_zenith_db /tmp/test-app-zenith-before-wua4-fixture-rebuild-20261101.dump`.
- Ran `RAILS_ENV=test bin/rails db:migrate:reset:app_zenith` with the local container environment
  file. The command targeted `test_app_zenith_db`; no production or Neon database was accessed.
- The reset temporarily left `db/app_zenith_structure.sql` as a 448-byte header-only dump. The
  pre-reset working file was restored from
  `/tmp/app-zenith-structure-before-wua4-fixture-rebuild-20261101.sql`, then
  `RAILS_ENV=test bin/rails db:schema:dump:app_zenith` completed successfully. The resulting file is
  333,636 bytes with SHA-256 `a710695c8d6a9596aebf24aec700191c4f312a8a8d9a1557895962c73376d054`,
  identical to the pre-reset working file. No other structure dump was changed by this operation.
- Read-only post-reset counts were: Clients 0, authority locks 0, persona ownerships 0 and
  enterprise ownerships 0. The orphan lock row was absent.
- Before the rebuild, the selected RP local-session group stopped during fixture setup: 27 runs, 11
  assertions, 0 failures and 26 errors, all from the foreign-key violation. After rebuilding,
  `bin/rails test test/integration/rp_cell_local_session_readiness_test.rb test/integration/rp_refresh_recovery_test.rb test/integration/sign_app_oidc_browser_flow_test.rb`
  passed: 27 runs, 339 assertions, no failures, errors or skips.
- The selected signup-delivery group passed: 12 runs, 233 assertions, no failures, errors or skips.
  The Base Dashboard Passkey journey test passed: 1 run, 45 assertions, no failures, errors or
  skips. The journey now follows the current Visa result GET plus same-origin POST continuation.
- These focused results do not close WU-A4 or establish full-suite status. No full suite was run in
  this slice.
