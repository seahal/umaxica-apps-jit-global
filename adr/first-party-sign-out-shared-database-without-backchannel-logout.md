# First-Party Sign-Out Is Committed in the Shared Database; Back-Channel Logout Is Not Used

## Status

Accepted (2026-10-13). User decision, confirmed by an escalation ruling on the same day.

This is a **target contract; the runtime is not yet migrated**. At commit
`4828aeedd141b54163236672890799b9b01128c2` the application still contains a Back-Channel Logout
(BCL) sender, receivers and declarations, and the missing authority check described below.
Acceptance of this ADR establishes neither implementation conformity nor that any test has run.

Supersedes, for first-party relying parties only:

- the sentence "sibling RP rows are not synchronously revoked" and the retained back-channel scope
  freeze in `adr/base-authority-and-self-rp-separation.md`;
- the back-channel RP entrypoint and the planned back-channel notifier layer in
  `adr/logout-primitive-and-composition.md`;
- the back-channel logout URI as a per-client binding in
  `adr/base-auth-ceremony-and-seven-rp-boundary.md`.

Everything else in those decisions stays in force, including authority-first logout, the
irreversible commit point, and "a hint identifies a session; it is not authority to end it" in
`adr/sign-neutral-entry-and-logout-target-authorization.md`.

## Vocabulary

- **IdP**: Base acting as OpenID Provider and OAuth Authorization Server. Other documents call the
  same role OP, AS or Authority.
- **RP**: a first-party relying party served by this application: Core, Warp, Edit, Palm, Tech and
  the Base Self-RP clients.
- **Parent**: the IdP Browser Session, that is, a Device Session and its current root token.
  Every RP session row belongs to exactly one parent.
- **BCL**: OpenID Connect Back-Channel Logout 1.0, in which the IdP posts a signed Logout Token to
  each RP server so the RP ends the session named by `sid`.

## Context

Sign-out started as a repository-specific design: short-lived access tokens, and a gate that
refuses to issue a new access token once the parent is revoked. To move closer to published
standards, BCL was added and then elaborated over several planning rounds. The plan grew a
request-owned sender with a time budget, retry rules, partial-delivery states, a stored delivery
outcome and acceptance-time measurement. `research/2026-10-13-first-party-backchannel-logout-rejected-design.md`
records that design and why each part followed from the one before.

Reviewing the plan against the code showed that the premise did not match this system:

1. **One application, one session store per realm.** Every first-party RP is a host-routed surface
   of this Rails application. RP session rows (`ClientRpSession`, `VisitorRpSession`,
   `OperatorRpSession`) live in the same realm Ticket database as the Device Session and root token
   they belong to. The IdP can change those rows directly and atomically.
2. **RPs already consult the parent.** A Browser RP request re-reads its RP row, the Device Session
   and the root token on the writer connection with caching disabled, and refuses a revoked or
   unusable parent (`BrowserRpAuthentication`). Refresh is refused the same way. Revoking the parent
   therefore already ends acceptance at every RP on its next request.
3. **BCL cannot do the remaining part.** What is left after server-side revocation is the cookie in
   the user's browser and any screen that is already open. BCL is server-to-server and touches
   neither.
4. **BCL adds failure where there was none.** A notification can time out or be refused, so the
   design needs partial states, a place to store them, wording to display them, a bound on waiting
   and a rule for retries. Sent from the request thread to receivers in the same process pool, it
   also holds a thread while calling itself.
5. **The existing BCL code is incomplete and defective.** Only the legacy end-session path sends.
   Receivers exist for Core (three realms) and Edit only, while all ten first-party browser clients
   and the discovery document declare BCL. The receiver consumes the token `jti` before the effect,
   can fall back from an RP `sid` to the root token and a parent logout, and returns 200 without
   checking the result.

The BCL specification does not exclude a deployment in which IdP and RPs share an application. The
reason for this decision is therefore not that BCL is inapplicable. It is that BCL is redundant
here and makes the outcome of sign-out depend on a network exchange that the system does not need.

## Decision

1. **The parent state is the single source of truth.** Whether a user is signed out is decided by
   the parent's state on its realm Ticket writer. RPs decide acceptance from that state on every
   request and every refresh, not from their own cookie or their own row alone.
2. **Sign-out is IdP-first and commits once.** A global sign-out revokes one authenticated current
   parent and, in the same database transaction, every unrevoked RP session row of that parent.
   The transaction contains no HTTP call, job enqueue or write to another database.
3. **Confirmed COMMIT is the point of no return.** After it, the parent is never restored, the user
   is not signed in again automatically, and no later failure is reported as a sign-out failure.
   Before it, nothing is revoked. A COMMIT whose response is lost is resolved by re-reading the
   persisted state, and is reported as indeterminate until that succeeds.
4. **No BCL between the IdP and first-party RPs.** The IdP does not send Logout Tokens to them and
   they do not expose receivers. The discovery document and client registrations must not declare
   BCL support. The existing sender, receivers and declarations are removed once it is confirmed
   that no party other than the IdP's own legacy path depends on them; they are not left in place
   as a disabled or dormant path.
