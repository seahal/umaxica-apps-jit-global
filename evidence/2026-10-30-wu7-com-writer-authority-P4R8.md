# WU-7 com writer authority

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; prior and current uncommitted worktree
  changes were present during verification.
- The shared com writer checks an explicit set of Base com controller classes and their `update`
  action before entering the setting transaction. Other classes and actions are refused.
- `bin/rails test test/controllers/concerns/preference_write_boundary_test.rb test/integration/anonymous_com_preference_write_journey_test.rb`:
  39 runs, 238 assertions, 0 failures, 0 errors, 0 skips. Public boundary tests cover authorized
  controllers, other actions, an unrelated com controller, an app controller and a missing caller.
- `bin/rubocop app/controllers/concerns/preference_write_boundary.rb test/controllers/concerns/preference_write_boundary_test.rb`:
  2 files inspected, no offenses.
- This does not establish a complete static inventory of all writers or finish reset, app/org or
  WU-7 lifecycle migration.
