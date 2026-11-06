# WU-A3 App test database rebuild and Switch boundary tests

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`.
- The worktree had uncommitted changes across 278 paths before this evidence file was added. No
  commit was created.
- Before rebuilding, `test/services/admission_binding_deadline_intent_test.rb` stopped during
  fixture setup with 9 errors, 0 assertions. The repeated error was a foreign-key violation for
  `enterprise_units.enterprise_id = 519260509` in `test_app_zenith_db`.
- Before rebuilding, a read-only query found 8 `enterprise_units` rows, no orphan `enterprise_id`
  references, and the fixture enterprise ID present. This did not explain the fixture insertion
  failure.
- Took a custom-format `pg_dump` snapshot of only `test_app_zenith_db` at
  `/tmp/test-app-zenith-before-wua3-rebuild-20261101T053252Z.dump` (556,425 bytes; SHA-256
  `34641b11244f140b08d2c8881ed812cdb030f06bab4676c7feae6380fe17b26e`). Recovery command:
  `pg_restore --clean --if-exists --no-owner --no-acl --dbname=test_app_zenith_db /tmp/test-app-zenith-before-wua3-rebuild-20261101T053252Z.dump`.
- Ran `RAILS_ENV=test bin/rails db:migrate:reset:app_zenith`. Rails reported dropping and recreating
  `test_app_zenith_db`; the task completed successfully by applying the current migrations. This
  operation did not target any other database. No production or Neon database was accessed.
- The first focused run after rebuilding exposed stale test calls that omitted the now-required
  `source_auth_session` argument, an outdated expected Switch handoff tuple, and a query assertion
  that included the separate source-row lock. Updated
  `test/services/admission_binding_deadline_intent_test.rb` to use the current Switch contract,
  exercise refusal while a distinct earlier ceremony remains live, and count the single batched read
  of earlier ceremonies.
- Final focused run with local Preference JWT settings, an explicit Valkey run ID, and one worker:
  `bin/rails test test/services/admission_binding_deadline_intent_test.rb` — 9 runs, 77 assertions,
  0 failures, 0 errors, 0 skips.
- `ruby -c`, `git diff --check`, and targeted RuboCop for the changed test passed.
- The full-suite result in `evidence/2026-11-01-wu9-final-suite-baseline-Q4M8.md` predates this
  database rebuild and test correction. The full suite was not run again; the WU-A3 focused check
  does not close the full two.md work.
