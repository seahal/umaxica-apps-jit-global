# WU-7 consent category binding

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree contained prior and current
  uncommitted changes.
- Com cookie categories with a binding column are all masked on a missing or mismatched browser
  binding, including a functional category stored as true when consented is false.
- `bin/rails test test/integration/anonymous_com_preference_write_journey_test.rb test/controllers/concerns/preference_browser_binding_read_test.rb`:
  9 runs, 74 assertions, 0 failures, 0 errors, 0 skips. The added case checks the displayed category
  and confirms the persisted decision is unchanged.
- `bin/rubocop app/controllers/concerns/preference_browser_binding.rb test/integration/anonymous_com_preference_write_journey_test.rb`:
  2 files inspected, no offenses.
- The API write transaction and its commit-before-cookie ordering remain incomplete.
