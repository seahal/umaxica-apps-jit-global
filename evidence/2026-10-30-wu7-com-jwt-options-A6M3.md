# WU-7 com JWT display option validation

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; prior and current uncommitted worktree
  changes were present.
- Com JWT encoding and decoding now accept only the named wire values for each display option;
  verification does not query the setting database. A test checks the allowlist against every
  nonempty fixed option model name to detect drift.
- `bin/rails test test/values/anonymous_com_preference_token_shape_test.rb test/integration/anonymous_com_preference_write_journey_test.rb test/integration/preference_browser_api_contract_test.rb`:
  60 runs, 2,804 assertions, 0 failures, 0 errors, 0 skips. After adding the complete option-name
  round-trip test, the focused codec suite ran 10 tests, 140 assertions, 0 failures or errors.
- RuboCop on the codec and its test passed after formatting corrections.
- Realm key separation, the 3 KiB limit, and the other WU-7 acceptance criteria remain incomplete
  or unverified.
