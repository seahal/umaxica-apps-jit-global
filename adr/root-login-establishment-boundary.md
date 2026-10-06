# Root Login Establishment Boundary

## Status

Accepted (2026-10-02)

Supersedes, where they conflict:

- `adr/social-login-cooldown-and-one-shot-completion.md`: the cooldown anchor ("a freshly issued
  `ClientToken`") and the `bootstrap_actor: true` exemption for sign-up completion and OIDC
  authorization resume. One-shot social ceremony results remain as decided there.
- The restricted-session approach to the concurrent session limit described in the header comments
  of the former `Auth::{App,Com,Org}::Sign::In::SessionsController` and in `SignInSessionLimitManager`
  (removed).

## Context

A sign-in attempt that had not satisfied its preconditions could still be treated as an
established login:

- At the active-session limit, `AuthenticationBase#log_in` minted a `RESTRICTED` token with a device
  session, access and refresh cookies, `current_resource`, and a `LOGGED_IN` audit, and returned
  `status: :success` with `restricted: true`. Base OIDC resume and the Base social limitation page
  depended on that placeholder; the current-resource resolver accepted it as a signed-in session.
- `status: :success` plus `session_management_required` left each caller to tell pending from
  established.
- `bootstrap_actor: true` and `skip_login_cooldown: true` skipped the limit and the cooldown for
  sign-up handoff, MFA completion, OIDC resume (com/org), selector completion, and limit promotion.
- The cooldown read the newest `created_at` of any token row on a read replica, so RP sessions,
  refresh rows, and restricted placeholders moved it, and replica lag could hide a new login.
- The cooldown check, the limit count, and the writes ran outside one transaction; cookies and the
  Rails session reset happened before the decision, so a refused attempt could still disturb the
  browser's existing context.
- Session-limit management trusted `session[:pending_login_*_id]`; the Base social limitation link
  carried a signed bearer token with the actor reference that let any holder list and revoke the
  account's sessions and sign in.
- Sign-out treated a database failure while resolving or revoking the session as "no session" and
  completed the sign-out flow.

## Decision

### Establishment point

A new root login is established when the session and its establishment record commit in the
surface's ticket database. Rendering a dashboard or storing a cookie is not part of the decision.

`AuthenticationBase#log_in(resource, establishment:)` is the only final issuance boundary. Under a
row lock on the actor (principal database) it opens one ticket-database transaction that:

1. re-checks the cooldown for `establishment: :root_login`,
2. re-locks and re-validates the sign-in flow when one is passed (surface, actor binding, expiry,
   no earlier session, waiting state),
3. counts ACTIVE sessions against the limit,
4. creates the token, device session, and refresh family, binds and advances the flow, and writes
   `root_login_established_at`.

A refusal returns before any write. Cookies, `current_resource`, and the `LOGGED_IN` audit are
applied only after the outermost ticket transaction commits (`after_commit`), so a caller that wraps
the call in its own transaction (OIDC resume, sign-up finalization) never hands a rolled-back
session to the browser. The Rails session id is rotated immediately after the issuance savepoint;
it grants nothing by itself.

`establishment:` has exactly two values:

- `:root_login` — a new Base Browser Session. Checks and records the cooldown anchor.
- `:rp_session` — a relying party's local session derived from an existing root login (the
  `OidcCallback` RPs). Neither checks nor records the anchor.

There is no bypass flag. Sign-up handoff, MFA completion, OIDC resume, limit resolution, social
completion, and selector completion all pass the same checks.

### Results

The issuance boundary returns `status: :success` only for a committed session. A full limit returns
`:session_limit_pending` with nothing issued. An OIDC-started Auth ceremony returns
`:authentication_evidence_recorded`: credential evidence is not a session. `SignInResult` maps each
status to one meaning and exposes `proceed?` for the two that continue the sign-in sequence; no flag
modifies a success.

### Pending state

The verified `*SignInFlow` in `SESSION_LIMIT_PENDING` is the only pending authority. The browser
holds it through the flow locator (public id plus nonce digest) in its Rails session. Session-limit
pages resolve the actor from that flow, never from a principal id in the session or the request.
The Base OIDC resume keeps its `ClientSessionLimitResolutionTransaction` challenge; the Base social
path uses the flow locator on the Base host that ran the completion. Cancelling fails only that
flow. A pending flow does not block other sign-ins of the account.

### Local Auth credential results

Base creates the actor-specific sign-in flow and retains its browser nonce before admitting a
local Auth ceremony. Auth stores the admission purpose, binds the verified principal and records
the authentication method, original event time and authentication context. Auth does not call the
root issuance boundary. Its POST handoff returns an opaque result to Base's POST completion.

Base validates the browser nonce, flow, actor, surface, result digest and generation, delivery
deadline, and Auth continuity under the existing actor-before-ticket lock order. The existing
`log_in` boundary remains the issuer. Flow finalization and Auth completion share its outer ticket
transaction. Emergency evidence on org retains the Emergency context; app/com accept Normal
evidence through their existing token contracts.

