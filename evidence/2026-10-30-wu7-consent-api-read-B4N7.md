# WU-7 com consent API read

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree included prior and current
  uncommitted changes.
- The com consent API reads the active preference and stored cookie decision on the writing
  connection and requires the browser binding to match before suppressing the banner.
- `bin/rails test test/integration/anonymous_com_preference_write_journey_test.rb test/integration/preference_web_csrf_test.rb`:
  19 runs, 89 assertions, 0 failures, 0 errors, 0 skips. The integration case covers a matching,
  mismatched, and missing binding and an expired preference. An initial run failed because the
  test attempted an invalid expiry before creation; it was corrected to advance the test clock.
- `bin/rubocop app/controllers/concerns/preference_web_cookie_endpoint.rb test/integration/anonymous_com_preference_write_journey_test.rb`:
  2 files inspected, no offenses.
- The API write path and the redesigned preference lifecycle remain incomplete; this is not WU-7
  acceptance evidence.
