# Acme Session And Token Authority

## Status

Accepted (2026-06-02)

> **Supersession (2026-06-12):** The target component model is now defined by
> `adr/acme-sign-core-base-port-boundary.md`. Acme is the only IdP / Authorization Server. Core is
> the Next.js web RP/BFF, Base is the Rails foundation/control-plane subdomain, and Palm is the
> native bearer-token API Resource Server. This ADR's older `acme/www` session/token authority
> framing is superseded where it conflicts with that model.

> **Partial supersession (2026-10-22, design only):**
> [OP, Auth, and RP responsibility separation](op-auth-rp-authentication-responsibility-separation.md)
> assigns OP sessions to the OP and application sessions and post-step-up authorization to each RP.
> Auth remains the authentication component without application-session authority. The universal
> authority-only grant/freshness wording below no longer requires an OP visit for authenticated
> RP direct paths; their concrete trust and evidence protocol remains open.

## Context

`adr/identity-authority-boundary.md` makes `acme/www` the identity authority for sessions, tokens,
accounts, preferences, authorization, and downstream token issuance. This ADR refines the session
and token part of that decision.

Earlier ADRs described token rows, refresh flows, logout, AAL downgrade, device sessions, and
step-up freshness in a model where `sign/id` could still be read as the IdP or as a participant in
session authority. That framing is no longer current. `sign/id` is a Credential Gateway, not a user
session service.

## Decision

`acme/www` owns all user sessions and all refresh-token families.

`acme/www` is the only authority for:

- user session creation, continuation, rotation, reset, revocation, and logout;
- refresh token family issuance, rotation, replay detection, compromise state, and revocation;
- device/session listing and session-management UI;
- current-session logout and all-session revocation;
- session-bound compromise state and recovery-required state;
- `recent_auth`, `sudo`, `last_step_up_at`, AAL freshness, and equivalent step-up freshness state;
- access-token issuance for `acme/www`;
- downstream token issuance for `core`, `line`, and future downstream services.

`sign/id` must not:

- issue, refresh, rotate, revoke, list, or display user sessions;
- issue, refresh, rotate, revoke, or list refresh tokens;
- own session-management UI;
- store `recent_auth`, `sudo`, `last_step_up_at`, AAL freshness, or equivalent freshness state;
- issue access tokens, session tokens, refresh tokens, or downstream tokens;
- become the source of truth for compromise state attached to a user session.

`core`, `line`, and future downstream services must trust only `acme/www` issued downstream tokens.
They must not trust `sign/id` issued session, access, or downstream tokens.

## Step-Up Freshness

`sign/id` may execute a step-up credential ceremony when `acme/www` provides a valid ceremony grant.
The result of that ceremony is evidence returned to `acme/www`; it is not a session update by
`sign/id`.

Only `acme/www` decides whether the evidence satisfies the requested step-up purpose and only
`acme/www` stores any resulting freshness on the user session.

## Consequences

Older ADR language about token rows, logout, AAL downgrade, device sessions, and step-up flows must
be read through this boundary. Their operational vocabulary can remain useful, but any authority
assignment that lets `sign/id` own user sessions, refresh tokens, session listing, logout, token
issuance, or step-up freshness is superseded by this ADR.

Implementation must keep `sign/id` ceremony audit records separate from `acme/www` session freshness
records. A successful ceremony at `sign/id` is not sufficient to update freshness until `acme/www`
accepts the signed ceremony result.

## Related

- `adr/identity-authority-boundary.md`
- `adr/sign-credential-gateway-surface.md`
- `adr/device-session-dbsc-device-id-boundary.md`
- `adr/logout-primitive-and-composition.md`
- `adr/refresh-revoke-aal-downgrade-and-replay-hardening.md`
- `adr/session-reset-on-privilege-transition.md`
- `adr/step-up-authentication-redesign.md`
