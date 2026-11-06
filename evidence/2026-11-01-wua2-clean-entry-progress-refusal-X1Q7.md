# WU-A2 progressed-entry reload refusal

At HEAD `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`, the worktree contained 463 changed or untracked
paths; existing uncommitted changes were retained. No commit was created.

## Change

The APP and ORG Sign In entry controllers and APP Sign Up entry controller now reject a clean
entry-page GET when the matching admitted OIDC authentication ceremony has recorded authentication
evidence, an APP email OTP, or an APP sign-up Flow. The shared refusal returns the existing
phase-violation 409 response before changing the parent transaction, admission binding, ceremony,
Flow, browser session, or Auth SID cookie. The public response is checked for the fixed body, no
`Location`, `private, no-store`, and no authentication or DBSC cookies or headers. A GET carrying a
fresh `entry_ref` continues through the existing admission path.

The acceptance checklist and public-entrypoint security documentation now describe this stale-page
boundary.

## Verification

- Before the controller guard, the new APP email-OTP and ORG Entra-evidence regression tests each
  returned 200 instead of the required 409: 2 runs, 2 failures.
- After the guard, those tests passed: 2 runs, 17 assertions, 0 failures/errors/skips.
- The APP OIDC sign-up Flow reload test passed: 1 run, 10 assertions, 0 failures/errors/skips.
- Final affected-file run:
  `bin/rails test test/integration/sign_entry_otp_admitted_order_test.rb test/controllers/auth/org/sign_ins_controller_test.rb test/controllers/auth/app/sign_ins_controller_test.rb test/controllers/auth/app/sign_ups_controller_test.rb`
  Result: 43 runs, 359 assertions, 0 failures/errors/skips.
- Scoped RuboCop on the seven changed controller, concern, and test files passed with no offenses.
  `git diff --check` passed.

These checks do not constitute the WU-A2/WU-A3 or full `two.md` closure run. Rails output included
the existing NanoID frozen-string warning.
