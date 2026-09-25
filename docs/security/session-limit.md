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

Each surface has its own token model and independent session limit.

| Surface | Actor      | Token model     | Active sessions | Restricted session | Total live sessions |
| ------- | ---------- | --------------- | --------------- | ------------------ | ------------------- |
| `app`   | `Client`   | `ClientToken`   | 2               | 1                  | 3                   |
| `com`   | `Visitor`  | `VisitorToken`  | 1               | 1                  | 2                   |
| `org`   | `Operator` | `OperatorToken` | 1               | 1                  | 2                   |

The active-session constants are:

- `ClientToken::MAX_SESSIONS_PER_USER = 2`
- `VisitorToken::MAX_SESSIONS_PER_VISITOR = 1`
- `OperatorToken::MAX_SESSIONS_PER_STAFF = 1`

The model-level total live-session constants are:

- `ClientToken::MAX_TOTAL_SESSIONS_PER_USER = 3`
- `VisitorToken::MAX_TOTAL_SESSIONS_PER_VISITOR = 2`
- `OperatorToken::MAX_TOTAL_SESSIONS_PER_STAFF = 2`

## Login-Time Behavior

`Authentication::Base#log_in` evaluates the actor's session-limit state before issuing a new token.

1. If active sessions are below the surface limit, login issues a normal active token.
2. If active sessions are at the surface limit and no restricted session exists, login issues a
   restricted token.
3. If active sessions are at the surface limit and a restricted session already exists, login is
   rejected with `:session_limit_hard_reject` and HTTP `403 Forbidden`.

Restricted sessions are short-lived and exist only to let the actor manage sessions. They are issued
with a 15-minute TTL.

## Restricted Session Management

Restricted sessions may access the Sign-In session management endpoint for their own surface:

- `app`: `Sign::App::In::SessionsController`
- `com`: `Sign::Com::In::SessionsController`
- `org`: `Sign::Org::In::SessionsController`

Acme also owns a browser ceremony for session-limit resolution at `/sign/in/limitation`. It is not
an OIDC protocol endpoint, and it is not part of the Sign RP surface. The OIDC branch uses
`resolution_challenge`; the social branch uses `social_resolution`.

The session management flow lists active and restricted sessions for the current actor. The actor
can revoke existing sessions. After revocation, the restricted session is promoted to active only if
the active-session count is below the surface limit.

If the actor cancels instead, the restricted token is revoked and the request is logged out.

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

For DB-backed sign-in cycles, `SignIn::SessionLimitManager` is the authoritative session-limit
participant. It accepts only cycles at `SESSION_LIMIT_PENDING`, binds the restricted token to
`cycle.token_id`, promotes only when the active-session count is below the surface limit, advances
successful promotions to `GUARDRAIL_PENDING`, and moves cancelled cycles to `FAILED`.

Legacy `SessionLimitGate` Rails session state remains as compatibility fallback for sign-in entry
points that have not yet been fully wired to DB-backed cycle locators. The legacy gate contains a
nonce, issue time, return path, and flow name. It expires after 15 minutes and is consumed after
successful session management.

The durable session state is the token row and its token-status reference id. The long-term sign-in
sequence authority is the DB-backed sign-in cycle, not the legacy gate session key.

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

New token rows default to `ACTIVE`. Restricted login flow rows are issued with `RESTRICTED`, and
revocation updates the reference id to `REVOKED`.

## Enforcement Notes

The login flow uses write-role reads when counting active and restricted sessions, so the decision
is based on the primary database state.

The token models also validate total live-session count on create. This validation gives a
model-level failure before excess live token rows are accepted.
