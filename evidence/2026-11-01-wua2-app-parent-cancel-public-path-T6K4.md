# WU-A2 APP parent Cancel public path

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`.
- The worktree had uncommitted changes: 372 tracked paths changed and 85 untracked paths before this
  evidence file was added.
- Ran `bin/rails test test/integration/oidc_initiated_sign_in_completion_test.rb:65` with
  `.env.container.devcontainer`: 1 run, 22 assertions, 0 failures, 0 errors, 0 skips.
- The test exercised APP OIDC parent cancellation from the public Visa authorize entry through Auth
  cancellation and the browser-bound Visa POST continuation. It observed the Auth ceremony canceled
  before authentication progress, the parent pending before the Visa POST, then a canceled parent
  and an `access_denied` RP redirect carrying the original state.
- Ran `bundle exec rubocop test/integration/oidc_initiated_sign_in_completion_test.rb`: nonzero, 9
  offenses reported outside the new test in the file's helper region (lines 848–972); no RuboCop
  finding was reported in the new test body. Those helper findings were not changed in this check.
- Full suite and other realms' public parent-Cancel paths were not run here.
- Follow-up public-path recheck with `.env.container.devcontainer`:
  `bin/rails test test/integration/sign_entry_exit_flow_test.rb test/integration/sign_entry_exit_org_flow_test.rb test/integration/oidc_initiated_sign_in_completion_test.rb:65`
  passed with 14 runs, 180 assertions, 0 failures, 0 errors, and 0 skips. This includes the existing
  APP and ORG Cancel-to-Visa-POST-to-RP journeys and the new APP authorize-entry journey. It is a
  focused group, not the full suite.
