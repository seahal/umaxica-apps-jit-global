# Logout Primitive and Composition

## Status

Accepted (2026-05-20)

> **Supersession (2026-06-02):** This ADR's IdP/RP-centered authority model is superseded by
> `adr/identity-authority-boundary.md`. `acme/www` is now the Session, Token, Account, Preference,
> and Authorization Authority. `sign/id` is no longer the IdP; it is a Credential Gateway and
> Credential Ceremony Zone only. Historical implementation details in this ADR must not be used to
> reintroduce sign-side sessions, refresh tokens, preference writes, dashboards, account lifecycle,
> downstream token issuance, authorization decisions, or step-up freshness.

## Context

IdP-side session management needs two logout flows: revoke only the current session and revoke every
active session.

A recent refactor incorrectly wired `Authentication::Logoutable#logout_current_session!` to
`Oidc::SingleLogoutService.call(user:)`. An operation intended to sign out only the current browser
therefore revoked every active token for the user. The regression had two causes:

1. **Name and behavior diverged:** `Oidc::SingleLogoutService` suggested the OIDC Single Logout
   protocol and RP notification through back-channel or front-channel logout. The implementation did
   neither; it merely revoked all active tokens for an actor.
2. **Incorrect composition:** The service was always inserted into the ordinary logout path, so an
   operation users understood as "this browser only" signed out every device.

`Authentication::LogoutAllSessions` separately provided substantially the same behavior, leaving two
implementations of all-session revocation that could drift.

Earlier sign-up and sign-in incidents also resulted from implementing one mechanism in multiple
places. The established response is to centralize each mechanism in one concern or service and have
callers delegate to it. Logout follows the same rule.

## Decision

### 1. Remove `Oidc::SingleLogoutService`

There were no production callers, and `Authentication::LogoutAllSessions` fully replaced its
behavior. `app/services/oidc/single_logout_service.rb` and its test were deleted.

Reserve the `Oidc::` namespace for a future implementation of the actual OIDC SLO protocol. Such an
implementation must use a protocol-specific name such as `Oidc::BackchannelLogoutNotifier`.

### 2. The Logout Primitive Revokes One Session

There is one canonical session-revocation operation:

- **`Authentication::LogoutCurrentSession.call(token:, ...)`** is the only path that revokes one
  session. It owns token resolution, the `revoke!` call, narrow rescue handling, and application-log
  output.

### 3. Compose All-Session Logout by Repeating the Primitive

All-session logout iterates the primitive over an actor's token scope:

- **`Authentication::LogoutAllSessions.call(resource:, reason:)`** only:
  - increments `session_version`, invalidating remaining JWTs at refresh time;
  - resolves the actor's tokens;
  - delegates every token to `Authentication::LogoutCurrentSession.call(token:, ...)`; and
  - reports `auth.logout_all_sessions.token_failed` when an individual failure escapes the
    primitive's narrow rescue.

It must never reimplement single-token revocation.

```text
revoke_all_sessions(actor) =
  bump session_version
  for each token in tokens_for(actor):
    revoke_one_session(token)   # delegate to the primitive only
```

### 4. Ordinary Logout Calls Only the Primitive

`Authentication::Logoutable#logout_current_session!` only calls `LogoutCurrentSession` once, records
the logout audit event, and clears cookies and session state in `ensure`. It has no hook such as
`perform_single_logout` that can fan out to every device.

An endpoint that intentionally signs out every device must explicitly call
`logout_all_sessions_for!(resource:, reason:)`.

## Future IdP and RP Modes

This decision describes the repository's then-current IdP-side logout design. The primitive and
composition rule also applies if applications later operate as RPs.

### IdP Side

- One session is one surface-specific token row: ClientToken, OperatorToken, or VisitorToken.
- The primitive revokes one token row.
- Composition iterates over the actor scope.

### RP Side

For an OIDC RP, a session is not an IdP token. It is an RP-owned local session, stored in a Rails
session or dedicated RP session table. Apply the same rule:

- One session is one RP local-session record associated with the IdP `sid` claim.
- `Rp::Authentication::LogoutCurrentSession` revokes one local session.
- `Rp::Authentication::LogoutAllSessions` composes revocation across a `sub`.

At least three RP entrypoints must ultimately reach these operations:

1. **RP-Initiated Logout:** The user signs out within the RP. The RP invokes its primitive and may
   then redirect to the IdP `/oidc/logout` endpoint.
2. **Back-channel Logout:** The IdP posts a `logout_token` to the RP endpoint. The RP identifies
   sessions by `sid` or `sub`, then calls the primitive for one matching `sid` or the composition
   for all sessions matching `sub`.
3. **Front-channel Logout:** The IdP loads the RP front-channel endpoint in an iframe, which reaches
   the same primitive or composition.

When the IdP side sends real SLO notifications, implement RP notification as a separate downstream
layer after `Authentication::LogoutAllSessions`, for example in
`app/services/oidc/backchannel_logout_notifier.rb`. Do not add network responsibility to
`LogoutAllSessions` itself.

### Namespace Guidance

- `Authentication::*` is for IdP-side session operations whose concrete resources are tokens.
- A future `Rp::Authentication::*` is for RP-side operations whose concrete resources are local
  session records.
- `Oidc::*` is for OIDC protocol behavior such as logout-request validation, back-channel
  notification, and ID-token issuance. Non-protocol operations such as revoking every token do not
  belong there.

## Evidence

- `Authentication::Logoutable` has no `perform_single_logout`; it calls `LogoutCurrentSession` once
  and clears cookies and session state in `ensure`.
- `Authentication::LogoutAllSessions` delegates each token to
  `Authentication::LogoutCurrentSession.call`.
- Regression tests establish that:
  - `Oidc::SingleLogoutService` remains absent;
  - current-session logout does not call `logout_all_sessions_for!`;
  - current-session logout clears cookies and session state even when revocation raises; and
  - all-session logout delegates each token to the single-session primitive.
- App, com, and org logout controller tests assert that ordinary logout revokes only the current
  session and retains tokens for other devices.

## Consequences

- `Authentication::LogoutCurrentSession` is the only location for single-session revocation. A
  future token representation change affects one primitive.
- Additional all-device flows change only composition, not the primitive.
- The absence and no-fan-out guards catch attempts to reintroduce cross-device ordinary logout.
- The `Oidc::` namespace remains available for the real SLO protocol without a naming collision.
- A future RP implementation must reproduce the same primitive/composition separation for its local
  sessions.

## Related

- `adr/session-reset-on-privilege-transition.md`
- `adr/refresh-revoke-aal-downgrade-and-replay-hardening.md`
- `plans/active/logout-state-machine-implementation-plan.md`
