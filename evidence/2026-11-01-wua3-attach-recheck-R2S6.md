# WU-A3 initial attachment and binding concurrency recheck

- Commit: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree had 555 staged, unstaged, or
  untracked paths; no commit was created.
- The first test boot without an explicit local environment-file selection stopped during the JWT
  initializer because `preference_com` issuer configuration was absent; no test ran in that attempt.
- The checked-in Dev Container environment contract was then selected explicitly with
  `UMAXICA_ENV_FILE=/home/global/workspace/.env.container.devcontainer`.
- Ran:
  `PARALLEL_WORKERS=1 bin/rails test test/integration/acceptance_wua3_initial_attach_race_test.rb test/services/auth_admission_binding_concurrency_test.rb`
- Result: 7 runs, 216 assertions, 0 failures, 0 errors, 0 skips. This rechecks the initial-attach
  race and binding concurrency cases against the current checkout. It does not close WU-A3's full
  acceptance, resolve the ORG Switch contract discrepancy, or verify the full suite.
