# Step-up email OTP sustained delivery limits

Status: Deferred; recorded at the user's request on 2026-10-22. No implementation change is
authorized by this entry. Stored in `docs/backlog/` at the user's explicit request.

## Current findings

IdentityStepUpEmailCodeIssuer implements a 60-second credential-scoped issuance interval under
locks, shared across transactions and browser changes. It records issuance before enqueue.
Verification separately has credential-scoped failed-attempt handling. These controls do not
establish a daily or provider-account delivery budget.

This entry records a follow-up for existing controls, not a claim that step-up email is currently
unthrottled.

## Follow-up when selected

- Decide whether the existing interval is sufficient alongside destination, actor and durable
  daily budgets, and how this event shares accounting with other outbound email purposes.
- Preserve credential binding, root authority checks and verification-failure budgets across resend.
- Verify fresh transactions/browser changes cannot reset the interval, including concurrency,
  enqueue failure and immediately below/at/above the 60-second boundary.

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

- [app/operations/identity_step_up_email_code_issuer.rb](../../app/operations/identity_step_up_email_code_issuer.rb)
- [app/operations/identity_step_up_email_verification_committer.rb](../../app/operations/identity_step_up_email_verification_committer.rb)
- [app/controllers/auth/app/verification/emails_controller.rb](../../app/controllers/auth/app/verification/emails_controller.rb)
- [app/controllers/auth/app/verification/redeliveries_controller.rb](../../app/controllers/auth/app/verification/redeliveries_controller.rb)
- [Credential abuse policy and unimplemented target rows](../security/credential-abuse-rate-limits.md)

## Related deferred work

- [Login rate-limit guarantees](2026-10-22-login-rate-limit-guarantees.md)
- [Email sign-up delivery limits](2026-10-22-email-sign-up-delivery-limits.md)
- [Telephone sign-up destination delivery limits](2026-10-22-telephone-sign-up-delivery-limits.md)
- [Sign-in OTP resend limits and initial-issuance accounting](2026-10-22-sign-in-otp-resend-limits.md)
- [Sign-up confirmation-code resend limits](2026-10-22-sign-up-confirmation-resend-limits.md)
- [Password-reset abuse policy before introducing a reset flow](2026-10-22-password-reset-abuse-policy.md)
- [Invitation email delivery policy before reopening issuance](2026-10-22-invitation-email-abuse-policy.md)
