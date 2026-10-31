# WU-7 com display context

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; verification ran with prior and current
  uncommitted worktree changes.
- The com JWT's named display fields now populate the request context; the Base com layout renders
  the verified JWT theme and language. The integration test also presents a conflicting legacy
  theme cookie and checks that the JWT wins without creating a preference row.
- `bin/rails test test/integration/anonymous_com_preference_write_journey_test.rb test/controllers/concerns/preference/global_test.rb test/controllers/base/com/roots_controller_test.rb`:
  22 runs, 83 assertions, 0 failures, 0 errors, 0 skips.
- `bin/rubocop app/controllers/concerns/preference_global.rb app/controllers/concerns/preference_base.rb app/helpers/application_helper.rb test/integration/anonymous_com_preference_write_journey_test.rb`:
  4 files inspected, no offenses after correcting one style offense.
- Browser rendering and other com readers were not verified. Actor preference hydration, display
  cookie recovery, the consent API, and other WU-7 contracts remain incomplete.
