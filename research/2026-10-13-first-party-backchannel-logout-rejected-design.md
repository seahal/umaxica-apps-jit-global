# First-Party Back-Channel Logout: The Design That Was Not Adopted

## Status

Rejected on 2026-10-13. Non-normative record. The accepted decision is
`adr/first-party-sign-out-shared-database-without-backchannel-logout.md`; do not implement from this
document. Observations about code were made at commit `4828aeedd141b54163236672890799b9b01128c2` and
must be re-verified before any current decision depends on them.

This record exists so that the next person who thinks "sign-out should notify the other relying
parties, as the standard does" can see that the idea was designed in detail, what it would have
required, and why it was withdrawn.

Vocabulary: IdP is Base as OpenID Provider and Authorization Server. RP is a first-party relying
party (Core, Warp, Edit, Palm, Tech, Base Self-RP). Parent is the IdP Browser Session (Device
Session plus current root token). BCL is OpenID Connect Back-Channel Logout 1.0.

## How the question arose

1. The original sign-out design was repository-specific. Signing out at one RP did not immediately
   sign the user out of the others. The guarantee was that a refresh after the parent's revocation
   is refused, and that the access cookie expires together with the access token, so every RP is
   signed out after a bounded time.
2. To be closer to published standards, BCL was introduced: the IdP would tell each RP to end its
   session.
3. Each planning round then resolved a problem created by the previous answer. The plan for this
   one topic grew to a bounded sender, a notification-phase state axis and acceptance-time
   performance measurement, and the person responsible could no longer follow why.
4. A review against the code found that the IdP can revoke the RP rows itself, in the transaction
   that revokes the parent, and that RPs already check the parent on every request.

## What adopting BCL would have required

The design, as it stood in the last planning candidate before withdrawal.

**Order of operations**

1. The initiating RP records a sign-out intent and sends the browser to the IdP.
2. The IdP confirms, then revokes the parent only. Sibling RP rows are deliberately left unrevoked.
3. Before revocation, under the parent lock, the IdP snapshots the notification targets: one tuple
   per unrevoked RP row of that parent, plus the initiating RP.
4. After COMMIT and outside every transaction, the same request sends a signed Logout Token to
   each target, one at a time.
5. Only when every target has been attempted does the IdP redirect back to the initiating RP.
6. Each RP receiver validates the token and revokes its own row.

**Sender, inside the user's request**

- Target bound N+1 per realm, where N is the number of registered clients: 6 for org, 5 for app,
  4 for com once Palm and Tech exist.
- Concurrency 1. At most 2 attempts per target.
- At most 8 seconds for the whole phase, derived from the 10-second request timeout minus a
  2-second reserve; at most 2 seconds per attempt, further divided by the number of remaining
  targets so a slow receiver cannot consume another's share.
- One delayed retry of at least 3 seconds for recoverable failures, only if it still fits the
  phase budget.
- Response bodies capped at 4,096 bytes while streaming; no redirects followed; only 200 and 204
  counted as acknowledgment.
- Final values to be chosen by measurement during acceptance, inside that envelope.

**State that had to exist**

- A notification outcome on the sign-out intent: pending, acknowledged, partial, incomplete, with a
  finished-at timestamp.
- Displayed states for confirmation pending, parent committed, origin completed, notification
  pending, acknowledged, partial, unresolved, and expired or rejected.
- A rule that an unattempted target prevents the normal success redirect.
- A rule that a process stop leaves delivery unknown, with no resend afterwards.

**Receivers and token profile**

- New receivers for Warp, Base Self-RP, Palm and Tech, in addition to Core and Edit.
- Token validation made free of side effects: no `jti` consumption before the effect, strict claim
  types, lifetime at most 120 seconds, mandatory `sid`, no account-wide `sub`-only logout.
- Exact-row revocation only, with the root-token fallback removed; 200 only after a committed or
  already-true revocation, 400 otherwise.

**Acceptance**

- Process interruption at each point after COMMIT; slow receiver; all receivers slow; lost
  acknowledgment; budget exhaustion; target counts at 0, 1, N and N+1; duplicate and concurrent
  delivery; replay of an old token against a successor session.

## Why it was withdrawn

- **The effect was already available without a network.** RP rows and the parent share a realm
  Ticket database. `RpSessionRevoker` scope `:browser_session` already revokes the root token and
  its children under the Device → root → RP lock order.
- **It did not add protection.** RPs re-read the parent on each request; a revoked parent is
  refused whether or not the sibling row carries `revoked_at`. The notification changed
  bookkeeping, not access.
- **Every difficulty came from one choice.** "Do not revoke sibling rows synchronously" made an
  HTTP exchange necessary; HTTP can fail; failure needs partial states, storage, wording, a time
  bound and retry rules. Reversing that one choice removes all of them.
- **The request called its own process pool.** All receivers are routes of the same application.
  The default Puma configuration has 3 threads; three concurrent sign-outs, each waiting on a
  receiver, could occupy every thread while waiting for themselves.
- **The budget could not be exercised in tests.** The request timeout middleware is not loaded in
  the test environment.
