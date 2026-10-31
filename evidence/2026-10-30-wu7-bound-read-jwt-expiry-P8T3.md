# WU-7 browser-bound read JWT expiry

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree contained uncommitted changes affecting this result.
- A signed JWT was valid according to the application clock while the simulated database decision clock reached its expiry. Before this change the Web Push endpoint returned enabled at the equality boundary. Consent and Web Push reads now also compare the verified JWT expiry with the database decision time while checking the active preference.
- The integration test holds the parent row valid beyond JWT expiry and checks one second before, exactly at, and one second after expiry for both endpoints. `bin/rails test test/integration/anonymous_com_web_push_api_test.rb test/integration/anonymous_com_retired_consent_test.rb test/integration/anonymous_com_preference_write_journey_test.rb`: 54 runs, 428 assertions, 0 failures, 0 errors, 0 skips.
- RuboCop found no offenses in the two implementation files and changed test. This does not establish realm-specific keys, the lifecycle schema, or WU-7 completion. No migration or full-suite run was performed.
