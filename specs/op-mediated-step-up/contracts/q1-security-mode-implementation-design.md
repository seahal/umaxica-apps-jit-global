# Q-1 security mode transition: RP owner boundary

Status: implementation design accepted by the owner on 2026-11-05. Revision 13 and the accepted
authentication-security-mode ADR remain authoritative; inventory and verification gates below still
apply.

## Current behavior and conflict

`Base::App::Identity::Mfa::ChallengesController` resolves a canonical Client from the local RP
session, but `current_session_token` is nil for that session. ADVANCED → NORMAL therefore refuses
with 422 before the existing Step-Up verifier runs. The NORMAL → ADVANCED path can update Zenith,
then invokes `CredentialSecurityTransition` separately. That service requires a ClientToken to
identify the current session, changes OP sign-in and token records, and records an audit after those
changes. A failure after the Zenith mode commit can leave a changed mode with incomplete revocation.
A local RP session must never be treated as that root token.

The accepted revision 13 requires O-10: actor lock, OP device/root/grant locks, evidence and policy
recheck, Zenith commit while OP locks remain held, then finish the read-only OP transaction.
`CredentialSecurityTransition` cannot simply run inside that OP transaction: it writes OP records,
and its own lock ordering and cross-database completion would violate the read-only boundary. Nor
can the RP look up the OP root directly. The existing all-session identity-stop mechanism advances
the actor epoch and delivers a durable event after Zenith commit, but its scope is all sessions
only. It cannot preserve the current session during the existing upgrade behavior
(`revoke_current: false`); silently logging out that session would change an existing contract.

## Required owner operation

Expose an authenticated Base APP owner operation that accepts the verified Access JWT and a
registered client assertion; its owner resolves the actor, root and grant, never an actor or root
selected by the browser. Bind an operation ID and immutable request identity to actor, requested
mode, grant and event. Before a principal mutation, verify RP evidence and identity, lock the Client
first, recheck the current mode, account eligibility and policy, and count active passkeys under the
same lock when entering ADVANCED. Start the OP transaction without OP row locks and then acquire the
device, current root and affected grant in that order after the actor lock. Recheck the evidence,
request binding and freshness immediately before committing. Keep the OP transaction read-only and
open through the actual Zenith commit. Prohibit an enclosing transaction that defers that commit.

The mode write and an operation-specific durable outcome and revocation intent must commit together
on Zenith. The intent must be idempotent, contain no credentials and permit recovery after an
unknown commit acknowledgement. Only after releasing locks may the owner deliver revocation;
delivery failure must leave an observable, retryable record and must not be reported as completed. A
replay with the same operation ID and different input is a conflict. An uncertain Zenith commit is
resolved against a fresh writer connection and the durable outcome; inability to determine the
outcome remains indeterminate. Session revocation, pending sign-in and ceremony invalidation,
Step-Up evidence invalidation, back-channel logout and authoritative audit are all part of
completion, not best-effort follow-up hidden from the caller.

## Unresolved safe-retention invariant

The existing transition treats downgrade as revoking the current session and other sessions, and
upgrade as retaining the current root while revoking other sessions.
`IdentityAuthenticationStopRecorder` and `OpIdentityEventInvalidator` currently support only an
all-session epoch cutoff. Advancing the actor epoch invalidates old roots, including the current
one; a post-commit attempt to update that root's epoch independently may race revocation, token
rotation, stale grant replay or a second transition. Conversely, not advancing the actor epoch
permits authority from other old roots until asynchronous invalidation arrives. The existing RP
access verifier authenticates its local session and JWT without an immediate OP read, so the effect
of delayed back-channel logout on still-live RP access must be included in the solution.

Before enabling the writer, specify and test an explicit preserve-current protocol: how the
originating OP root and grant are bound to the Zenith intent, how epoch or equivalent authorization
is made current without accepting an old or replaced root, how later issued roots are excluded from
a delayed stop, how old RP sessions fail closed while delivery is pending, and how receipt/retry and
partial delivery are recovered. Also prove how the Zenith operation result and audit are resolved if
OP delivery or the principal COMMIT acknowledgement is lost. A blanket all-session stop is not an
implementation shortcut for the existing upgrade contract.

## Preserve-current candidate for an upgrade

