# First-Party Sign-Out Commits at the OP; Separated RP Stores Receive Back-Channel Logout

## Status

Accepted (2026-10-16); **amended 2026-10-24 and implemented locally 2026-10-25; amended again
2026-10-26 and implemented locally 2026-10-26/27** (see the last sections). Where the 2026-10-26 amendment and an
earlier section disagree, the 2026-10-26 amendment wins. The 2026-10-22 owner decisions
are recorded here as the current WU-39 documentation contract. It takes effect only for a
first-party relying party that has been activated with its own session store under the OP/RP
persistence separation (release R5). Until a client is so activated, and for every client during
releases R1 to R4, `adr/first-party-sign-out-shared-database-without-backchannel-logout.md` remains
fully in force.

The direction is already a user decision: OP/RP persistence separation, and sign-out that succeeds
when the OP revocation and its outbox commit, independent of any RP acknowledgement or cookie purge
(user decision D-08, confirmed 2026-10-16). This ADR records the contract change that decision
requires. It changes no code, schema, registration or deployment, and claims no implementation or
test result.

On acceptance it supersedes, for separated first-party RPs only, these parts of
`adr/first-party-sign-out-shared-database-without-backchannel-logout.md`:

- Decision 1, that RPs decide acceptance by reading the parent on the realm Ticket writer;
- Decision 2, that one transaction revokes the parent and every RP session row;
- Decision 4, that no Back-Channel Logout is used between the IdP and first-party RPs;
- the condition that every authentication path reads the parent, replaced by the bounded residual
  acceptance stated below;
- the "Do not reintroduce without a new ADR" items for `backchannel_logout_uri`, a delivery queue or
  ledger, and sibling RP sessions that end on notification. This ADR is that new ADR.

Everything else in that ADR stays in force: Decision 3 (confirmed COMMIT is the point of no return),
Decision 5 and its 2026-10-13 amendment (authority is separate from identification; no
single-service sign-out), Decision 6 (priorities), Decision 7 (the standards-shaped browser flow,
GET never mutates, a CSRF-protected POST confirms, exact registered return URIs), and the
constraints that ADR set for any future BCL extension.

## Context

The shared-database ADR rests on one premise: every first-party RP session row lives in the same
realm Ticket database as its parent, so the IdP can revoke them in one transaction and every RP
request can read the parent. That ADR names the condition for reopening it: an RP whose sessions the
IdP cannot revoke in the parent's transaction, such as a first-party service with its own session
store and its own deployment.

The OP/RP separation makes every first-party RP such a service. Its purpose is that compromising one
RP database cannot mint OP credentials, revive a revoked grant, authenticate with only a local
session, or read another surface's private state. To achieve that, each RP cell gets its own local
store and its own role-limited credentials, and has no OP or Zenith database login. An RP can then
neither be revoked inside the OP transaction nor read the parent on each request. The premise of the
shared-database ADR no longer holds for those cells.

## Decision

1. **The OP commit establishes sign-out.** In the realm OP database, one transaction revokes the
   authenticated current root, invalidates its grants, Refresh authority, pending Codes and delivery
   receipts, and records the logout flow, its participants, a one-time browser receipt and the
   outbox events. Confirmed COMMIT is the point of no return, unchanged from the earlier ADR. A lost
   response is resolved by re-reading the OP writer's recorded outcome.
2. **Separated RPs end their sessions by Back-Channel Logout.** After COMMIT, a worker outside the
   request delivers an OpenID Connect Back-Channel Logout Token to each registered participant. The
   token is signed by the realm OP, names the exact client as audience and the exact OP `sid`,
   carries the logout event and a unique `jti`, and has no `nonce`. Endpoints come only from the
   fixed client registration. Delivery never decides whether sign-out succeeded.
3. **Delivery is durable.** Outbox rows are written in the OP transaction. Queue messages carry
   event IDs only, never tokens, cookies or keys. Workers use bounded leases and retries, and a
   database sweep recovers events if the queue is lost. No outbound HTTP call runs while a database
   transaction or row lock is held.
