# WU-7 write boundary realm identity

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; prior and current uncommitted changes were
  present during verification.
- The write boundary recognizes only the three exact preference model classes or their exact
  established names; lookalike names and missing values are refused instead of being normalized
  into a realm.
- `bin/rails test test/controllers/concerns/preference_write_boundary_test.rb test/integration/anonymous_com_preference_write_journey_test.rb`:
  38 runs, 231 assertions, 0 failures, 0 errors, 0 skips.
- `bin/rubocop app/controllers/concerns/preference_write_boundary.rb test/controllers/concerns/preference_write_boundary_test.rb`:
  2 files inspected, no offenses after style correction.
- The reset path still uses the legacy lifecycle implementation and WU-7 remains incomplete.
