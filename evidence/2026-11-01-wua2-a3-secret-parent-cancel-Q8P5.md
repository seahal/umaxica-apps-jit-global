# WU-A2/A3 shared boundary: completed Secret signup survives parent OIDC Cancel

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`.
- The worktree contained extensive uncommitted WU and test changes; no commit was made.
- Added an App signup-journal assertion after completed registration and before Base finalizes the
  OIDC parent. The test issues and consumes the parent cancellation handoff, cancels the unfinalized
  parent, then runs the signup phase of `ClientSecretLifecycleJob`.
- It verifies that the signup flow remains completed, the actor remains `VERIFIED_WITH_SIGN_UP`, the
  issuance completion fact remains, and credential lifecycle facts and audit records are unchanged.
- Targeted command:
  `set -a; . ./.env.container.devcontainer; set +a; bin/rails test test/integration/app_secret_signup_journey_test.rb --name '/A=0 saves its fixed Secret set and handles completed/'`.
- Final result: 1 run, 82 assertions, 0 failures, 0 errors, 0 skips. The test used the configured
  local test databases; no production or Neon database was accessed.
- During the first run with the new assertions, strict loading rejected lazy access to the signup
  flow's admission binding. The test now loads the binding and OIDC parent explicitly; the final
  targeted run passed.
- Targeted RuboCop after correcting the new lines reported 4 offenses, all in pre-existing lines 67,
  93 and 94; no offense remained on the added lines. `git diff --check` passed.
- This covers the shared registered-account/Secret-job clause in two.md §3.6 and §10.5, assigned to
  WU-A2. It does not close the other generated signup cases, the remaining WU-A2/A3 acceptance
  matrix, or the full test suite.
