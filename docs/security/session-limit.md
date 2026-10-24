# Sign-In Session Limit

> **Current authority boundary (2026-10-24):** Visa is the OIDC authority and owns Root Session
> issuance and session-limit resolution on `visa.umaxica.*`. Auth remains ceremony-only. Base is the
> `www.umaxica.*` browser RP and does not read or write Visa's OP session state. Historical
> `acme/www` and `sign/id` wording below must not be used to reintroduce a shared session or an
> authority endpoint on Base; see `adr/visa-op-host.md`.

This document records the session-limit behavior for sign-in flows across the `app`, `com`, and
`org` surfaces.

> **Waiting lease and resolution admission implemented (2026-10-16).** R2-WU01 stores the waiting
> slot on each realm resolution, enforces one live actor lease with a database partial unique index,
> and reconciles elapsed rows through the named writer. R2-WU02 maps a competing live lease to the
> existing generic sign-in refusal (`:session_limit_conflict`, HTTP 403). R2-WU03 implements atomic
> purge, explicit POST continuation, natural promotion, cancel and expiry completion.

## Login Units, Waiting Slot And Refusal

A login unit is one signed-in browser (one root session) of an actor on a realm. A full-access unit
has ordinary access. N is the realm's limit of full-access units.

| Realm | N   | Full-access counts | Waiting unit | Sign-in refused |
| ----- | --- | ------------------ | ------------ | --------------- |
| `app` | 2   | 0, 1, 2            | 3rd sign-in  | 4th onward      |
| `com` | 1   | 0, 1               | 2nd sign-in  | 3rd onward      |
| `org` | 1   | 0, 1               | 2nd sign-in  | 3rd onward      |

Decided under the actor lock on the writer, with the database clock:

1. Fewer than N full-access units: the sign-in becomes a full-access unit.
2. N full-access units and no open resolution for the actor: the sign-in becomes the waiting unit,
   an open session-limit resolution with no token, cookie, `current_resource` or RP grant.
3. N full-access units and an open resolution (`PENDING` or `SESSION_SELECTED`, unexpired) for the
   actor: the sign-in is refused outright. Nothing is issued, no resolution is created and no purge
   choice is offered. R2-WU01 enforces the actor's single waiting lease under the actor lock;
   R2-WU02 maps an occupied lease to the existing generic sign-in refusal
   (`:session_limit_conflict`, HTTP 403) without exposing the other flow.

- Existing full-access units are unaffected while a waiting unit exists.
- The waiting unit may only select one full-access unit, explicitly continue the bound sign-in, or
  cancel itself. It never reaches MFA reset or any full-access page.
- It becomes full access only through the explicit bound continuation after the full-access count
  drops below N (purge, sign-out, expiry or revocation); the count is rechecked under the actor
  lock. There is no background promotion.
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

An open resolution occupies the actor's waiting slot under the actor lock. R2-WU01 expires elapsed
rows before a new claim and rejects a second live claim. R2-WU02 catches that named occupied-slot
outcome at the root-admission boundary and returns the existing generic `:session_limit_conflict`
result with HTTP 403; the existing flow and lease remain unchanged.

## Session-Limit Resolution

- Auth: none. An Auth host runs credential ceremonies and issues no session, so it never holds a
  resolution; its former `/sign/in/session` page is removed.
- Visa app, OIDC resume: `/sign/in/limitation` with the `ClientSessionLimitResolutionTransaction`
  challenge.
- Google and Apple sign-up have no separate path: they reach the limit through the canonical Sign In
  and the OIDC resume above (`adr/sign-up-finalization-in-auth.md`).

The show action is read-only. The existing Visa update path accepts PATCH/PUT to select a candidate
and an explicit POST with `continue=1` to continue the same browser-bound flow. All three Visa
limitation routes expose that POST mapping without adding a new action surface. Selection records a
candidate; it does not revoke a session. The final `log_in` call obtains the actor, parent-flow and
resolution locks in the canonical order and calls
`SessionLimitResolutionTransactionable#finalize_for_session_issuance!`.

If natural sign-out or expiry has already brought the count below N, finalization marks the
resolution complete without revoking the selected history. If the count is still full, finalization
revalidates the selected target as an active session, revokes it through the authoritative current
session logout primitive, recounts and commits the new root and terminal resolution in the same OP
transaction. A stale or invalid selected target fails closed. A failed transaction leaves the
existing sessions and waiting lease intact. Competing new login and continuation attempts serialize
on the actor; the first eligible final commit wins, and no GET, polling or background request
promotes a waiting flow.

Cancelling fails only the waiting flow; no existing session is touched. com and org use the same
ceremony at `/sign/in/limitation` on their Visa host (`Visa::Com::Sign::In::LimitationsController`,
`Visa::Org::Sign::In::LimitationsController`).

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

## R2-WU03 Delivery (2026-10-16)

The three realm resolution models now permit a resolved row without selected-session facts when
capacity was freed naturally. The existing state/timestamp checks remain in place for selected
completions, and the forward migrations validate the adjusted checks separately. The source and
schema paths were exercised against the local development databases; the focused model, controller,
integration and Inertia component checks are recorded in the R2-WU03 evidence file.

## R2-WU04 Delivery (2026-10-16)

Authentication and credential continuation now require an explicit `ACTIVE` token status in addition
to expiry, rotation and device-session checks. Browser RP access, root lookup, OIDC Code and
UserInfo validation, Refresh and reissue, Step-Up, and credential ceremony consumers refuse
historical `RESTRICTED` (103) rows before principal creation. The old RestrictedSessionGuard, its
callback registrations and its refresh exception path were removed; the status reference and
historical token/audit rows remain readable. MFA reset remains a GET-only unavailable page, and the
three Base reset controllers are unreachable from a historical 103 session.

## Delivered reconciliation (2026-10-06)

All three realms use the durable session-limit resolution contract. The parent sign-in flow remains
in `SESSION_ISSUANCE_PENDING` while the child transaction is bound to actor, browser, realm and OIDC
transaction where present. Resolve, cancel, expire and conflict transitions lock and reload the
owner and use the database clock; there is no early `SESSION_LIMIT_PENDING` graph edge or
placeholder session. The former Acme/sign authority wording is historical.
