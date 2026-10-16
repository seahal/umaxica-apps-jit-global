# Sign-In Session Limit

> **Deprecated / partially superseded by Identity Authority inversion:** `acme/www` is the Session,
> Token, Account, Preference, Authorization, and downstream-token Authority. `sign/id` is
> ceremony-only: it may host credential entry points and execute delegated credential ceremonies,
> but it must not own sessions, refresh tokens, preference writes, dashboards, account lifecycle,
> token issuance, logout, or step-up freshness. Existing sign-side physical tables/models do not
> imply sign-side authority. Do not use this document to reintroduce sign-side sessions, refresh,
> preference, dashboard, account lifecycle, token issuance, logout, or step-up freshness.

This document records the session-limit behavior for sign-in flows across the `app`, `com`, and
`org` surfaces.

> **Decided contract, implementation pending (2026-10-16).** The user decided the waiting-slot rule
> in "Login Units, Waiting Slot And Refusal" below (`nine.md` P-8). Current code already provides
> the waiting unit with purge and cancel on all three realms; it does not yet refuse a further
> sign-in while the actor's waiting unit is open. Statements marked **pending** describe the decided
> contract, not current code.

## Login Units, Waiting Slot And Refusal

A login unit is one signed-in browser (one root session) of an actor on a realm. A full-access unit
has ordinary access. N is the realm's limit of full-access units.

| Realm | N | Full-access counts | Waiting unit | Sign-in refused |
| ----- | - | ------------------ | ------------ | --------------- |
| `app` | 2 | 0, 1, 2            | 3rd sign-in  | 4th onward      |
| `com` | 1 | 0, 1               | 2nd sign-in  | 3rd onward      |
| `org` | 1 | 0, 1               | 2nd sign-in  | 3rd onward      |

Decided under the actor lock on the writer, with the database clock:

1. Fewer than N full-access units: the sign-in becomes a full-access unit.
2. N full-access units and no open resolution for the actor: the sign-in becomes the waiting unit,
   an open session-limit resolution with no token, cookie, `current_resource` or RP grant.
3. N full-access units and an open resolution (`PENDING` or `SESSION_SELECTED`, unexpired) for the
   actor: the sign-in is refused outright. Nothing is issued, no resolution is created and no purge
   choice is offered. **Pending:** current code looks up open resolutions per sign-in flow, so it
   creates one resolution per flow instead of refusing.

- Existing full-access units are unaffected while a waiting unit exists.
- The waiting unit may only purge one full-access unit or cancel itself. It never reaches MFA reset
  or any full-access page.
- It becomes full access only when the full-access count drops below N (purge, sign-out, expiry or
  revocation); the count is rechecked under the actor lock.
- The slot frees when the waiting unit is promoted, cancelled or expires (15 minutes, capped by the
  parent flow).
- Two sign-ins arriving together at N with a free slot: exactly one becomes the waiting unit, the
  other is refused.

## Surfaces And Limits

Each surface has its own token model and independent session limit. The limit counts ACTIVE,
unexpired, unrotated token rows. No restricted placeholder is issued
(`adr/root-login-establishment-boundary.md`).

| Surface | Actor      | Token model     | Active sessions | Model total-row ceiling |
| ------- | ---------- | --------------- | --------------- | ----------------------- |
| `app`   | `Client`   | `ClientToken`   | 2               | 3                       |
| `com`   | `Visitor`  | `VisitorToken`  | 1               | 2                       |
| `org`   | `Operator` | `OperatorToken` | 1               | 2                       |

The total-row ceiling is the token model's create validation (`MAX_TOTAL_SESSIONS_*`); it remains
the last line of defence. When it refuses a login that the active-session gate allowed, the commit
is retried once under the actor lock and sent to the ordinary session-limit resolution, so the
result is `:session_limit_pending` and nothing is issued. If that retry is refused as well, the
login answers `:session_limit_conflict` with HTTP 503: a temporary failure that issues nothing and
leaves the sign-in flow resumable. The former immediate 403 (`session_limit_hard_reject`) no longer
exists.

## Login-Time Behavior

`AuthenticationBase#log_in(resource, establishment:)` decides under the actor row lock, in one
ticket-database transaction:

1. Below the limit, it commits one ACTIVE session and returns `status: :success`.
2. At the limit, it writes nothing and returns `status: :session_limit_pending`. The sign-in flow
   moves to `SESSION_LIMIT_PENDING` and is the only pending state; no token, cookie,
   `current_resource`, or `LOGGED_IN` audit exists for the attempt.

A pending flow does not block other sign-ins of the account in current code. **Pending:** under the
decided contract an open resolution occupies the actor's waiting slot and further sign-ins are
refused (see "Login Units, Waiting Slot And Refusal").

## Session-Limit Resolution

- Auth: none. An Auth host runs credential ceremonies and issues no session, so it never holds a
  resolution; its former `/sign/in/session` page is removed.
- Base app, OIDC resume: `/sign/in/limitation` with the `ClientSessionLimitResolutionTransaction`
  challenge.
- Base app, social completion: `/sign/in/limitation` on the Base host that ran the completion,
  located through that host's flow locator. The URL carries no grant.

After the user revokes a session, the waiting sign-in completes through `log_in`, which re-counts
the limit; if it is still full, nothing is issued and the page is shown again. Cancelling fails only
the waiting flow; no existing session is touched. com and org use the same ceremony at
`/sign/in/limitation` on their Base host (`Base::Com::Sign::In::LimitationsController`,
`Base::Org::Sign::In::LimitationsController`).

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
`discard_at`. It was the former session-limit placeholder; the waiting unit replaces it and is a
resolution, never a token row. It is unrelated to org Emergency Access "Restricted Mode", which is
an authentication context (`docs/security/org-emergency-access.md`).

## Enforcement Notes

The login flow counts ACTIVE sessions and reads the cooldown anchor on the writer inside the
issuance transaction, so the decision is based on the primary database state.

The token models also validate total live-session count on create. This validation gives a
model-level failure before excess live token rows are accepted.

## Delivered reconciliation (2026-10-06)

All three realms use the durable session-limit resolution contract. The parent sign-in flow remains
in `SESSION_ISSUANCE_PENDING` while the child transaction is bound to actor, browser, realm and OIDC
transaction where present. Resolve, cancel, expire and conflict transitions lock and reload the
owner and use the database clock; there is no early `SESSION_LIMIT_PENDING` graph edge or
placeholder session. The former Acme/sign authority wording is historical.
