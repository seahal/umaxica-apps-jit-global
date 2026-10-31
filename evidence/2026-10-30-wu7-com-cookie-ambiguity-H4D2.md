# WU-7 com cookie input boundary

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; prior and current uncommitted worktree
  changes were present during verification.
- Base com rejects duplicate JWT, experience, language or browser-binding cookie names with 400
  before preference callbacks. The com access-token transport rejects a JWT over 3,072 bytes before
  calling the codec. This does not add a general HTTP Cookie header limit.
- `bin/rails test test/integration/anonymous_com_preference_write_journey_test.rb test/integration/preference_web_csrf_test.rb test/controllers/base/com`:
  57 runs, 317 assertions, 0 failures, 0 errors, 0 skips. After extending duplicate-cookie coverage
  to all four names, the journey ran 36 tests, 254 assertions, 0 failures, 0 errors, 0 skips.
- RuboCop on the two changed controllers/concerns and the journey test passed.
- This validates Base com handling; other com readers and the broader WU-7 acceptance remain
  unverified or incomplete.