A result's short transport deadline bounds receipt by Base. If that receipt reaches the session
limit, the durable `SESSION_LIMIT_PENDING` flow and its existing `expires_at` become the authority
and deadline for Base's limitation ceremony. Resuming that accepted pending flow does not require
the expired transport code, renew either deadline, or replace the authentication event time. It
still validates the Base nonce, active Auth evidence, principal, flow deadline and final issuance
constraints. Auth redirects this pending local limitation to Base.

After finalization, replay can only return the browser already holding the issued session to the
success page; it cannot issue a token. If the post-commit response was lost and the browser lacks
that session, completion refuses with conflict. Recovery requires a new Base entry and remains
subject to the login cooldown; result possession alone never recovers a Browser Session.

### Credential changes and unfinished authentication results

Credential security transitions acquire the actor lock before ending owned unfinished local
admissions or expiring authenticated OIDC transactions. Their surface ticket transaction also
revokes Auth continuity and cancels open APP OIDC capacity resolutions. Expiry is shortened using
the writer clock; result digests, generations and original authentication times remain history.
Consumed or Base-finalized transactions remain unchanged. Existing flags still decide which root
sessions are retained.

OIDC result transport expires at the earliest of its short delivery deadline, authorization
transaction deadline and login challenge deadline. Result matching uses the stored generation as
a positive integer and compares the exact digest; an oversized legacy transport expiry does not
make an expired parent valid. Re-display and retry preserve the original authentication time.

Base OIDC completion on APP, COM and ORG acquires the actor lock before the authorization transaction
lock, matching credential transitions and final issuance. APP capacity resolution rejects an
expired or mismatched parent before selecting a session for revocation. Its root promotion runs
inside the authorization transaction's finalization, so expiry rejection occurs before issuance.
This contract does not imply atomicity across principal, ticket, audit and transport databases.

`RESTRICTED` tokens are no longer issued. The resolver authenticates only `ACTIVE`, unexpired,
unrotated tokens, so an existing `RESTRICTED` row and its cookies authenticate nothing and are
refused by refresh as before.

### Cooldown

The cooldown blocks a new root login for 30 seconds after the previous root login of the same actor
on the same surface was established. The anchor is the newest `root_login_established_at`, read on
the writer inside the issuance transaction. Signing out does not clear it. Failures, pending or
refused attempts, callback retries, refresh, step-up, and RP sessions do not write it, so repeated
refusals do not extend the wait. A refusal answers `429` with `Cache-Control: no-store` and the
surface's Base `/sign` entry as the way to start again. The response must not disclose that the
account exists, that it signed in recently, or when: the message is generic, and `Retry-After` is
always the full cooldown window, never the time remaining since the previous login.

### Uniqueness and replay

A partial unique index on each `*_sign_in_flows.token_id` keeps one flow from binding more than one
session. OAuth state, authorization codes, ceremony results, and flows stay one-shot; nothing here
makes a used callback reusable.

### Sign-out

A database failure while resolving or revoking the current session propagates. Sign-out reports an
idempotent success only when the session is genuinely absent or already revoked.

## Consequences

- Existing `RESTRICTED` rows stop authenticating at deploy and expire through their 15-minute
  `discard_at`; no data migration revokes them. Rows written before this change have no
  `root_login_established_at`, so the first root login after deploy is not refused by the cooldown
  on account of earlier sessions. Token existence or `created_at` is never used to backfill it.
- com and org Base OIDC resume enforce the one-session limit; with no Base limitation ceremony on
  those surfaces, a full limit is refused with `403` instead of exceeding the limit.
- RP sessions minted by `OidcCallback` still count toward the active limit, as before. At a full
  limit the RP refuses instead of issuing a restricted session.
- The success audit is written after commit by the best-effort `AuthenticationAuditWriter`; there is
  no transactional outbox, so a committed login whose audit write fails has no `LOGGED_IN` record.
- On Auth, guardrail and checkpoint run after the root login has committed. Today they hold no
  blocking evaluator beyond what the final boundary already checks (`login_allowed?`, the limit).
  Adding a blocking pre-establishment check there requires moving issuance after it first.
- Rollback must not restore restricted issuance. If the change has to be withdrawn, stop new
  sign-ins rather than reintroduce the placeholder.

## Related

- `adr/base-auth-ceremony-and-seven-rp-boundary.md`
- `adr/session-reset-on-privilege-transition.md`
- `adr/social-login-cooldown-and-one-shot-completion.md`
- `.agents/harnesses/rules/project/session-issuance.mdc`

## Unified implementation amendment (2026-10-06)

The Unified Implementation Plan partially supersedes the pending-session portion of this ADR.
`SESSION_LIMIT_PENDING` is no longer a sign-in authority. Capacity is evaluated only while the
parent is in `SESSION_ISSUANCE_PENDING`; when capacity is full, a realm-local durable
session-limit-resolution transaction is issued as a child of that parent. The parent remains in
that state while the child is open or resolved, and the same parent retries root issuance after a
selected session is revoked.

The child is bound to the parent flow, actor, browser ceremony, realm, and OIDC authorization
transaction where applicable. It has its own row-locked named transitions, database-clock expiry,
terminal facts, retention hold, and actor-owned session selection. It is not authentication
evidence and cannot create a session by itself. The existing establishment point, cooldown,
actor-before-ticket lock order, post-commit cookie behavior, and prohibition on restricted root
sessions are **retained**.
