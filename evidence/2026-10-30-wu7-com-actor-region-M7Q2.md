# WU-7 com actor region on read

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree contained uncommitted changes affecting this result.
- Base com reads region from the active, unexpired preference associated with a verified JWT, without requiring a browser binding. Explicit URL region remains the request overlay. Warp com does not use this Base database read.
- A public journey saved the US region and then requested the Base root without a region. Before the change it redirected to the default JP region; after the change it redirects to US and the rendered actor reports US. A request explicitly supplying JP reports JP. The two GETs in the first journey issued no INSERT, UPDATE, or DELETE SQL.
- `bin/rails test test/integration/anonymous_com_preference_write_journey_test.rb test/integration/anonymous_com_retired_consent_test.rb test/controllers/base/com test/controllers/warp/com/roots_controller_test.rb test/unit/actor/preference_test.rb`: 83 runs, 520 assertions, 0 failures, 0 errors, 0 skips.
- RuboCop autocorrection completed without remaining offenses on the controller and journey test. This slice does not establish Web Push actor hydration, realm-separated keys, lifecycle/schema completion, or full-suite status. No migration was performed.
