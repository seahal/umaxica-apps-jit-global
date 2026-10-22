# Telephone sign-up destination delivery limits

Status: Deferred; recorded at the user's request on 2026-10-22. No implementation change is
authorized by this entry. Stored in `docs/backlog/` at the user's explicit request.

## Current findings

App/com telephone sign-up issuance checks a 30-second cooldown on the individual telephone
candidate under a database lock. TelephoneSignUpCandidateCreator creates a new owner and candidate;
its identifier advisory lock serializes creation but does not consume a destination send budget.
Independent candidates can therefore have independent send timestamps for the same number.

The sign-up controllers have the inherited Auth 300/minute/IP baseline, but no dedicated
phone-destination issuance budget was found in these entry paths. Admission and Turnstile are
prerequisites, not destination send quotas. This is a static code finding, not a reproduced
HTTP or real-provider exploit.

## Follow-up when selected

- Add a shared phone-digest delivery budget before first issuance and every reissue, preserving
  app/com trust boundaries and independent candidate state.
- Define layered source/session/actor controls and durable cost budgets.
- Test independent candidates for the same number, parallel issuance, IP/browser changes,
  provider failures and limits immediately below, at and above each boundary.
- Keep the development test SMS provider and real SNS delivery verification distinct.

## Scope and verification context

Development environment only. Cloudflare Tunnel is excluded. The user plans Amazon EKS with
CloudFront and AWS WAF; the AWS rate-limiting mechanism is undecided. Planned edge controls are
not current guarantees, and this entry does not select an AWS product or authorize external changes.
Development configuration selects `SMS_PROVIDER=test` in the checked-in environment file and SES
SMTP for email; live provider settings and quotas were not inspected. Provider quotas must not be
assumed to enforce application destination budgets.

The source inspection was performed on 2026-10-22 at commit
`febec3225cc9a0cfa53b9cbe817d20d366aba5a2`, including pre-existing uncommitted changes.
A combined run of `test/services/sign/in/otp_resend_policy_test.rb`,
`test/controllers/auth/authentication_rate_limit_test.rb` and
`test/operations/telephone_sign_up_otp_issuer_test.rb` stopped during test database preparation:
`PG::DuplicateTable` for `publishing_media_files`. Test bodies did not run. Existing tests were
read, not established as passing. No HTTP flood or real email/SMS delivery was performed.

## References

- [app/controllers/auth/app/sign/up/telephones_controller.rb](../../app/controllers/auth/app/sign/up/telephones_controller.rb)
- [app/controllers/auth/com/sign/up/telephones_controller.rb](../../app/controllers/auth/com/sign/up/telephones_controller.rb)
- [app/operations/telephone_sign_up_candidate_creator.rb](../../app/operations/telephone_sign_up_candidate_creator.rb)
- [app/services/sign_up_email_pending_guard.rb](../../app/services/sign_up_email_pending_guard.rb)
- [app/operations/telephone_sign_up_otp_issuer.rb](../../app/operations/telephone_sign_up_otp_issuer.rb)
- [Credential abuse policy and unimplemented target rows](../security/credential-abuse-rate-limits.md)

## Related deferred work

- [Login rate-limit guarantees](2026-10-22-login-rate-limit-guarantees.md)
- [Email sign-up delivery limits](2026-10-22-email-sign-up-delivery-limits.md)
- [Sign-in OTP resend limits and initial-issuance accounting](2026-10-22-sign-in-otp-resend-limits.md)
- [Sign-up confirmation-code resend limits](2026-10-22-sign-up-confirmation-resend-limits.md)
- [Step-up email OTP sustained delivery limits](2026-10-22-step-up-email-otp-delivery-limits.md)
- [Password-reset abuse policy before introducing a reset flow](2026-10-22-password-reset-abuse-policy.md)
- [Invitation email delivery policy before reopening issuance](2026-10-22-invitation-email-abuse-policy.md)