4. **Receivers commit before they answer.** A receiver validates the token without side effects,
   then in one local transaction records the replay receipt, upserts and locks the binding for that
   exact issuer, realm, client and `sid`, marks it revoked, and invalidates the local session. It
   answers 200 only after that commit, or when the same event was already committed. A persistence
   failure is a retryable non-200. A `sid` the receiver has never seen still gets a revoked binding
   (a tombstone), so a later callback for that `sid` is refused. A revoked binding is never cleared
   or reused.
5. **Residual acceptance is bounded.** Between the OP COMMIT and the receiver's commit, a separated
   RP may still accept an Access JWT it already holds, but never beyond that JWT's `exp` (currently
   300 seconds plus 30 seconds of leeway). No Refresh, Code exchange or receipt redelivery succeeds
   after the OP COMMIT. This is the explicit upper bound and remedy that the earlier ADR required of
   any path that cannot read the parent.
6. **One path per client.** A client uses this contract if and only if it is activated as a
   separated cell. There is no dual mode in which one client both reads the parent and receives BCL,
   and no fallback to the shared path for a disabled or failed cell; such a cell stays closed.
7. **Declarations match behavior.** A separated client's registration declares its back-channel
   logout URI with `sid` required, and discovery advertises back-channel logout support only when
   every advertised first-party client implements a receiver. Nothing advertises it before that.
8. **Browser completion stays separate from delivery.** The Base completion page reports that OP
   sign-out is established, even while other cleanup is pending. Each RP's cookie-purge or return
   step is bound to the flow, the client, the browser and the matching old local session, so it can
   never remove a newer login. A purge response being sent is not proof that the browser deleted the
   cookie.

## Do not

- Do not make the sign-out result depend on an RP acknowledgement or a cookie purge. The redirect
  after it waits only for the bounded first delivery attempt of the 2026-10-26 amendment, never for
  an acknowledgement.
- Do not let an RP answer 200 before its revocation commit.
- Do not take a delivery endpoint from a request, a token or a grant row instead of the fixed
  registration.
- Do not restore a revoked root, reopen a revoked binding, or reset an outbox to recover service.
- Do not add a single-service sign-out; the 2026-10-13 amendment stands.

## Consequences

- An RP database compromise no longer exposes OP signing keys, OP or Zenith data, or other cells'
  sessions. This is the reason for the change.
- Sign-out at other RPs is no longer instantaneous. It ends at the receiver's commit or at Access
  JWT expiry, whichever comes first. The window is bounded, not zero.
- The system gains durable delivery: outbox rows, workers, a sweep, replay receipts and tombstones.
  These are new failure points, but none of them can turn a committed sign-out into a failure.
- Tombstones are retained. Garbage collection would need proof that every callback, Code, token and
  receipt horizon for the `sid` has closed, and is not part of this decision.
- Logout rows written under the shared-database contract stay as history and are not reinterpreted
  as current authority.
- Documents that describe current behavior, including `docs/security/logout-session-management.md`
  and `docs/security/logout-sequence.md`, are updated when the implementation changes, not by this
  ADR.

## Alternatives considered

- **Keep the shared database for sign-out only.** It keeps instantaneous revocation, but an RP
  process would again need OP database credentials, which defeats the separation.
- **Per-request introspection from every RP to the OP.** It removes the residual window, but couples
  every RP page to OP availability and adds a call to every request. Rejected for ordinary
  authentication; narrow current-authority checks remain where a domain contract requires them.
- **Synchronous BCL from the sign-out request.** Rejected for the reasons the earlier ADR gives:
  sign-out would wait on the network and need partial-delivery states. *Superseded in part by the
  2026-10-26 amendment:* a bounded first attempt is made from the request after COMMIT; the sign-out
  result still never depends on it, and the durable outbox still owns every retry.
- **Front-channel logout or redirect chains across RPs.** Rejected for the same reasons as in the
  earlier ADR; they depend on the browser completing the chain.

## Standards and assurance limits

OpenID Connect Back-Channel Logout 1.0, OpenID Connect RP-Initiated Logout 1.0, RFC 7009 and
RFC 8725. This ADR claims no conformance and no implementation. Acceptance would establish the
contract only; delivery, race, restore and role-isolation evidence belong to the release that
implements it.

