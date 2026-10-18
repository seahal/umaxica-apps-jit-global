# Legacy Auth verification base retirement

- Date: 2026-10-04 UTC.
- Commit: `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`.
- Worktree: uncommitted authentication changes and unrelated concurrent work.
- Database: owned isolated run `20261003auth6f3`, manifest
  `tmp/auth-boundary-isolated-20261003auth6f3.json`; APP ticket preparation, one worker.

The unused APP, COM and ORG `Auth::*::Verification::BaseController` files were removed. Current
verification leaf controllers already inherit their own surface ApplicationController and enforce
purpose-scoped admission and ownership. Searches of the verification controllers, routes, and test
references found no caller of the removed classes. Their ordinary Auth root-login prerequisite,
verification callback skips, and attachment of old ceremony concerns are no longer available as
an inheritance path. The sensitive-skip allowlist removes precisely those three files.

`bin/rails test test/unit/security/forbidden_rails_patterns_test.rb
test/unit/security/authentication_mode_inventory_test.rb test/unit/security/action_policy_usage_test.rb
test/controllers/auth/step_up_admission_test.rb test/controllers/auth/ceremony_admission_boundary_test.rb
test/integration/totp_registration_boundary_test.rb` passed
**41 runs, 402 assertions, no failures/errors/skips**, seed 65169. `git diff --check` passed.
RuboCop inspected the changed security guard test with no offenses.

The regional-routing analysis marks its earlier finding about those three classes as historical.
This retirement changes no route, database, admission payload, or active endpoint response.
Other legacy concerns and their private-method tests still need deliberate retirement and coverage
migration. Primary sign-in/signup challenge storage and Auth credential management are separate
remaining work. This does not establish full R03, R06 or R16 completion, live provider behavior,
production usage, or browser verification. OTP logging remediation remains excluded.
