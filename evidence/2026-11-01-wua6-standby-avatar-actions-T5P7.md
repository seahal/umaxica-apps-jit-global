# WU-A6 ORG Standby Avatar transfer action refusals

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree was dirty (574 staged, unstaged, or
  untracked status entries at verification); no commit was created.
- A public HTTP test seeds a Standby ORG Browser RP token with matching fresh Step-Up evidence and
  exercises Avatar transfer request, accept and cancel. All three return HTTP 403 with the existing
  `auth.step_up.emergency_unavailable` response.
- The request adds no `AvatarTransferReservation`. The seeded accept and cancel transfers remain
  pending. Step-Up freshness and Standby context remain unchanged, and no additional Operator
  Step-Up ceremony is created.
- The focused test passed: 1 run, 22 assertions, 0 failures, 0 errors, 0 skips. The entire Avatar
  transfer controller test file passed: 16 runs, 128 assertions, 0 failures, 0 errors, 0 skips.
- Scoped RuboCop inspected the Avatar controller test and Step-Up integration test files with no
  offenses. Ruby syntax checks returned `Syntax OK` for both; `git diff --check` passed.
- The test creates source/target transfers through the existing transfer operation, then submits the
  protected browser actions. It does not establish real Standby Root issuance or the full
  policy-derived Normal/Standby operation matrix. The full suite was not run. No application
  behavior, schema or production/Neon data was changed.