## Amendment (2026-10-24)

Owner decisions of the 2026-10 authentication cycle; implemented locally 2026-10-25.

- **Scope.** With process separation withdrawn (D-19, D-20, D-35), every first-party RP is a
  standard OIDC RP with Back-Channel Logout; there is no per-client activation. The "one path per
  client" condition is satisfied by removing the pre-R5 OP-chain path per surface (D-108).
- **Residual bound (item 5).** The Access JWT bound is `CoreBrowserCredentialContract::ACCESS_TTL`
  (10 minutes) plus 30 seconds, not 300 seconds; the TTL is not shortened (D-111).
- **Durable outbox kept, delivered through Solid Queue.** Every stop writes one outbox row per
  participant in the stop transaction; after COMMIT `OpOutboxDispatchJob` is enqueued on Solid
  Queue, and a recurring task re-enqueues rows left without a final state until each reaches 200,
  400 or the retry deadline (D-117, D-121). HTTPS only, no redirects, explicit timeouts and
  connection-time SSRF protection apply.
- **Receiver.** `POST /oidc/closures` keeps `ActionController::API` as its parent (no
  `allow_browser`, forgery protection or session) as a scoped exception, with FQDN gating and rate
  limiting added explicitly; only the Logout Token signature and claims are trusted (D-118).

## Local implementation amendment (2026-10-25)

WU-15, WU-16 and WU-22 implement this contract in the current checkout. Each realm OP now writes a
cause/scope authority-stop record, target and epoch children, one BCL participant per revoked grant,
and the optional browser receipt in the same transaction as revocation. The one committer covers the
nine accepted causes and is the only root/grant revocation writer. Solid Queue enqueue occurs after
commit; the durable participant is dispatched by a recurring sweep if enqueue is lost. Each of the
twelve first-party RP cells exposes `POST /oidc/closures`; its receiver verifies the fixed issuer and
audience, then commits the replay receipt, absorbing `sid` tombstone and matching local-session
revocation before 200. The sender uses HTTPS, pins a validated public DNS answer, applies bounded
timeouts and never follows redirects.

**BX-4 implementation choice.** The accepted response table leaves 3xx and 413 unclassified. This
implementation treats all redirects as permanent endpoint misconfiguration and alerts; it never
follows the redirect because a registered endpoint is fixed and following it would change the
security boundary. It treats 413 as permanent endpoint/WAF misconfiguration and alerts because the
Logout Token request body has a fixed, bounded shape; retrying the unchanged request cannot resolve
a stable size limit. The existing table remains in force for 200, 400, 401/403, 404/405/410, 429,
5xx and transport failures. Participant rows retry transient failures until BX-10 and then become
`expired`; each row otherwise ends as `acknowledged` or `refused`.

The implementation is local code and test-database evidence only. It does not claim deployment,
external-RP delivery or OIDC conformance. Current verification is recorded in
`evidence/2026-10-25-wu15-16-22-op-authority-stop-6B3Q.md`.

## Amendment (2026-10-26)

Owner decisions of 2026-10-26 (sign-out suite redesign; audit in the cycle working document
`ten.md`). Implemented locally 2026-10-26/27 (SO-1 … SO-5 and the quality fixes;
`evidence/2026-10-26-sign-out-so5-acceptance-G5P8.md`, `evidence/2026-10-27-sign-out-quality-fixes-H8M2.md`,
`evidence/2026-10-27-acceptance-partials-V8M2.md`).

- **Every first-party RP is a standard RP this cycle** (held later the same day: the owner judges the
  open WU-18 questions after the sign-out implementation; until then sign-out is built on the OP-chain
  path every first-party client runs today). The OP-chain path and the runtime-role
  switch are removed in this cycle (WU-18c … 18e brought back; supersedes the deferral D-175 for
  them). Each first-party RP keeps its own local session in its `rp_*` database and ends it on
  Back-Channel Logout. Item 6 ("one path per client") and the 2026-10-24 "Scope" bullet then hold
  for every client.
