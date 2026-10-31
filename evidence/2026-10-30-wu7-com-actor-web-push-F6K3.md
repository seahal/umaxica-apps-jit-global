# WU-7 com actor Web Push on read

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree contained uncommitted changes affecting this result.
- The actor preference now carries an explicit enabled/disabled Web Push value. On Base com GET/HEAD, a verified JWT, active unexpired row and matching browser binding are required to read it. A missing consent child does not prevent a bound Web Push value from being read or cause a child to be created. Warp retains the disabled value.
- The new rendered-actor assertion initially errored because the value was absent. The final tests exercise matching, missing and mismatched binding, a retired row, and preservation across actor cookie replacement.
- `bin/rails test test/integration/anonymous_com_web_push_api_test.rb test/integration/anonymous_com_retired_consent_test.rb test/controllers/warp/com/roots_controller_test.rb test/unit/actor/preference_test.rb test/security/invariants/actor_context_invariant_test.rb`: 56 runs, 331 assertions, 0 failures, 0 errors, 0 skips.
- RuboCop reported no offenses in the seven changed Ruby files. No full suite or migration was run. Realm-specific keys and the WU-7 lifecycle schema remain incomplete.
