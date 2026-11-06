# Earlier signup attempt entry guard

- Commit: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`; pre-existing uncommitted changes were present.
  This result includes the local locator and regression-test changes.
- Read-only development inspection found the earlier signup Flow still live, with a redeemed,
  unretired sign-up Binding and pending authorization parent. A newer sign-up Binding existed. No
  account, Flow, Binding or cookie was changed by the inspection.
- The earlier Flow deadline was `2026-11-02T05:10:00.838Z`. Latest request logs showed two 422
  submissions followed by a 400 `ownership_mismatch` after entering Email creation.
- `unreleased_attempt?` previously checked only the new Admission's Flows. It now also checks an
  earlier attempt identified by the browser's existing locator and matching nonce. It refuses new
  candidate creation through the existing contact-held response, without changing ownership or
  releasing the old attempt.
- Added a public-method regression case for a new Admission with a held earlier browser Flow,
  unchanged ownership and a nonmatching nonce.
- `bin/rails test test/services/sign_up_cycle_locator_test.rb`: blocked at initialization by
  `Umaxica::TestEnvironment::ConfigurationError`: missing `test_app_zenith_replica_db` and
  `test_chronicle_replica_db`; no tests executed and no database construction attempted.
- Ruby syntax checks and scoped `git diff --check`: passed. RuboCop initially found a new
  line-length offense (corrected), plus a pre-existing assertion-style warning in the unchanged
  cleanup test. The final service-only RuboCop run passed (1 file, no offenses). No browser replay
  was performed.
