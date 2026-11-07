# Remove Application-Level Turnstile Degradation

Date: 2026-11-07

Status: Backlog. Owner requested a simpler design and a remediation proposal. Implementation and
provider configuration changes are not authorized by this document.

## Problem

`CloudflareTurnstile#verify_turnstile` passes verifier results through `TurnstileDegradation`.
When `turnstile_degraded_mode` is enabled, an upstream-unavailable result becomes a success. Missing
tokens, missing secrets and ordinary challenge failures still fail, but successful provider
verification is no longer required during an outage. A forgotten incident flag or an outage during
automated abuse can therefore weaken protection at the worst time.

Current owners and consumers:

- `app/controllers/concerns/cloudflare_turnstile.rb`
- `app/services/turnstile_degradation.rb`
- `lib/jit_security_turnstile_verifier.rb`
- `app/values/feature_flags.rb`
- `test/services/turnstile_degradation_test.rb`
- Degraded-mode cases in email sign-in and email sign-up OTP controller tests.
- `test/security/invariants/feature_flag_registry_invariant_test.rb`
- `docs/security/turnstile.md` and `docs/reference/feature-flags.md`.

The superseded `adr/turnstile-environment-toggle.md` records an earlier direction to use operational
configuration instead of an application toggle. Current docs explicitly describe degradation;
reconcile these records in the owning current contract when implementing this proposal.

## Proposed Changes

1. Remove the success-rewriting service, its call site and the feature flag registration. Keep one
   verifier outcome: a protected action proceeds only after successful verification. Provider
   timeouts, transport failures and invalid responses remain explicit failures. Add no replacement
   bypass flag, automatic key fallback or per-controller exception.
2. Retire the flag's stored operational state through an explicitly scoped cleanup. Inventory the
   flag UI, seeds, consumers and tests before removal; document deployment ordering so old running
   processes cannot continue honoring an enabled flag. Preserve relevant incident/audit history.
3. Use ordinary Cloudflare widget configuration and environment-owned credentials for recovery
   where they address the actual fault. Confirm the provider's available controls and limitations
   before describing any on/off capability. Keep the existing visible/stealth and surface ownership
   boundaries; add no new key-switching subsystem to the request path.
4. Update the current security/flag documentation and, where needed, an operator runbook with the
   supported recovery operation, verification and restoration criteria. State explicitly that
   provider unavailability can temporarily prevent protected operations. Keep the existing CSRF,
   admission, authorization, OTP budgets and rate limits.

## Provider Capabilities And Limits

Official documentation checked on 2026-11-07:

- [Widget configuration](https://developers.cloudflare.com/turnstile/concepts/widget/) documents
  Managed, Non-Interactive and Invisible modes. Presentation without interaction is not evidence
  that server-side verification can be disabled.
- [Secret rotation](https://developers.cloudflare.com/turnstile/troubleshooting/rotate-secret-key/)
  supports updating the website's secret, with a two-hour overlap of old and new keys.
- [Rotation API](https://developers.cloudflare.com/api/resources/turnstile/subresources/widgets/methods/rotate_secret/)
  also supports immediate invalidation. Choose overlap versus immediate invalidation according to
  whether the incident involves key compromise; do not assume a compromised old key is safe for
  recovery.
- [Server-side validation](https://developers.cloudflare.com/turnstile/get-started/server-side-validation/)
  remains required. Rotating a key or selecting another widget does not establish recovery from a
  Siteverify service outage. In that case, protected operations remain unavailable until successful
  verification resumes.
- [Dummy keys](https://developers.cloudflare.com/turnstile/troubleshooting/testing/) are documented
  for testing. Always-pass test credentials are not a proposed production incident bypass.

A provider-side verification-disable switch has not been established by this review. Its existence
and semantics remain a research question, not a dependency or an assumed replacement control.

## Acceptance And Verification

- Valid provider verification retains the existing successful behavior at affected public endpoints.
- Missing, empty, rejected, expired/replayed tokens, missing configuration, upstream timeouts and
  malformed responses produce no protected mutation, OTP consumption or session issuance.
- Failure remains failure even if a stale `turnstile_degraded_mode` row is enabled. Exercise the
  affected visible and stealth entry points and preserve APP/ORG isolation.
- Remove tests expecting outage-to-success conversion; retain meaningful failure and success
  coverage through the existing provider adapter seam. Do not call Cloudflare from automated tests.
- Inventory remaining references and confirm the retired flag has no executable consumers.
- Verify configuration/key changes separately as operational setup, outside Minitest/Vitest. Any
  actual production key rotation or stored-flag cleanup requires its own scoped authorization and
  recovery plan. Record real validation results without secrets.

## Scope And Tradeoff

This item addresses the Turnstile degradation concern only. OAuth revocation and Access JWT
revocation timing are separate work. No application behavior, flags or Cloudflare settings changed
while recording this proposal. The availability tradeoff is explicit: provider verification failure
stops protected work instead of silently accepting it.