**Rejected as written:** the epoch-retag candidate below predates the check against
`AuthenticationEpochValue` and D-165. That value states the actor epoch advances only for identity
stop, and a root issued before a stop never becomes current again. Advancing that epoch for a mode
change and rewriting an existing root's issuance epoch is inconsistent with the accepted invariant.
A mode-specific generation with its own explicit preservation semantics, or an expressly reviewed
amendment of the identity epoch contract, is required. The discussion below records the race and
delivery questions for that redesign; it does not authorize retagging the identity epoch.

A candidate protocol retains the same root, rather than minting a new authenticated session. A
server-generated transition ID and monotonically increasing cutoff epoch belong to a single actor
and are committed with the Zenith mode outcome and an explicit pending-delivery record. The
initiating grant SID and the OP device/root public references are obtained only from the verified
owner request and are captured in that record. The owner operation rejects another mode transition
while one is pending. The operation does not claim success until the delivery and the required audit
are confirmed.

After the Zenith commit and after releasing the original OP locks, an idempotent OP receiver locks
the actor's device sessions, roots and affected grants in a deterministic documented order. It
advances only the captured root and its still-valid same-root grants to the new epoch, provided the
device is usable, the root remains current and all identity/session/generation bindings still match.
It revokes the other roots below the cutoff, invalidates their grants and pending ceremonies, and
records a receipt and back-channel logout deliveries in the same OP transaction. If the captured
root was rotated, signed out or rebound, the receiver must not retain a substitute: fail closed,
revoke the old authority and return an explicit unsuccessful or indeterminate transition result.
Roots created at the new epoch after the commit must not be selected by the old cutoff. Duplicate
event delivery verifies the exact receipt and does not repeat the mutation. A later mode change
cannot overtake an earlier pending delivery.

The accepted separated-RP sign-out ADR explicitly allows old Access JWTs to remain accepted between
OP stop and the RP receiver commit, bounded by token expiry and leeway; its 2026-10-24 amendment
states ten minutes plus 30 seconds. It rejects per-request OP introspection for ordinary
authentication. Q-1 should reuse that established stop and durable back-channel delivery contract
instead of assuming an instantaneous RP barrier. Zenith-to-OP event delivery can exceed that
interval, so the bound from the Zenith commit depends on an additional fact: after the actor epoch
advances, no old-epoch token may be minted or redelivered.
`OidcTokenExchangeCoordinator#refresh_actor_guard` and `#lock_actor_and_root` acquire the actor lock
and enforce epoch equality before issuance; `OidcAccessTokenAuthenticator` rejects a stale root. If
every remaining issuance, refresh and redelivery path is proved to have the same guarantee, then an
old token must have been issued before the Zenith epoch commit and its existing TTL/leeway gives a
bounded residual even while OP delivery is delayed. This remains an inventory and concurrency-test
obligation, not yet a verified guarantee. The response must still report OP stop delivery as
unconfirmed until the durable stop exists.

A plausible partition is the original device lineage as the retained unit: hold the actor lock while
recording its authenticated device/root/grant binding and incrementing the actor epoch; on delivery,
revalidate that exact device's current root and exclude the whole preserved device from stale-device
revocation. If the current root changed, do not promote an unseen replacement; resolve the
transition as unconfirmed and remove only verified stale authority. For other devices, restrict
grants and roots by the committed cutoff before invoking the stop primitive. New-epoch grants on an
old device require the same protection as a newly issued root; the current primitive's device-wide
grant scan does not provide it. Device-granularity preservation is a candidate, not an approved
change of `revoke_current` semantics, until the root rotation lineage and its grants are reconciled
with the current `CredentialSecurityTransition` implementation.

The first 2026-11-04 rotation probe did **not** reproduce the previously suspected existing
transition cascade: `currently_usable_at` explicitly excludes rows with `rotated_at` set, so an
ordinary predecessor does not enter `CredentialSecurityTransition`'s `not_revoked` enumeration. The
probe stopped on that prerequisite before invoking the transition. Treat the earlier
ordinary-rotation concern as disproved, not as an observed bug. A different same-device concurrent
or corrupted lineage would require its own reachable-path evidence.

