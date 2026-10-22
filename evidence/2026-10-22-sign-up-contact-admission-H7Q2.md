# Sign-up contact admission verification

- Date: 2026-10-22 (UTC).
- Git HEAD: `febec3225cc9a0cfa53b9cbe817d20d366aba5a2`.
- Worktree: uncommitted changes were present before this task, including COM authentication
  controllers, localization and authentication tests. Verification includes those changes and
  this task's four contact-entry controller fixes, regression tests and documentation. It does
  not certify HEAD alone or a deployed environment.

## Changes and scope

APP/COM email and telephone registration accept explicit checkbox consent (`"1"`) and JSON
boolean consent (`true`). Other values reach the existing rejection validation. Parsing stays
at these HTTP entries because shared contact models also serve other creation workflows.
Telephone entry requires both policy and MFA-use consent.

Contact-entry replacement checks Turnstile and input validity before invoking the existing
HALTED/cleanup operation. Its position remains outside the identifier advisory transaction;
no lifecycle writer, terminal edge, lock protocol or external API contract was replaced.
Existing admission, CSRF, enforcement and OTP checks remain in place.

## Passing verification

Final command:

```sh
bin/rails test test/controllers/auth/app/up/emails_controller_test.rb test/controllers/auth/com/up/emails_controller_test.rb test/controllers/auth/app/up/telephones_controller_test.rb test/controllers/auth/com/up/telephones_controller_test.rb
```

Result: **198 runs, 2,865 assertions, 0 failures, 0 errors, 0 skips** (seed 48339).
Includes 66 added request cases covering omitted/null/empty/unchecked/false/zero/unsupported
consent, explicit JSON boolean consent and rejected replacement after missing, invalid or
unavailable CAPTCHA, missing consent or invalid contact input. Rejected requests assert no
new principal, contact, sign-up flow, token or queued job. Replacement cases compare original
flow, pending contact, principal and browser-locator facts without printing their snapshots.
Existing tests also exercise successful form submissions and accepted replacement cleanup.

RuboCop on those four test files and their four controller files: **8 files inspected, no
offenses detected**. Initial formatting offenses in the added tests were corrected before
the final run. `git diff --check` also passed.

## Expanded verification and existing failures

The following command exercised adjacent OTP, login, phase and security boundaries:

```sh
bin/rails test test/controllers/auth/app/sign/up/check/email/otps_controller_test.rb test/controllers/auth/com/sign/up/check/email/otps_controller_test.rb test/controllers/auth/app/sign/up/check/email/birthdates_controller_test.rb test/controllers/auth/com/sign/up/check/email/birthdates_controller_test.rb test/controllers/auth/app/in/emails_controller_test.rb test/controllers/auth/com/in/emails_controller_test.rb test/services/sign/in/otp_resend_service_test.rb test/services/sign/in/otp_resend_policy_test.rb test/unit/jit/security/turnstile_verifier_test.rb test/services/turnstile_degradation_test.rb test/integration/local_authentication_boundary_test.rb test/integration/sign_up_phase_regression_app_test.rb test/integration/sign_up_phase_regression_com_test.rb test/security/invariants/csrf_verification_strategy_invariant_test.rb test/security/invariants/lifecycle_direct_state_write_invariant_test.rb
```

Result: **186 runs, 3,309 assertions, 2 failures, 0 errors, 0 skips** (seed 53094).
Both failures concern replay of an already finalized local email login completion:

- `LocalAuthenticationBoundaryTest`, entry at line 789: replay assertion at line 976 expected
  HTTP 303 and received HTTP 400.
- Same class, COM entry at line 1215: replay assertion at line 1405 expected HTTP 303 and
  received HTTP 400.

Running just those two entries reproduced both failures (seed 55816). Temporarily removing
only this task's four controller changes, while retaining unrelated pre-existing work, also
reproduced both failures: 2 runs, 116 assertions, 2 failures (seed 6440). All four controllers
were then restored byte-for-byte to their fixed versions, followed by the passing final
198-test run above. No login replay behavior was changed as part of this task.

The entire Ruby/JavaScript suites, live Cloudflare verification and a browser journey were
not run. The recovery routes remain security-lock recovery, not a newly implemented
password-reset service. No production data or external service was modified.
