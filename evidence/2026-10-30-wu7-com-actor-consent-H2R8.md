# WU-7 com actor consent on read

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree contained uncommitted changes affecting this result.
- Base com GET/HEAD now installs consent into the actor snapshot only after a verified JWT, active and unexpired preference, and matching browser binding. Missing or mismatched binding and retired rows retain the no-consent snapshot. Warp does not perform this database read.
- The matching-binding actor assertion failed before the change. Afterward, `bin/rails test test/integration/anonymous_com_retired_consent_test.rb test/integration/anonymous_com_preference_write_journey_test.rb test/controllers/warp/com/roots_controller_test.rb test/security/invariants/actor_context_invariant_test.rb` passed: 58 runs, 366 assertions, 0 failures, 0 errors, 0 skips. The integration test observes actor consent during actual template rendering for matching, mismatching, and retired cases.
- RuboCop found no offenses in the three changed Ruby files. No migration or full-suite run was performed. Actor region and Web Push hydration, realm-specific keys and the WU-7 lifecycle schema remain incomplete.
