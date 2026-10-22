# Login rate-limit guarantees

Status: Deferred; recorded at the user's request on 2026-10-22. No implementation change is
authorized by this entry. Stored in `docs/backlog/` at the user's explicit request.

## Current findings

App Secret login declares IP limits of 5/minute and 20/15 minutes, plus an account limit of
5/minute. App/com email OTP issuance declares IP limits of 5/minute and 20/15 minutes and an
identifier cooldown of 30 seconds. Passkey paths have their own declarations. Auth surfaces also
have a 300/minute/IP baseline. These are layered controls, not evidence that every login method
has equivalent coverage.

The development RedisCacheStore logs connection failures and returns nil. The installed Rails
rate limiter rejects only when a non-nil count exceeds the limit, so this request-counting layer
fails open. Other admission or credential checks may still refuse the request.

## Follow-up when selected

- Inventory login methods and public endpoints separately for app, com and org, including external
  IdP initiation/callbacks, credential verification and MFA.
- Define the required IP, identifier and actor windows and explicit backend-failure behavior.
- Verify refusal at limit boundaries, distributed attempts and backend outage through public interfaces.
- Distinguish application enforcement from external IdP policy and future AWS edge controls.

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

- [app/controllers/auth/app/sign/in/secrets_controller.rb](../../app/controllers/auth/app/sign/in/secrets_controller.rb)
- [app/controllers/auth/app/sign/in/emails_controller.rb](../../app/controllers/auth/app/sign/in/emails_controller.rb)
- [app/controllers/concerns/sign_org_normal_passkey_ceremony.rb](../../app/controllers/concerns/sign_org_normal_passkey_ceremony.rb)
- [config/environments/development.rb](../../config/environments/development.rb)
- [lib/umaxica/valkey/store_error_handler.rb](../../lib/umaxica/valkey/store_error_handler.rb)
- [Credential abuse policy and unimplemented target rows](../security/credential-abuse-rate-limits.md)

## Related deferred work

- [Email sign-up delivery limits](2026-10-22-email-sign-up-delivery-limits.md)
- [Telephone sign-up destination delivery limits](2026-10-22-telephone-sign-up-delivery-limits.md)
- [Sign-in OTP resend limits and initial-issuance accounting](2026-10-22-sign-in-otp-resend-limits.md)
- [Sign-up confirmation-code resend limits](2026-10-22-sign-up-confirmation-resend-limits.md)
- [Step-up email OTP sustained delivery limits](2026-10-22-step-up-email-otp-delivery-limits.md)
- [Password-reset abuse policy before introducing a reset flow](2026-10-22-password-reset-abuse-policy.md)
- [Invitation email delivery policy before reopening issuance](2026-10-22-invitation-email-abuse-policy.md)
