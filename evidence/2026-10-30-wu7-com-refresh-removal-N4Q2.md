# WU-7 com refresh credential removal

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained uncommitted
  changes from earlier work and the changes tested here.
- Com preference creation no longer generates or stores a refresh credential or records a
  refresh rotation; com refresh lookup no longer accepts a presented legacy credential. Existing
  app and org refresh paths remain in place pending WU-9.
- `bin/rails test test/integration/anonymous_com_preference_write_journey_test.rb test/integration/preference_web_csrf_test.rb`:
  15 runs, 66 assertions, 0 failures, 0 errors, 0 skips. The journey includes an invalid legacy
  refresh cookie and checks that the newly created com row has no refresh digest.
- `bin/rubocop app/controllers/concerns/preference_refresh_token_transport.rb test/integration/anonymous_com_preference_write_journey_test.rb`:
  2 files inspected, no offenses.
- WU-7 remains incomplete, including its lifecycle/schema and transaction contracts; this result
  does not establish the remaining acceptance criteria.
