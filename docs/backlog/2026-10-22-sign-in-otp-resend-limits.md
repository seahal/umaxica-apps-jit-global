# Sign-in OTP resend limits and initial-issuance accounting

Status: Deferred; recorded at the user's request on 2026-10-22. No implementation change is
authorized by this entry. Stored in `docs/backlog/` at the user's explicit request.

## Current findings

SignInOtpResender supports email on app/com, not SMS login. It locks an EmailOccurrence row
for the target and reserves the resend slot before issuing or delivering. Provider failure still
consumes that slot. The policy computes exponential cooldown from the most recent five minutes,
starting at 30 seconds with a configured 15-minute cap; an empty recent window permits a resend.
This is pacing, not a daily or lifetime send ceiling.

Initial login issuance uses separate controller counters and does not itself establish a combined
initial-send/resend destination budget.

## Follow-up when selected

- Define whether initial issuance and resend consume one shared destination delivery budget.
- Specify sustained and daily limits, five-minute-history behavior and accounting after failed sends.
- Preserve browser/surface binding, non-enumerating responses and reservation before provider I/O.
- Exercise races, first-send/resend alternation, new flows, invalid state and exact cooldown boundaries.

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

- [app/services/sign_in_otp_resender.rb](../../app/services/sign_in_otp_resender.rb)
- [app/policies/sign_in_otp_resend_policy.rb](../../app/policies/sign_in_otp_resend_policy.rb)
- [app/services/sign_in_otp_resend_state.rb](../../app/services/sign_in_otp_resend_state.rb)
- [app/controllers/auth/app/web/v0/in/email/otps_controller.rb](../../app/controllers/auth/app/web/v0/in/email/otps_controller.rb)
- [test/services/sign/in/otp_resend_service_test.rb](../../test/services/sign/in/otp_resend_service_test.rb)
- [Credential abuse policy and unimplemented target rows](../security/credential-abuse-rate-limits.md)

## Related deferred work

- [Login rate-limit guarantees](2026-10-22-login-rate-limit-guarantees.md)
- [Email sign-up delivery limits](2026-10-22-email-sign-up-delivery-limits.md)
- [Telephone sign-up destination delivery limits](2026-10-22-telephone-sign-up-delivery-limits.md)
- [Sign-up confirmation-code resend limits](2026-10-22-sign-up-confirmation-resend-limits.md)
- [Step-up email OTP sustained delivery limits](2026-10-22-step-up-email-otp-delivery-limits.md)
- [Password-reset abuse policy before introducing a reset flow](2026-10-22-password-reset-abuse-policy.md)
- [Invitation email delivery policy before reopening issuance](2026-10-22-invitation-email-abuse-policy.md)
