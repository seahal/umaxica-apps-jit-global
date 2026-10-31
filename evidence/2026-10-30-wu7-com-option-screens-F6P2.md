# WU-7 com selectable screen writes

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; prior and current worktree changes were
  uncommitted during verification.
- The com date format, time format, motion, density and page-size screens validate their fixed
  option sets and use the shared setting transaction and signed issuance. Invalid input is refused;
  an injected signing failure returns 503 and rolls back the new preference in the tested case.
- `bin/rails test test/integration/anonymous_com_preference_write_journey_test.rb test/controllers/base/com test/integration/preference_web_csrf_test.rb`:
  47 runs, 252 assertions, 0 failures, 0 errors, 0 skips. An earlier run failed two cases because
  the option reference rows were absent before validation; the implementation was changed to
  validate against the fixed model definitions and ensure the reference rows within the transaction.
- RuboCop on the concern, five controllers and journey test passed after formatting fixes.
- Language, timezone, region and reset screens remain on the previous write path. Per-option
  classification boundaries, concurrent writers and database commit failures remain unverified.
