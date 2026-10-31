# WU-7 stale JWT display

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; verification included previous and current
  uncommitted worktree changes.
- A com GET or HEAD may use a still-valid signed display payload even if the active row's current
  jti has advanced. Write paths retain their current-jti check.
- `bin/rails test test/integration/anonymous_com_preference_write_journey_test.rb test/controllers/concerns/preference_browser_binding_read_test.rb`:
  19 runs, 138 assertions, 0 failures, 0 errors, 0 skips. The added case checks an older generation
  renders its language and theme, does not create a row, and does not replace the JWT cookie.
- `bin/rubocop app/controllers/concerns/preference_access_token_transport.rb test/integration/anonymous_com_preference_write_journey_test.rb`:
  2 files inspected, no offenses.
- This check covers an active row, not display of a token whose row is retired or absent. HTML
  writes and other WU-7 acceptance criteria remain incomplete.
