# WU-A2 APP Email and Secret same-page Back refusal

- Commit: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree had 465 staged, unstaged or
  untracked paths; no commit was created.
- APP admitted OIDC Email now returns the shared 409 phase refusal when a browser returns to the
  address-entry page after Email OTP issuance, including before a `ClientSignInFlow` exists. The
  active OTP page and explicit resend remain available. APP admitted OIDC Secret now has a public
  regression case for a same-page GET after valid authentication evidence; it asserts no parent,
  binding, flow, credential, ceremony, browser-session, Auth-cookie or DBSC mutation.
- Ran the relevant entry and credential test files:
  `bin/rails test test/integration/sign_entry_otp_admitted_order_test.rb test/controllers/auth/app/in/secrets_controller_test.rb test/controllers/auth/app/in/emails_controller_test.rb test/controllers/auth/app/sign_ins_controller_test.rb test/controllers/auth/app/sign_ups_controller_test.rb test/controllers/auth/org/sign_ins_controller_test.rb`
  — 115 runs, 1,104 assertions, 0 failures, 0 errors, 0 skips.
- RuboCop on the changed controller and test files reported five layout offenses in
  `test/controllers/auth/app/in/secrets_controller_test.rb`. Running RuboCop on the HEAD version of
  that same file reported the same five offenses; no new offense was introduced. `git diff --check`
  passed.
- Not run: full test suite. This slice does not establish all WU-A2 acceptance criteria or
  completion of `two.md`.
