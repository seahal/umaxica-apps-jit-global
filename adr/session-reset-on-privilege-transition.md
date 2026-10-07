# Session Reset On Privilege Transition

## Status

Accepted (2026-05-19)

> **Supersession (2026-06-02):** This ADR's IdP/RP-centered authority model is superseded by
> `adr/identity-authority-boundary.md`. `acme/www` is now the Session, Token, Account, Preference,
> and Authorization Authority. `sign/id` is no longer the IdP; it is a Credential Gateway and
> Credential Ceremony Zone only. Historical implementation details in this ADR must not be used to
> reintroduce sign-side sessions, refresh tokens, preference writes, dashboards, account lifecycle,
> downstream token issuance, authorization decisions, or step-up freshness.

## Context

To prevent session fixation attacks, it is necessary to rotate the Rails session ID
(`reset_session`) at the moment of privilege transition. The authentication entity of this
application is JWT `reset_session` because it is a cookie and is not included in the Rails session.
is a layered defense and pre-authentication flow state (state/nonce of OIDC/social, email cooldown,
WebAuthn challenge, etc.).

The problem was not placement but **distribution of call ports**. `reset_session` If you don't put
it in a "must-pass single method", it will be silently removed in future refactors. The
investigation revealed the following (`app/controllers/concerns/authentication/base.rb`,
`app/controllers/concerns/authentication/logoutable.rb`,
`app/controllers/concerns/sign/verification_step_up_lifecycle.rb`).

- logout to `Authentication::Logoutable#logout_current_session!` to `reset_session` existing. The
  call ports are also consolidated (sample shape).
- For sign in, the session issue primitive is not called from outside `log_in`, and the beginning of
  `log_in` (of `base.rb`) `reset_session` already exists in `log_in`) and cannot be bypassed.
  However, the entrance is `complete_sign_in_or_start_mfa!` / Distributed into 3 systems: `log_in`
  direct call / `finalize_mfa_login!`.
- step-up completed all elements (passkey/TOTP/email-OTP) and all surfaces
  `consume_step_up_session!` There was no `reset_session` here.

## Decision

`reset_session` is limited to the following three privileged transition points, and each point is
aggregated into a single choke point that must pass.

1. **sign in**: `complete_sign_in_or_start_mfa!` to `establish_signed_in_session!` and make it the
   only regular public entry (`logout_current_session!` and lexical symmetry). interactive sign-in 9
   routes to this method. Sign up completed 4 routes
   (`sign/{app,com}/up/{emails,telephones}_controller`) `log_in` Direct calls are also changed to
   via this method. Actual `reset_session` remains the same as `log_in` This aggregation
   structurally guarantees non-circumvention. `log_in` / `finalize_mfa_login!` The internal body of
   is unchanged to avoid risks.
2. **step-up completed**: `Sign::VerificationStepUpLifecycle#consume_step_up_session!` adds
   `reset_session` after the `ActiveRecord::Base.connected_to` block ends and before the controller
   renders or redirects the step-up result. (This application does not use `flash`; the earlier
   ordering constraint relative to a `flash[:notice]` assignment no longer applies, but
   `reset_session` must still run before any post-transition response.)
3. **logout**: `logout_current_session!` (existing). No changes.

step-up Flow-based symmetrization refactor (`Sign::{App,Com,Org}VerificationBase` →
`Verification::Flow::*` com→app piggyback removal) is independent of the security objectives of this
decision and involves MRO fidelity risks, so it will be implemented as a separate step with a test
safety net.

## Evidence

- `reset_session` safety in step-up: WebAuthn challenge is done before calling
  `consume_step_up_session!` Consumed by `verify_passkey!`
  (`verification_passkey_actions.rb:21-22`). `return_to`/`scope` is `connected_to` Make local
  variable before block. The step-up session is DB persistent (`rs.destroy!`), so `reset_session`
  does not discard pending step-up state held in the browser session. `reset_session` must run
  before the controller renders or redirects the post-transition response.
- Equivalence of signup 4 routes: `establish_signed_in_session!` is `mfa_bypassed_for_auth_method?`
  or `!mfa_required_for?` with `log_in(require_totp_check: false)` Branched into. For newly created
  accounts, `mfa_required_for?` is fake, so the old account is `log_in(require_totp_check: true)` →
  `check_totp_requirement` → `mfa_required_for?` false and nil → Same route. Completely equivalent.
- Negative validation (no code changes required): `session_limit_gate` / `pending_login` There is no
  straddling hazard. `store_pending_login_resource` and `issue_session_limit_gate!` (via
  `login_result`) is the same **after** `reset_session` Runs within the `log_in` call and
  `session_limit_gate_return_to` is `request.fullpath` Origin and session independent.

## Consequences

Non-goal (outside the scope of this decision. Both are `reset_session` via `log_in` has already been
reached, so it is safe from fixed attacks):

- **org Social** (`sign/org/auth/omniauth_callbacks_controller.rb`'s `log_in` Direct call): For
  existing staff, MFA may be required, so `establish_signed_in_session!` If it is via TOTP, the
  behavior of judgment changes (`require_totp_check` route → MFA Orchestration). Excluded from
  regular entry aggregation to avoid behavioral differences.
- **OIDC RP / passkey Login when registering** (`log_in` of `oidc/callback.rb`,
  `sign/app/up/passkey_registrations_controller.rb` `log_in`): Out of aggregation scope due to risk
  of behavior difference of flow-specific arguments.
- **AAL promotion bypass**: `last_step_up_at` without going through `consume_step_up_session!`
  Directly update routes (risk enforcement for `app/services/sign/risk/enforcer.rb`,
  `sign/app/settings/` secrets/totps/passkeys/ telephones registrations/emails registrations).
  Because these are bootstrap/risk paths and not interactive step-ups. `reset_session` Not
  applicable.
- **Using Com's Client constants**: `verification_success_*` of `Sign::ComVerificationBase` /
  `verification_audit_*` is `ClientChronicle*` / `sign.app.*` The current behavior using is
  suspected to be a bug, but the symmetrization refactor is saved because it changes no behavior.
  Another ticket candidate.

## Related

- `adr/step-up-authentication-redesign.md`
- `adr/refresh-revoke-aal-downgrade-and-replay-hardening.md`
- `adr/authentication-assurance-level-boundaries.md`
- `docs/security/session-reset-policy.md`

## Delivered reconciliation (2026-10-06)

Full reauthentication, ordinary step-up freshness and RP credential reissuance are separate
contracts. Step-up continuation does not extend a freshness window, a credential-management
operation cannot promote registration evidence, and a privilege transition re-evaluates the current
actor and resource before issuing or replacing a session. Older sign/acme authority references are
historical and are superseded by the Base authority and operation inventory.