- **Reachability through the edge was unexamined.** A receiver placed behind an access gateway
  would answer a server-to-server POST with a redirect, making every sign-out "partial".
- **It still could not clear another host's cookie**, which is the only thing left to do after
  server-side revocation.
- **Internal inconsistencies remained.** The N+1 bound assumed the initiating RP had already ended
  when targets were snapshotted, but the sequence ended it after the notification phase. The
  hint-based authority rules had no producer, because first-party RPs do not keep ID Tokens.

## Methods not used

Ways of ending, or tidying up, the sessions of RPs that did not start the sign-out. Each was
considered and set aside. "Not needed" means the accepted design already achieves the effect.

| Method | What it would do | Why it is not used |
| --- | --- | --- |
| BCL sent synchronously from the sign-out request | IdP posts a Logout Token to each RP before redirecting | Makes the result of sign-out depend on HTTP; needs budgets, retries and partial states; calls the same process pool; not needed for revocation |
| BCL sent by a background job after COMMIT | Same notification without blocking the user | Still a second, weaker path to an effect the transaction already has; keeps receivers and a queue for no added protection |
| Front-Channel Logout (hidden iframes) | IdP page loads each RP's logout URL in an iframe so the RP clears its own cookie | Depends on the browser staying on the page until every frame loads, with no confirmation; triggers a state change by GET; requires every RP sign-out page to be framable by the IdP. The user ruled out iframes. Hosts within one realm share a registrable domain, so third-party cookie blocking was not the deciding reason |
| Redirect chain through every RP | Browser visits each RP in turn so each clears its cookie | Stops half-way whenever a hop fails or the user leaves; adds visible navigation; needs RP-to-RP navigation that the directed Jump graph denies |
| IdP clearing another host's cookie, or `fetch` from the IdP page to each RP | Remove RP cookies directly | A host cannot delete another host's host-only cookie; cross-origin credentialed requests are unreliable and need CORS exceptions |
| Server push to open pages | Notify open RP screens at once | No Action Cable channel is mounted; building a push channel only for sign-out is not justified |
| Periodic polling from open pages | Detect revocation within seconds | Authenticated requests refresh session activity (throttled), so polling would keep idle sessions alive and defeat the 30-minute Operator idle limit |
| Leaving sibling RP rows unrevoked until they are notified or expire | Avoid touching other RPs' rows | Stored state would disagree with what the acceptance checks enforce; this is the choice that made BCL necessary |
| Keeping the BCL code disabled for later | Preserve the option | Dormant security code is untested and misleading; discovery would have to keep or drop a claim that nothing honours |

What is used instead, in order of strength:

1. The parent and all its RP rows are revoked in one transaction.
2. Each RP refuses the revoked parent at its next request and clears its own cookies then.
3. The access cookie expires with the access token (five minutes at the time of writing), so the
   browser discards it even if the RP is never visited again. Whether every RP sets the cookie
   expiry this way was read from the issuing code, not measured.
4. Optionally, a page that becomes visible again asks its own RP once and switches to the
   signed-out screen. This is a usability improvement and must not refresh session activity.

## What existed in the code when this was decided

For anyone reading history after the removal:

- Sender: `OidcBackchannelLogoutNotifier`, `OidcBackchannelLogoutDeliveryJob` (2-second open and
  3-second read timeouts, five queued attempts, any 2xx accepted), called only from
  `SignOidcLogout#notify_oidc_rps_of_logout` on the legacy end-session path. The `browser_rp`
  authority path sent nothing.
- Receivers: `OidcRpLogoutReceiver` in the Core app/com/org and Edit org
  `oidc/backchannel/logouts` controllers, with `OidcLogoutTokenCodec` and `OidcRpSessionLogout`.
- Declarations: a BCL URI on all ten first-party browser clients in
  `OidcClientStoresStaticClientStore`, and `backchannel_logout_supported: true` in
  `OidcDiscoveryDocument`. Warp and Base Self-RP declared a URI without having a receiver route.
- Known receiver defects: `jti` consumed before the revocation; fallback from an RP `sid` to the
  root token and a parent logout; unconditional 200 regardless of the logout result.

## When to reopen

When an RP appears whose sessions the IdP cannot revoke in the parent's transaction: an external
party, or a service with its own session store and deployment. The ADR lists the constraints a new
BCL extension should carry. Parts of the withdrawn design that would be worth reusing then: the
side-effect-free token validation, exact-row revocation with a truthful 200/400, the rule that a
hint or challenge is never authority, and the test list above. Parts not worth reusing: sending
from the user's request, and any rule that makes the sign-out result depend on delivery.

## Uncertainty

- Whether every authentication path refuses a revoked parent has not been tested. Browser page
  requests were read in code; API and Bearer paths, in particular the Palm native API, were not.
- Production process topology was not observed. The thread-starvation concern assumes receivers
  share the sender's pool, which is true for a single application process.
- The specifications were not re-read for this record; clause references in earlier planning
  documents were not checked.
- The planning documents this summarizes (`one.md`, `two.md` in the repository root) are ignored by
  Git and may no longer exist.
