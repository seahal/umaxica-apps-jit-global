# WU-7 Base com API actor state

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree contained uncommitted changes affecting this result.
- Base com preference API controllers skip the general preference transport callback. Their GET/HEAD requests now load the verified JWT before actor display and browser-bound state hydration. The new public API test initially observed disabled actor Web Push despite a successful bound read, and afterward observed enabled state during the endpoint's database read.
- `bin/rails test test/integration/anonymous_com_web_push_api_test.rb test/integration/anonymous_com_preference_write_journey_test.rb test/integration/anonymous_com_retired_consent_test.rb test/controllers/warp/com/roots_controller_test.rb test/security/invariants/actor_context_invariant_test.rb`: 72 runs, 497 assertions, 0 failures, 0 errors, 0 skips.
- RuboCop autocorrection completed without remaining offenses in the changed test; the concern passed the same check. No full suite or migration was run. Realm-separated keys, lifecycle/schema completion and unsafe-request actor hydration remain unverified or incomplete.
