# WU-A1 JSON OTP resend stop boundary

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree carried the uncommitted
  WU-3..WU-7 slices of prior sessions plus these changes.
- The Auth app sign-in entry classification (WU-A1 pauses: the closed four-way declaration,
  route guard, parent-intent source guard and standby exception in
  `test/unit/security/sign_entry_classification_guard_test.rb`) and the sentry surface battery
  verified green this session: 32 runs, 316 assertions, 0 failures (guard, resolver, integration,
  three acceptance_wu29 sentry records) plus the WU-7 journey (36 runs, 254 assertions).
- New acceptance evidence: the designated resend entry stop (`sign_entry_classification`
  sign_in) also covers the JSON OTP resend endpoint at the ceremony-expiry boundary.
  `test/controllers/auth/app/web/v0/in/email/otps_controller_test.rb` gained:
  - a blocked sign-in sentry answers the signed resend with the uniform 503 availability body,
    no-store, and creates no delivery occurrence, no delivery and no new OTP generation;
  - a resend at one second before, exactly at, and one second after the ceremony expiry is
    refused every time with no delivery and no ceremony mutation (no generation rotation, no
    revocation), covering the lifetime boundary through the public endpoint.
- `bin/rails test test/controllers/auth/app/web/v0/in/email/otps_controller_test.rb`:
  9 runs, 71 assertions, 0 failures, 0 errors, 0 skips.
- `test/controllers/concerns/ + preference_web_csrf_test.rb` regression after the boundary
  addition: 741 runs, 8,982 assertions, 2 failures — the two recorded baseline ids
  (`AuthenticationSessionRevokerTest`, `SignOrgVerificationBaseDirectCoverageTest`).
- RuboCop on the touched test file clean after `-A` style corrections.
- Not established here: the org-surface resend endpoint boundary tests, the D-52 phase-409
  response boundary and its exact cookie/header suppression (that is two.md §12.3, WU-A2 scope,
  which stays behind the A2/A3 shared-contract ordering), and the attached-but-unconfirmed
  admission variant, which the public entry path cannot reach without first confirming.
