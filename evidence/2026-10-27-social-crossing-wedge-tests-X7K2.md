# Social intent-crossing wedge tests (before the D-47 controller change)

- Commit: `aeb09ca9fb97ef1ca24c0195b2fa1d28d21245df`; the worktree had extensive uncommitted cycle
  changes, including earlier edits to both test files.
- Added to `test/integration/social_login_admission_test.rb` (APP Google, end to end through Base,
  Visa and Auth):
  - D-48 L1: an unknown subject started at sign-in creates no Client, ClientGoogleIdentity,
    ClientSignUpFlow or ClientToken, records no Auth evidence, leaves the authorization transaction
    pending and removes the social state from the session.
  - D-48 L2: the same for a registered subject started at sign-up.
  - D-47: the two crossings return the same status, Location path and body.
- Added to `test/controllers/auth/org/omniauth/omniauth_callbacks_controller_test.rb`: an
  unprovisioned Entra subject creates no Operator, OperatorEntraIdentity or OperatorToken.
- Mutation checks (temporary, reverted): removing the sign-up-only guard in
  `SocialAuthLoginHandler#pending_social_signup` failed the L1/D-47 run (2 runs, 1 failure); removing
  `clear_social_auth_intent!` from the HTML error branch failed the L2 test (1 run, 1 failure).
- `PARALLEL_WORKERS=1 bin/rails test` on both files: 31 runs, 285 assertions, 0 failures, 0 errors.
  RuboCop: no offenses on both files.
- Not added: an ORG D-47 uniformity test. Run once, it failed: the unprovisioned subject shows
  "このアカウントはスタッフとして登録されていません。…" and a locked method shows
  "このアカウントの Microsoft サインインはロックされています。…" (both 422). Reported to the owner.
