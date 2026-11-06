# WU-9 full-suite baseline comparison

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`.
- The worktree had uncommitted changes across 276 paths before this evidence file was added. No
  commit was created.
- Ran the WU-9 closure suite once with `PREFERENCE_COM_JWT_ISSUER=https://www.umaxica.com`,
  `PREFERENCE_COM_JWT_AUDIENCE=com`, `PREFERENCE_COM_JWT_REVOKED_KIDS=`,
  `VALKEY_NAMESPACE_RUN_ID=codex-wu9-full-20261101`, and `PARALLEL_WORKERS=1` using
  `bin/rails test`.
- Result: 16,659 runs, 115,227 assertions, 154 failures, 4,883 errors, 0 skips; exit status 1. The
  full output was kept outside the repository at `/tmp/wu9-final-full-suite-2026-11-01.log`.
- Compared unique failure/error identifiers with `plans/2026-10-28-baseline-failing-tests.md` after
  removing output line locations. The baseline contains 981 unique identifiers; 330 identifiers
  appeared in both sets and 4,707 current identifiers were absent from the baseline.
- The largest repeated error is fixture setup raising `PG::ForeignKeyViolation` because
  `enterprise_units.enterprise_id = 519260509` is absent from `enterprises` (4,204 error sections).
  The stack is in `ActiveRecord::FixtureSet.insert`. Earlier evidence recorded the same fixture
  failure in `test_app_zenith_db`; this run did not establish its originating change or WU.
- Re-ran `test/services/admission_binding_deadline_intent_test.rb` with local Preference JWT
  settings, a Valkey run ID, and one worker: 9 runs, 0 assertions, 0 failures, 9 errors. Fixture
  loading failed before the tests reached their assertions with the same `enterprise_units`
  foreign-key violation, so the WU-A3 Switch boundary cases remain unverified in this run.
- A read-only query using `EnterpriseUnit.connection_pool.with_connection` identified the database
  as `test_app_zenith_db`, with 8 enterprise-unit rows, 0 rows lacking a matching enterprise, and
  the fixture enterprise `id = 519260509` present after the failed run. This did not identify why
  fixture insertion fails. An initial diagnostic using deprecated `ActiveRecord::Base.connection`
  was rejected by the repository deprecation policy; the query was repeated through the connection
  pool.
- Other repeated errors include `VALKEY_NAMESPACE_RUN_ID` missing in
  `ValkeyTestIsolation.cleanup_worker_keys!` (231 sections) and `Rails.cache.clear` called on nil
  (293 sections). The run supplied `VALKEY_NAMESPACE_RUN_ID`; the cause of its absence during
  cleanup was not established.
- The full-suite failures and errors are not fully attributed. No repairs to test databases or
  unrelated WUs were made during this verification.
- WU-9 remains incomplete: this result does not establish the full AC matrix, and 4,707 current
  failure/error identifiers are outside the recorded baseline. The later implementation and targeted
  continuation checks are recorded in `evidence/2026-11-01-wu9-visa-post-continuation-Q7M2.md`; this
  full run does not replace the still-missing complete three-realm AC matrix.
- This full-suite result predates the later local `test_app_zenith_db` rebuild and WU-A3 test
  correction recorded in `evidence/2026-11-01-wua3-app-zenith-rebuild-and-switch-tests-M9C4.md`. No
  full suite was rerun after those changes.
