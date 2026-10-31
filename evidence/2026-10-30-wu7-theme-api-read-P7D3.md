# WU-7 com theme API read

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree included uncommitted prior
  work and the changes tested here.
- The com theme API reads the `theme` member of the signed com preference payload. The app and
  org paths continue to read their existing `ct` member.
- `bin/rails test test/integration/anonymous_com_preference_write_journey_test.rb`: 3 runs,
  33 assertions, 0 failures, 0 errors, 0 skips. The added HTTP test checks a dark theme and confirms
  the GET does not create a preference row.
- `bin/rubocop app/controllers/concerns/preference_web_theme_endpoint.rb test/integration/anonymous_com_preference_write_journey_test.rb`:
  2 files inspected, no offenses.
- The browser consent API still uses the legacy payload and buffer-only path; this check does not
  establish its write or binding contract. WU-7 remains incomplete.
