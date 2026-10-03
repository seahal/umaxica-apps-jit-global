# Sign-In Session Limit

> **Deprecated / partially superseded by Identity Authority inversion:** `acme/www` is the Session,
> Token, Account, Preference, Authorization, and downstream-token Authority. `sign/id` is
> ceremony-only: it may host credential entry points and execute delegated credential ceremonies,
> but it must not own sessions, refresh tokens, preference writes, dashboards, account lifecycle,
> token issuance, logout, or step-up freshness. Existing sign-side physical tables/models do not
> imply sign-side authority. Do not use this document to reintroduce sign-side sessions, refresh,
> preference, dashboard, account lifecycle, token issuance, logout, or step-up freshness.

This document records the current session-limit behavior for sign-in flows across the `app`, `com`,
and `org` surfaces.

## Surfaces And Limits

Each surface has its own token model and independent session limit. The limit counts ACTIVE,
unexpired, unrotated token rows. No restricted placeholder is issued
(`adr/root-login-establishment-boundary.md`).

| Surface | Actor      | Token model     | Active sessions | Model total-row ceiling |
| ------- | ---------- | --------------- | --------------- | ----------------------- |
| `app`   | `Client`   | `ClientToken`   | 2               | 3                       |
| `com`   | `Visitor`  | `VisitorToken`  | 1               | 2                       |
| `org`   | `Operator` | `OperatorToken` | 1               | 2                       |

The total-row ceiling is the token model's create validation (`MAX_TOTAL_SESSIONS_*`); it remains a
last line of defence and is answered with `:session_limit_hard_reject`.

## Login-Time Behavior

`AuthenticationBase#log_in(resource, establishment:)` decides under the actor row lock, in one
ticket-database transaction:

1. Below the limit, it commits one ACTIVE session and returns `status: :success`.
2. At the limit, it writes nothing and returns `status: :session_limit_pending`. The sign-in flow
   moves to `SESSION_LIMIT_PENDING` and is the only pending state; no token, cookie,
   `current_resource`, or `LOGGED_IN` audit exists for the attempt.

A pending flow does not block other sign-ins of the account.

## Session-Limit Resolution

- Auth: `Auth::{App,Com,Org}::Sign::In::SessionsController` opens only for the browser whose flow
  locator names a flow in `SESSION_LIMIT_PENDING`. The actor is that flow's principal.
- Base app, OIDC resume: `/sign/in/limitation` with the `ClientSessionLimitResolutionTransaction`
  challenge.
- Base app, social completion: `/sign/in/limitation` on the Base host that ran the completion,
  located through that host's flow locator. The URL carries no grant.

After the user revokes a session, the waiting sign-in completes through `log_in`, which re-counts
the limit; if it is still full, nothing is issued and the page is shown again. Cancelling fails only
the waiting flow; no existing session is touched. com and org have no Base limitation ceremony, so
their OIDC resume refuses a full limit with `403`.

## Sign-In Families

The current `app` sign-in families all use this same identity-level model and all converge on the
same completion gate:

- email OTP sign-in
- Google social sign-in
- Apple social sign-in
- passkey / WebAuthn sign-in
- TOTP / passcode MFA continuation

Each family reaches `establish_signed_in_session!` or a shared MFA continuation path before a token
is issued. Step-up does not create a new login unit and must not advance this model.

Login units are counted per `ClientToken`, not per RP-specific downstream token. A social sign-in,
email OTP sign-in, or passkey sign-in that arrives through the same browser/device still contributes
one login unit when it mints one `ClientToken`.

## Gate State

The DB-backed `*SignInFlow` is the pending authority. `SessionLimitGate` only remembers the return
path in the Rails session; it holds no principal and grants nothing.

## Token Status Reference

Token state is stored through the per-surface reference id, not through a token `status` string
column:

- `ClientToken#user_token_status_id`
- `VisitorToken#visitor_token_status_id`
- `OperatorToken#staff_token_status_id`

The current token-status ids reserve space between active and terminal states:

| Status       |  ID |
| ------------ | --: |
| `NOTHING`    |   0 |
| `ACTIVE`     |   1 |
| `EXPIRED`    | 102 |
| `RESTRICTED` | 103 |
| `REVOKED`    | 104 |

New token rows default to `ACTIVE`, and revocation updates the reference id to `REVOKED`.
`RESTRICTED` is no longer written; existing rows authenticate nothing and expire through their
`discard_at`.

## Enforcement Notes

The login flow counts ACTIVE sessions and reads the cooldown anchor on the writer inside the
issuance transaction, so the decision is based on the primary database state.

The token models also validate total live-session count on create. This validation gives a
model-level failure before excess live token rows are accepted.
