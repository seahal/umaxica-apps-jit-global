# WU-A14 BL-23 session-limit screen contract

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The shared worktree contained 544 changed tracked
paths and 264 untracked paths at the final verification snapshot; none were staged. The limitation
controller test file was clean before this slice. Its change is uncommitted, and no application
source or schema was changed.

The APP Visa limitation controller test now disables unrelated global fixtures and checks the
rendered Inertia component, session-limit labels, non-continuable state, resolution challenge, and
that every displayed signed session reference resolves to one of the actor's existing sessions. This
covers the controller's screen response and its inventory references; it is not a deployed or
real-browser check.

Verification:

- `PARALLEL_WORKERS=1 bin/rails test test/controllers/base/app/sign/in/limitations_controller_test.rb`:
  8 runs, 57 assertions, 0 failures, 0 errors, 0 skips.
- `bin/rubocop test/controllers/base/app/sign/in/limitations_controller_test.rb`: no offenses.
- `ruby -c test/controllers/base/app/sign/in/limitations_controller_test.rb` and
  `git diff --check -- test/controllers/base/app/sign/in/limitations_controller_test.rb`: passed.
- Attempting the OIDC route-level case at `test/integration/oidc_rp_browser_flow_test.rb:52` stopped
  before the test body while global fixtures loaded: `enterprise_units.enterprise_id` referenced a
  missing `enterprises` row (1 run, 0 assertions, 1 error). The route-level rendered page therefore
  remains unverified by this slice.
- The full Rails suite was not run.

2026-11-02 recheck at HEAD `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`: the route-level request was
tried again after temporarily narrowing that test class's fixture tables. Fixture setup still failed
before the test body, this time on `client_telephones.user_id` referencing an absent Client. The
temporary fixture-table edit was reverted. The route-level render remains unverified. The shared
worktree remained uncommitted (550 tracked paths changed, 269 untracked paths, none staged); no full
suite was run.
