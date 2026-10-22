# Email sign-up delivery limits

Status: Deferred; recorded at the user's request on 2026-10-22. No implementation change is
authorized by this entry. Stored in `docs/backlog/` at the user's explicit request.

## Current findings

App/com email sign-up creation has an IP limit of 30/minute and an address limit of
30/10 minutes in development. Issuance also checks a 30-second cooldown on the pending email
candidate under a database lock. New sign-up candidates have independent cooldown state.
The candidate cooldown therefore does not establish a shared destination delivery budget.

Daily and longer outbound email limits in the credential-abuse policy document remain target rows
with pending implementation sources. The Valkey request limits also have the outage limitation
tracked in the login backlog.

## Follow-up when selected

- Define a destination-scoped issuance budget shared across new candidates and browser flows,
  while preserving realm boundaries and independent candidate ownership.
- Reserve delivery capacity atomically before enqueue or transport and specify failure accounting.
- Select durable daily and longer limits without treating documented target values as approved policy.
- Cover new-flow attempts, parallel requests, provider/enqueue failure and exact window boundaries.

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

- [app/controllers/auth/app/sign/up/emails_controller.rb](../../app/controllers/auth/app/sign/up/emails_controller.rb)
- [app/controllers/auth/com/sign/up/emails_controller.rb](../../app/controllers/auth/com/sign/up/emails_controller.rb)
- [app/values/rate_limit_profiles.rb](../../app/values/rate_limit_profiles.rb)
- [app/operations/email_sign_up_candidate_creator.rb](../../app/operations/email_sign_up_candidate_creator.rb)
- [app/operations/email_sign_up_otp_issuer.rb](../../app/operations/email_sign_up_otp_issuer.rb)
- [Credential abuse policy and unimplemented target rows](../security/credential-abuse-rate-limits.md)

## Related deferred work

- [Login rate-limit guarantees](2026-10-22-login-rate-limit-guarantees.md)
- [Telephone sign-up destination delivery limits](2026-10-22-telephone-sign-up-delivery-limits.md)
- [Sign-in OTP resend limits and initial-issuance accounting](2026-10-22-sign-in-otp-resend-limits.md)
- [Sign-up confirmation-code resend limits](2026-10-22-sign-up-confirmation-resend-limits.md)
- [Step-up email OTP sustained delivery limits](2026-10-22-step-up-email-otp-delivery-limits.md)
- [Password-reset abuse policy before introducing a reset flow](2026-10-22-password-reset-abuse-policy.md)
- [Invitation email delivery policy before reopening issuance](2026-10-22-invitation-email-abuse-policy.md)
