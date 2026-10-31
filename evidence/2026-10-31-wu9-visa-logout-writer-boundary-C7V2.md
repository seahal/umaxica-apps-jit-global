# WU-9 Visa logout writer boundary

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- Worktree had uncommitted and untracked changes, including the two untracked PreferenceWriteBoundary files; they were preserved.
- Changed the static `sign_out` caller map and its boundary test so only `Visa::{App,Org}::Oidc::Logouts::ConfirmationsController#create` is accepted. The initiating logout controllers are rejected.
- Focused test: `bin/rails test test/controllers/concerns/preference_write_boundary_test.rb` with the required COM JWT environment: 10 runs, 78 assertions, 0 failures, 0 errors, 0 skips.
- RuboCop on the concern and test: 2 files inspected, no offenses.
- This verifies only the static writer-call boundary. Preference writes are not yet connected to the confirmed logout operation.
