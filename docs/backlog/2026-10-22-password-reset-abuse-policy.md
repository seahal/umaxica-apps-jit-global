# Password-reset abuse policy before introducing a reset flow

Status: Deferred; recorded at the user's request on 2026-10-22. No implementation change is
authorized by this entry. Stored in `docs/backlog/` at the user's explicit request.

## Current findings

The inspected Auth route inventory and credential-gateway documentation do not expose a general
forgotten-password flow that sends a reset link by email. Existing identity recovery and MFA-reset
routes have different purposes. No unlimited reset-email endpoint was established by this audit.

This is a deferred design gate if such a feature is introduced, not a request to implement it now.

## Follow-up when selected

- Reconfirm the route and credential model inventory before selecting work; keep Secret credentials,
  recovery and MFA reset distinct.
- If a reset-email flow is accepted, define destination/IP/session issuance budgets, verification
  attempt limits, token lifetime, single use and non-enumerating responses before delivery is enabled.
- Specify provider-failure and rate-store-failure behavior and meaningful public-boundary tests.
- Keep any new feature and its security contract subject to a separately accepted scope.

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

- [config/routes/auth.rb](../../config/routes/auth.rb)
- [config/routes/base.rb](../../config/routes/base.rb)
- [docs/security/credential-gateway.md](../../docs/security/credential-gateway.md)
- [Credential abuse policy and unimplemented target rows](../security/credential-abuse-rate-limits.md)

## Related deferred work

- [Login rate-limit guarantees](2026-10-22-login-rate-limit-guarantees.md)
- [Email sign-up delivery limits](2026-10-22-email-sign-up-delivery-limits.md)
- [Telephone sign-up destination delivery limits](2026-10-22-telephone-sign-up-delivery-limits.md)
- [Sign-in OTP resend limits and initial-issuance accounting](2026-10-22-sign-in-otp-resend-limits.md)
- [Sign-up confirmation-code resend limits](2026-10-22-sign-up-confirmation-resend-limits.md)
- [Step-up email OTP sustained delivery limits](2026-10-22-step-up-email-otp-delivery-limits.md)
- [Invitation email delivery policy before reopening issuance](2026-10-22-invitation-email-abuse-policy.md)
