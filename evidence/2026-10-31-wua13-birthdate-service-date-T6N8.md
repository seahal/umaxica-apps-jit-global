# WU-A13 birthdate service-date boundaries

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting the checks.
- At a time when UTC and Asia/Tokyo had different calendar dates, the targeted email and telephone signup tests and email birthdate response cases produced 3 failures in 6 runs (135 assertions). The test inputs used the UTC date while requests used the Tokyo service date.
- Changed the tests to construct their boundary inputs using the Tokyo service date at execution time. The telephone yesterday case now uses the same date as its today and tomorrow cases.
- Re-ran `PARALLEL_WORKERS=1 bin/rails test` with the targeted email signup, telephone signup and email birthdate test locations: 7 runs, 194 assertions, 0 failures, 0 errors, 0 skips.
- The full suite was not rerun for this change.
- `bundle exec rubocop` on the three changed test files passed (3 files, no offenses).
