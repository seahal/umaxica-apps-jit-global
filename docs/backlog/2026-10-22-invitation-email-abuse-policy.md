# Invitation email delivery policy before reopening issuance

Status: Deferred; recorded at the user's request on 2026-10-22. No implementation change is
authorized by this entry. Stored in `docs/backlog/` at the user's explicit request.

## Current findings

OrgInvitationService.create currently returns an unsuccessful result with the message that
organization invitations are unavailable pending Bureau migration. OrgOperatorLifecycleInvitationIssuer
calls that service. No active invitation-mail send path was established through this issuance path.
The Auth org invitation controller accepts invitation codes; it is not an invitation-mail sender.

Issuance being closed is not proof of rate limiting. Existing invitation acceptance remains a
separate endpoint to inspect when this work is selected.

## Follow-up when selected

- Keep issuance closed until Bureau/Unit and grant authority prerequisites are explicitly resolved.
- Before enabling email, define inviter/organization/destination/IP budgets and authorization,
  duplicate-invitation and resend semantics with durable delivery accounting.
- Separately verify invitation-code acceptance throttling, expiry and single-use behavior.
- Test authorized success, unauthorized issuance, repeated destinations, parallel requests and
  provider failure; reopening issuance requires separately accepted scope.

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

- [app/services/org_invitation_service.rb](../../app/services/org_invitation_service.rb)
- [app/operations/org_operator_lifecycle_invitation_issuer.rb](../../app/operations/org_operator_lifecycle_invitation_issuer.rb)
- [app/controllers/auth/org/sign/up/invitations_controller.rb](../../app/controllers/auth/org/sign/up/invitations_controller.rb)
- [app/models/organization_invitation.rb](../../app/models/organization_invitation.rb)
- [Credential abuse policy and unimplemented target rows](../security/credential-abuse-rate-limits.md)

## Related deferred work

- [Login rate-limit guarantees](2026-10-22-login-rate-limit-guarantees.md)
- [Email sign-up delivery limits](2026-10-22-email-sign-up-delivery-limits.md)
- [Telephone sign-up destination delivery limits](2026-10-22-telephone-sign-up-delivery-limits.md)
- [Sign-in OTP resend limits and initial-issuance accounting](2026-10-22-sign-in-otp-resend-limits.md)
- [Sign-up confirmation-code resend limits](2026-10-22-sign-up-confirmation-resend-limits.md)
- [Step-up email OTP sustained delivery limits](2026-10-22-step-up-email-otp-delivery-limits.md)
- [Password-reset abuse policy before introducing a reset flow](2026-10-22-password-reset-abuse-policy.md)
