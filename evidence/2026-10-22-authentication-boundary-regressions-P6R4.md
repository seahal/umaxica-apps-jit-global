# Authentication boundary regression verification

- Date: 2026-10-22 (UTC).
- Git HEAD: `febec3225cc9a0cfa53b9cbe817d20d366aba5a2`.
- Worktree: pre-existing uncommitted work and the earlier contact-admission fixes were present.
  Results describe this worktree, not HEAD alone or a deployed system.
- Scope: retain the existing CAPTCHA, bound OTP resend and effective-email-binding behavior;
  add missing regression coverage and clarify the existing security-lock recovery scope.
  No application behavior, route, feature flag, database schema or external service was changed
  during this follow-up.

## Added coverage

Twenty-one public-boundary cases were added:

- Three real-verifier/degradation cases: missing, empty and whitespace-only tokens fail even
  when outage degradation is enabled. These inputs stop before provider HTTP.
- Six resend-state cases: APP/COM authenticated state can be parsed one second before expiry
  and is refused at and one second after its absolute deadline.
- Six APP/COM sign-in requests: unverified, pending-sign-up and VERIFIED-status candidates
  without a finalized binding receive no login OTP and cannot authenticate. Candidate facts
  are preserved and no Root credential is issued.
- Six APP/COM security-lock recovery requests: the same unbound candidate partitions cannot
  obtain OTP delivery, a recovery ceremony, a login token or a secret credential, even with an
  eligible active security lock. The contact and lock remain unchanged by rejected recovery.

The new cases first passed in isolation: 21 runs, 190 assertions, no failures/errors/skips
(seed 18931). Tests use the existing confirmed-admission setup and public HTTP/production APIs;
no private-method access or new test helpers were introduced.

## Final verification

```sh
bin/rails test test/services/turnstile_degradation_test.rb test/unit/jit/security/turnstile_verifier_test.rb test/services/sign/in/otp_resend_service_test.rb test/services/sign/in/otp_resend_policy_test.rb test/controllers/auth/app/web/v0/in/email/otps_controller_test.rb test/controllers/auth/com/web/v0/in/email/otps_controller_test.rb test/controllers/auth/app/in/emails_controller_test.rb test/controllers/auth/com/in/emails_controller_test.rb test/integration/identity_recovery_entrypoint_render_test.rb test/controllers/base/identity_recovery_actions_test.rb test/models/email_signup_verification_status_test.rb test/controllers/auth/app/sign/up/check/email/otps_controller_test.rb test/controllers/auth/com/sign/up/check/email/otps_controller_test.rb
```

Result: **186 runs, 1,993 assertions, 0 failures, 0 errors, 0 skips** (seed 39202).
The selected existing tests also cover admitted cross-browser resend rejection, released-binding
retargeting refusal, destination cooldown, preservation of OTP failure counts, successful OTP
delivery/verification and security-lock completion.

RuboCop on all five changed Ruby test files: **5 files inspected, no offenses detected**.
Initial formatting/assertion-style offenses in the new tests were corrected before the final
run. `git diff --check` passed.

Current security documentation now states the incident-only CAPTCHA degradation condition,
the bound resend exception, effective-binding requirements and the difference between lock
recovery and a forgotten-password reset. Durable checklist items AUTH-22 through AUTH-25 retain
these contracts.

## Limits and separate known failures

The entire test suites, live provider HTTP and a browser journey were not run. No new
password-reset feature was implemented. The two previously reproduced login-completion replay
failures in `LocalAuthenticationBoundaryTest` were not changed or rerun in this follow-up;
their pre-change reproduction is retained in
[the preceding evidence](2026-10-22-sign-up-contact-admission-H7Q2.md).