The preserved-device exclusion is required even for normal rotation history: unlike
`CredentialSecurityTransition`'s `not_revoked` scope, `OpIdentityEventInvalidator#stale_roots`
selects every root below the cutoff, including rotated predecessors. If the candidate first advances
the current root and then feeds those predecessors to the existing `stop_principal`,
`OpAuthorityStopCommitter#lock_root_chain` selects all live grants for their device and can revoke
the retained current grant. That is a consequence of the proposed reuse of the existing epoch
receiver, not an observed defect in the current credential-transition path. A retained-device
operation therefore needs its own explicit target scope and receipt semantics; it must not label an
exception to the cutoff as an unqualified `all_roots_of_principal` stop.

The candidate is **not yet safe to activate** for a separate concrete reason.
`OpAuthorityStopCommitter#lock_root_chain` selects all live grants for a stopped root's device
session, without filtering the grant epoch. A delayed stop of an old root could therefore revoke a
newer grant on the same device, including one meant to be retained. The receiver must partition
device/root/grant targets without disturbing the preserved device lineage or newer epoch, and must
coordinate concurrent root rotation and sign-in. The existing stop scopes and
`IdentityAuthenticationStopRecorder` do not encode a preserve-current device. Prove the target
selection, receipt and retries on independent connections before wiring the mode change. If the
preserved root cannot safely be advanced, fail closed without inventing a replacement login.

## Verification

Use public requests and real persisted records to cover each mode direction, the two-passkey
boundary, authorization failure and session/actor substitution. Exercise both winners of revocation
versus principal commit on independent connections, expiration while waiting, rollback, unknown
commit, delivery failure/retry, root rotation during preservation, no stale session use before
delivery and no revocation of a newer login. Check audit failure and replay without duplicate
transition. Reconcile `docs/mermaid/idp-state-machine-transition-inventory.md` and the owning
diagrams with the final implementation. The global O-10 reverse-lock inventory remains an activation
prerequisite.

## Alternative using a mode-transition barrier (not yet implemented)

A possible way to avoid changing identity-epoch semantics is an explicit, separate mode-transition
generation and pending state on the Client's Zenith writer. Under the Client lock, capture the
verified retained device and root, snapshot the other root/device targets using a documented
actor-first serialization guarantee, write the mode change, the transition generation, a durable
delivery intent and the operation outcome in one Zenith commit. The retained identity epoch is never
rewritten. The owner OP transaction remains read-only and holds the authenticating chain through
this commit.

While the generation is pending, every OP issuance, refresh, redelivery and owner-authority check
must re-read the Client under the existing actor-first lock and refuse non-retained old authority.
The captured retained root may continue only if its current-device pointer, identity, generation and
authentication context still match; do not promote a replacement root. RP-local requests may still
accept previously issued JWTs until the established separated-RP expiry bound or a committed logout
receipt. No new token may be minted for an excluded root after the barrier commit. Implementing this
requires an exhaustive inventory and behavioral tests of _every_ issuance and owner path; current
evidence about two coordinator methods is insufficient to establish the invariant. It must also
ensure that in-flight issuance holds the same Client lock through its OP commit, so a token cannot
appear after the snapshot under old authority.

After the principal commit, the idempotent OP delivery must stop precisely the captured non-retained
device lineages using the existing root-stop/BCL machinery, preserving the retained lineage and
excluding new logins. A target with a changed device/current-root binding is an explicit conflict,
not permission to stop a newer device or skip an old target. Its durable per-target progress,
reconciliation and `AccountAccessEvent`/security audit must survive a lost enqueue, receiver failure
and unknown commit. The barrier is removed only by a confirmed, idempotent completion transition; if
delivery cannot be confirmed it remains active and is visible to the caller. Serialize or reject
subsequent transitions while pending. An independently committed new login after the barrier must be
classified explicitly so that a delayed old intent cannot revoke it.

This is a candidate architecture, not a claim that the existing OP APIs provide such a barrier or a
sufficient snapshot. Its storage ownership, state-machine transitions, stop-target granularity and
cross-database commit/error behavior must be specified and verified before implementation or
controller activation. In particular, do not use a time delay as proof of delivery or silently leave
the barrier uncleared.

## Candidate request and persistence shapes for owner review

These are a concrete candidate for the separate pending-delivery barrier above, not an accepted
shape or implementation authorization. They avoid changing `authentication_epoch`: that value
remains owned by identity stops, and no old root is retagged as current.

