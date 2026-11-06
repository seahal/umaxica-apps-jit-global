# Base APP/ORG/COM Preference integration recheck after App Zenith rebuild

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree had extensive existing uncommitted
  changes (539 changed or untracked paths at the time of the run); the test ran against that working
  tree. No commit was created.
- After the local App Zenith test-database rebuild recorded in
  `evidence/2026-11-01-wua3-app-zenith-rebuild-and-switch-tests-M9C4.md`, ran
  `bin/rails test test/integration/acme_preference_test.rb` with `.env.container.devcontainer`
  sourced, the local COM Preference JWT settings supplied, a unique Valkey test namespace, and one
  worker.
- Result: 126 runs, 1,116 assertions, 0 failures, 0 errors, 0 skips across the APP, ORG and COM Base
  Preference cases. This supersedes the prior closure-note result in which fixture setup failed in
  this file before assertions.
- No application or test code changed during the run. This does not verify all three realm
  acceptance criteria or resolve the previously recorded full-suite baseline comparison. No
  production or Neon database was accessed.
