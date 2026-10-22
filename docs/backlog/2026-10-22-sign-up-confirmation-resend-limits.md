# Sign-up confirmation-code resend limits

Status: Deferred; recorded at the user's request on 2026-10-22. No implementation change is
authorized by this entry. Stored in `docs/backlog/` at the user's explicit request.

## Current findings

App/com email and telephone sign-up issuers enforce a 30-second cooldown on the candidate
record under locks. This protects repeat issuance for one candidate and is distinct from the
login resend occurrence policy. Creating independent candidates does not share that timestamp.
Delivery guards check generation and binding but are not long-term delivery budgets.

## Follow-up when selected

- Connect first issuance and confirmation resend to the destination budgets tracked in the
  email and telephone sign-up backlogs, without duplicating counters or choosing conflicting limits.
- Preserve flow nonce, candidate ownership, expiry, terminal-state and generation checks.
- Cover immediate resend, exact 30-second boundary, concurrent calls, new candidates and failed delivery.
- Confirm request refusal prevents both enqueue and direct transport work.

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

- [app/controllers/auth/app/sign/up/check/email/otps_controller.rb](../../app/controllers/auth/app/sign/up/check/email/otps_controller.rb)
- [app/controllers/auth/app/sign/up/check/telephone/otps_controller.rb](../../app/controllers/auth/app/sign/up/check/telephone/otps_controller.rb)
- [app/operations/email_sign_up_otp_issuer.rb](../../app/operations/email_sign_up_otp_issuer.rb)
- [app/operations/telephone_sign_up_otp_issuer.rb](../../app/operations/telephone_sign_up_otp_issuer.rb)
- [test/controllers/auth/app/up/telephones_controller_test.rb](../../test/controllers/auth/app/up/telephones_controller_test.rb)
- [Credential abuse policy and unimplemented target rows](../security/credential-abuse-rate-limits.md)

## Related deferred work

- [Login rate-limit guarantees](2026-10-22-login-rate-limit-guarantees.md)
- [Email sign-up delivery limits](2026-10-22-email-sign-up-delivery-limits.md)
- [Telephone sign-up destination delivery limits](2026-10-22-telephone-sign-up-delivery-limits.md)
- [Sign-in OTP resend limits and initial-issuance accounting](2026-10-22-sign-in-otp-resend-limits.md)
- [Step-up email OTP sustained delivery limits](2026-10-22-step-up-email-otp-delivery-limits.md)
- [Password-reset abuse policy before introducing a reset flow](2026-10-22-password-reset-abuse-policy.md)
- [Invitation email delivery policy before reopening issuance](2026-10-22-invitation-email-abuse-policy.md)