Before (current request and relevant authority rows):

```text
PATCH /identity/mfa/challenges
{"user":{"security_mode_id":7}}

clients: security_mode_id, authentication_epoch
client_tokens: device_session_id, authentication_epoch
op_app_grants: device_session_id, authentication_epoch
```

After (candidate browser request):

```text
PATCH /identity/mfa/challenges
{"user":{"security_mode_id":7},"operation_ref":"<uuid>"}
```

The browser supplies only the requested mode and an idempotency selector. The server binds the
operation reference to a canonical request digest. The Access JWT, Step-Up event, actor, current
root, grant `sid`, device and local RP session are resolved from the verified RP request and OP
records; none is selected by request fields.

After (candidate APP Zenith persistence):

```text
client_security_mode_transitions:
  operation_ref: uuid NOT NULL UNIQUE
  client_id: bigint NOT NULL FK
  prior_mode_id: bigint NOT NULL FK
  requested_mode_id: bigint NOT NULL FK
  retained_device_ref: string(21) NOT NULL
  retained_root_ref: string(21) NOT NULL
  retained_grant_ref: string(21) NOT NULL
  rp_session_ref: string NOT NULL
  step_up_event_ref: string NOT NULL
  request_digest: char(64) NOT NULL
  state_id: reference NOT NULL  # pending, completed, reconciliation_required
  created_at: timestamp NOT NULL

client_security_mode_transition_targets:
  operation_ref: uuid NOT NULL FK
  target_device_ref: string(21) NOT NULL
  target_root_ref: string(21) NOT NULL
  state_id: reference NOT NULL  # pending, stopped, reconciliation_required
  UNIQUE(operation_ref, target_device_ref)
```

The parent row is the durable operation receipt and issuance barrier. Target rows are an immutable
snapshot of other device lineages captured under the OP locks while the Client actor lock is held.
They are not authority: the OP stop receiver must recheck the exact device/root relation under
`device → root → grant` locks. The initiating device lineage is retained as a unit because the
current authority-stop primitive revokes all live grants belonging to a stopped device. Its root and
grant are revalidated before the transition is marked complete. A target that changes unexpectedly
becomes `reconciliation_required`; it is never replaced with a newer root and the issuance barrier
stays active.

While any transition for the Client is `pending` or `reconciliation_required`, every root login,
refresh, RP grant issuance and owner-authority path must refuse while holding the same Client-first
lock. This freezes the target set between the source commit and confirmed OP stops. After every
target has a durable stop receipt, the exact retained lineage is rechecked and the source operation
is marked `completed`. A lost Zenith acknowledgement is resolved by the exact operation reference
and digest on a fresh writer; an unknown result remains unavailable. OP stop retries use immutable
target rows and existing durable stop receipts. RP-local Access JWTs already issued for stopped
roots retain only the established bounded residual window.

The independent fields represent independent facts: prior/requested Security Mode, transition state
and per-target stop state use separate reference tables; no compound enum or positional tuple is
introduced. `operation_ref` is a replay selector, not authorization. Public IDs and event/session
references are historical bindings, not credentials. No JWT, refresh token, OTP, cookie, client
assertion or raw request is stored. The APP Zenith writer is authoritative for mode and transition
state; OP records remain authoritative for root/grant liveness and stop receipts.

Migration is additive and APP-only: create the two transition tables and explicit status reference
rows, add the unique operation and target constraints, and do not backfill old mode changes.
Preserve completed and unresolved transition records on rollback; dropping them is not a recovery
plan. Existing browser forms must render and submit an `operation_ref`; a missing value is refused
and the page must be reloaded. The source/API shape, partial unique constraint for one open
transition per Client, retention, audit-outbox linkage and exact retry behavior still need review.
In particular, the pending barrier is safe only after the complete root-login, refresh, grant
issuance and owner-authority inventory proves every relevant writer takes the Client lock and checks
it. That O-10 inventory is currently incomplete.

Approval requested: accept or revise these Before/After shapes before any migration, request-shape
change or controller/service implementation. This approval would authorize the shape only; the
listed issuance-path inventory, audit recovery and concurrency verification remain implementation
acceptance conditions.