- **RP clears itself first (unchanged, D-33 (2)).** The originating RP ends its own local session
  and cookies before it redirects to `end_session_endpoint`. The return to the RP changes no
  authority and deletes nothing, so a delayed return cannot end a newer login. Cancel at the OP
  means signed out of that RP only.
- **Bounded first delivery attempt from the request** (deferred the same day to WU-18; see the
  last bullet). After the OP COMMIT and before the
  post-logout redirect, the request makes one delivery attempt to each participant of that stop:
  - the attempt claims each participant's lease in a short OP transaction, exactly as
    `OpOutboxDispatchJob` does, so the job and the request never both send one attempt;
  - Logout Tokens are signed before any network call; the HTTP calls run in parallel with no
    database transaction or row lock held and no Active Record use inside the parallel work;
  - one total deadline for the whole attempt (initially 3 seconds, measured on a monotonic clock);
    each call's open and read timeouts are cut to the time left;
  - each outcome is recorded as that participant's attempt in its own short transaction, with the
    same classification and backoff as the job; a participant without an outcome when the deadline
    passes keeps its lease until expiry and is then retried by the job;
  - the redirect follows when every call has answered or the deadline has passed. The sign-out
    result and the redirect never depend on an acknowledgement.
  Rationale: RP-Initiated Logout 1.0 §2 and §3 describe notifying the RPs before the post-logout
  redirection (descriptive text, no requirement keyword); open-source certified OPs send from the
  logout request and do not let a failure block the redirect (node-oidc-provider
  `lib/actions/end_session.js`, Keycloak `AuthenticationManager.browserLogoutAllClients`, read
  2026-10-26). Back-Channel Logout 1.0 sets no timing.
- **HTTP 204 is an acknowledgement** of a Logout Token, like 200 (Back-Channel Logout 1.0 §2.8).
- **The one-time browser receipt is removed.** Decision 1's "one-time browser receipt" and
  Decision 8's Base completion are replaced: the completion page belongs to the originating RP
  (`GET /sign/out/completion`, shown once). The OP's `/sign/bye`, its session key and the
  `*_authority_stop_browser_logouts` tables are removed by a new migration. The authority-stop
  record, its targets and participants remain the authority and the audit trail.
- **End-session refusal.** A request carrying a verified `id_token_hint` is refused with HTTP 403
  and the plain text "This action is not allowed." / 「禁止された振る舞いです」, with no state
  change and no redirect, when the browser has no current OP session, or when the hint's `sid` does
  not identify a grant of the browser's current root (RP-Initiated Logout 1.0 §2: such a request
  SHOULD be treated as suspect and MAY be declined).
- **The OP stops the browser's current root, never a guessed one.** The target is the browser's
  current OP session; a hint only has to match it. If no root can be stopped, or the outcome cannot
  be confirmed, the OP reports that and does not redirect as if signed out.
- **The RP discards its own tokens; it neither writes OP authority nor calls the revocation endpoint
  during sign-out.** The OP stops the root and its grants on confirmation (RFC 9700 §4.14.2 places
  revocation on logout with the authorization server; RP-Initiated Logout 1.0 sets no RP revocation).
  A cancel at the OP leaves that RP's grant alive until it expires; accepted for now and revisited
  with WU-18.
- **Discovery advertises Back-Channel Logout** (`backchannel_logout_supported`,
  `backchannel_logout_session_supported`), since every first-party client has a receiver; item 7
  holds. The ID Token `sid` is the `sid` of the Logout Token; no random substitute is issued.
- **Without a usable redirect the OP shows its own signed-out page** (no `id_token_hint` or no
  registered `post_logout_redirect_uri`; RP-Initiated Logout 1.0 §3), shown once, replacing
  `/sign/bye`. The RP cookie-purge endpoint of item 8 is removed.
- **No delivery from the sign-out request this cycle.** The bounded first attempt above is deferred
  to WU-18: on the OP-chain path first-party receivers change nothing, and the attempt needs a
  process-wide bounded executor, a DNS timeout and a deadline covering token preparation and outcome
  recording before it can be bounded at all. Until then delivery is the after-commit job, as in
  Decisions 2 and 3, and the "Do not" bullet holds without the exception.
