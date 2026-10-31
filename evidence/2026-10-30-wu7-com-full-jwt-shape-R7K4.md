# WU-7 com complete JWT display shape

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes, including the implementation and tests checked here.
- Com anonymous JWT issuance and verification require the complete nine-field display snapshot. Tests exercise each missing field and an empty snapshot, and a signed incomplete snapshot submitted to the write endpoint creates a new preference without changing the original consent value.
- `bin/rails test test/values/anonymous_com_preference_token_shape_test.rb test/controllers/warp/com/roots_controller_test.rb test/integration/anonymous_com_preference_response_binding_test.rb test/integration/anonymous_com_retired_consent_test.rb test/integration/anonymous_com_web_push_initialization_test.rb test/integration/anonymous_com_web_push_api_test.rb test/integration/anonymous_com_preference_write_journey_test.rb`: 112 runs, 1022 assertions, 0 failures, 0 errors, 0 skips.
- This check does not establish WU-7 completion or cover the full suite.