5. **Authority is separate from identification.** The IdP revokes a parent only for the current IdP
   session that owns it. A challenge, a URL parameter or an `id_token_hint` never authorizes
   revocation by itself. An RP credential can end only that RP's own session; when the IdP has no
   matching session, sign-out ends the initiating RP session only and says so.
6. **Priorities.** IdP sign-out is mandatory. Cleanup at the initiating RP is desirable, and its
   failure neither changes the result nor triggers a retry or a new sign-in. For other RPs the
   guarantee is refusal at their next authentication check; removing their cookies and switching
   their open screens is best effort.
7. **The standards-shaped browser flow is kept.** The RP sends the browser to the IdP end-session
   endpoint, the IdP confirms, and the browser returns to an exactly registered URI. GET never
   mutates; a CSRF-protected POST confirms.

## Conditions on this decision

The decision is safe only while these hold. They are obligations, not assumptions.

- **Every authentication path honours the parent.** Browser pages, refresh, token reissue, API and
  Bearer authentication, any long-lived connection and any read that could come from a replica or
  cache must refuse credentials of a revoked parent. This must be shown by test for each path. A
  path that cannot do so needs an explicit upper bound on residual acceptance and a remedy, recorded
  before sign-out is described to users as ending the other services' sessions.
- **Revocation and issuance are serialized.** Token exchange and refresh take the same parent lock
  as revocation, so a revoked parent can never regain a usable child.
- **Declarations match behavior.** No metadata may advertise BCL while none is sent.

## Do not reintroduce without a new ADR

- Do not add `backchannel_logout_uri` or `backchannel_logout_supported` back to registrations or
  discovery for first-party clients.
- Do not make the result of sign-out, or the redirect that follows it, wait on an HTTP exchange
  with an RP.
- Do not add a delivery queue, delivery ledger, retry budget or partial-delivery state to
  first-party sign-out.
- Do not leave sibling RP rows unrevoked "until notified".

Each of these was designed in detail and withdrawn; the research record lists what it cost.

## When BCL becomes the right tool

Reopen this decision when an RP exists whose sessions the IdP cannot revoke in the parent's
transaction: an external party, or a first-party service with its own session store and its own
deployment. For such an RP, BCL is the standard mechanism and should be added as a separate
extension under a new ADR, with these constraints carried over:

- per-client opt-in; first-party RPs on the shared store stay on the shared-database path;
- delivery happens after COMMIT and outside the request, and never decides whether sign-out
  succeeded;
- a receiver validates the token without side effects, revokes exactly the session named by `sid`,
  and answers 200 only after that revocation is committed or already true.

## Consequences

- Sign-out has one outcome that matters, the COMMIT, and three observable results: committed,
  rolled back, unknown. Notification timeouts, retries and partial delivery do not exist.
- Sibling RP rows become revoked at the same instant as the parent, so stored state matches what
  the acceptance checks already enforced.
- The parent sign-out primitive must become one transaction. Today it writes the sign-out flow
  record, the Device Session and the tokens without one enclosing transaction and falls back to
  token-only revocation after a Device Session failure. That primitive also serves ordinary
  sign-out, so its other callers are affected by the change.
- Until the removal is implemented, the defective receivers remain reachable. Removing them is not
  optional follow-up work.
- An open screen at another RP keeps showing what it already rendered until it next communicates.
  An optional check when a page becomes visible again can shorten this. It must not refresh session
  activity, or it would defeat idle expiry.
- A stateless token accepted somewhere without a parent check would remain usable until its expiry
  (five minutes plus thirty seconds of leeway at the time of writing). The authentication-path
  condition above exists to find and bound such paths.
- Documents that describe current behavior, including `docs/security/logout-session-management.md`
  and `docs/security/logout-sequence.md`, are updated when the implementation changes, not by this
  ADR.

## Alternatives considered

- **Synchronous BCL from the sign-out request, then redirect.** The withdrawn plan. Rejected for
  the reasons in Context items 3–5.
- **Asynchronous BCL through a background job.** Removes the waiting but keeps a second, weaker
  path to an effect the transaction already achieves, and keeps the receivers.
- **Front-channel logout, redirect chains across RPs, cross-origin cookie operations, server push
  and periodic polling.** See the "Methods not used" section of the research record.
- **Keep the BCL code disabled for later.** Rejected under
  `.agents/harnesses/rules/generic/no-compatibility-layer.mdc`; dormant security code is neither
  tested nor trusted when revived.

## Standards and assurance limits

Relevant specifications: OpenID Connect RP-Initiated Logout 1.0, OpenID Connect Back-Channel Logout
1.0, RFC 7009 and RFC 8725. This ADR claims only that RP-Initiated Logout's browser flow is kept
and that BCL, an optional extension, is not offered. It makes no conformance claim. The escalation
ruling was issued from a description of the system, without reading the code, and certifies no
implementation.
