# Identity Resolution and Credential Binding

## Status

Accepted (2026-10-06) as the target architecture for the `two.md` implementation cycle.

Amended (2026-10-21) by [Passkey Identifier-First Sign-In](passkey-identifier-first-sign-in.md):
APP/COM Passkey sign-in selects an Identity through its effective Email or Telephone binding before
challenge issuance and verifies credential ownership against that server-fixed Identity. Contact
lifecycle, immutable ownership and handle contracts remain accepted. The successor also expressly
restored a four-slot target over the ten-credential decision of 2026-10-19; that capacity is
superseded again on 2026-10-23 by [Passkey authenticator account label](passkey-authenticator-account-label.md): ten Passkeys per Identity. Enforcement remains
unverified. This amendment records design, not implementation.

## Context

Credential lookup currently mixes pending candidates with effective bindings and, for app Secrets,
uses a global value-derived lookup digest. Social uniqueness is provider-shaped rather than
effective-binding-shaped, passkey ownership is not uniformly checked at the assertion boundary, and
Secret allocation and delivery cross multiple databases without a durable authority snapshot.

## Decision

An effective credential binding is verified, fully finalized, owned by exactly one actor, and not
released. Database constraints enforce both cardinality directions under owner-locked mutation:
email and telephone have one effective Identity per normalized destination and one destination per
Identity; app social has one effective subject per Client and one effective social binding per
Client across Google and Apple; app Secrets have zero to twenty effective unused credentials per
Client; passkeys have at most ten per Identity (capacity restored 2026-10-23; the earlier four-slot
wording is superseded). Pending candidates and OTP evidence remain outside
the effective unique predicates.

Email and telephone finalization rechecks candidate, proof, expiry, cancellation, Identity state,
and both uniqueness directions. A uniqueness loser terminates only its own operation. Release and
replacement are atomic under the owner lock, while reattachment requires new authorization and OTP.
OTP evidence is bound to surface, purpose, flow, browser, Identity, candidate, and binding; a
released binding is never re-resolved to another Identity.

Social resolution uses verified issuer and subject only. Email, display name, provider browser
state, and `iss/sub` translations never select an actor. Release history is retained, old callbacks
cannot reattach a released subject, and org remains limited to the existing Operator, tenant,
organization, and Emergency controls.

Passkey credential ownership and the stable opaque Identity handle are immutable. Discoverable
authentication compares decoded returned `userHandle` bytes to the registered handle; actor-known
authentication checks ownership and any returned handle. Signature, challenge, RP, Origin, UV, UP,
purpose, browser, and slot concurrency remain in the real verifier and owner serialization.

App Secrets are Client-owned, server-generated Base58 values stored only as Argon2id hashes. App
Secret sign-in first resolves a finalized email or telephone binding to one Client and then verifies
the supplied value against that Client's credentials. The value-derived `lookup_digest` and global
reverse lookup are removed. A successful claim is irreversible, bound to the Client, credential,
operation, admitted browser, and durable flow, and shares a durable receipt with the canonical root
token issuance.

Capacity is evaluated under a short Client writer lock with `A <= 20` and `A + R <= 20`; manual
issuance reserves one, passkey registration reserves two at A=0..18 and one at A=19, and A=20
creates no material or candidate. Plaintext exists only in the short-lived encrypted server
payload, and explicit protected POST actions control presentation, confirmation, and reattempt.

Source mutation and allowlisted audit outbox rows commit together. The outbox snapshots issuance
origin and exactly one authority reference. Unknown provenance is held, and physical deletion waits
for Chronicle identity-matched terminal audits, retention, legal/enforcement holds, and live proof
retention. Delivery retries reconcile committed facts and never recreate consumed credentials.

## Consequences and supersession

The Contact Source audit shape was explicitly approved on 2026-10-07. Separate app/com Zenith
outboxes retain a server UUID, email/telephone kind, finalized/released event, opaque owner/contact/
operation references, nullable actor reference, Source occurrence and acknowledgment timestamps.
They contain no address, number, OTP, browser proof or result token. Delivery to the existing
Chronicle security retention policy is UUID-deduplicated and checks immutable event identity before
acknowledgment. A periodic bounded scan is the recovery authority; queue enqueue is not.
The ceremony committers are wired to this path and receive an explicit ActorValuesContext.
Authenticated attribution must match the owner and role on the owning surface; anonymous signup
attribution retains a nil actor reference. The Source recorder also checks the finalized/released
binding fact instead of accepting an unsupported event intent. Exact consumed-result retries compare
the retained Ticket provenance and Source receipt under the owner/contact lock, returning the
committed binding without creating another event. A released binding or consumed Ticket with no
committed Source fact remains terminal and refused.
Email signup reconciles its Source-committed/Ticket-failed binding through its original bound
birthdate POST only when every checkpoint requirement is already clear and one anonymous intent
matches that flow, owner and effective contact. The finalizer rechecks provenance under Source
locks after Ticket authorization is revalidated. It rewrites neither the binding timestamp, audit
intent nor birthdate. This is binding-fact reconciliation toward D-107, not permission to revisit a cleared
checkpoint generally; missing or ambiguous evidence, release, owner unavailability and expiry refuse.
It does not recover COM's entire recovery distribution: the stricter HTTP fault test retains the ten
credentials and original reveal row but fails the original distribution-destination check. The
Source-owned distribution receipt and read-only GET/protected POST receiver proposal are deferred
outside this Goal by the owner; see `plans/backlog/com-recovery-distribution-interruption.md`.
The existing GET consumer is not certified against the older receiver expectation, and this cycle
changes neither its transport nor the ten-credential distribution. The retained red evidence does
not create a current-scope approval blocker; Task 23.3's remaining in-scope verification stays open.
Initial finalization also checks the signed result's candidate reference and digest against the
retained Ticket before consumption, then rechecks the actual digest under the Source lock. A valid
signature and matching owner alone cannot substitute another candidate of that owner.
Base app/com Contact removal now supplies its authenticated ActorValuesContext and commits
one-way binding release, terminal contact status and Source audit intent together under the
owner/contact/session locks. Missing, anonymous, foreign-role and foreign-realm contexts refuse
before security transition; terminal retries add no event. Ticket invalidation remains independent
and is not resurrected when Source rollback leaves the binding effective. The old controller-level
post-commit Contact audit writes are removed from these four removal endpoints.
Settings app/com email/telephone confirmation also commits its finalized Source intent under the
owner lock, using the immutable candidate reference as its operation reference. During replacement,
the old effective binding remains until OTP succeeds; its one-way release, old OTP invalidation,
new finalization and both intents then share that Source transaction. Org contact behavior retains
its separate existing contract and receives no Customer outbox.
Telephone signup finalizers receive the explicit request Actor context and the signup flow's immutable
public reference. They lock the owner before the candidate and persist its binding fact, OTP clearing,
app principal promotion and Source audit intent in one transaction. Anonymous signup requests retain
an absent authenticated actor reference; a pending principal is not invented as that actor. The app
finalizer no longer creates Chronicle reference rows or writes Chronicle after the Source commit.
Settings initiation creates independent same-destination candidates without destination-wide deletion
or reuse; this does not establish the complete independent-browser/concurrency contract.
Signup OTP issuance and verification compare the bound candidate's owner with the Ticket principal
before use and again under the Source contact lock. A mismatched trusted Ticket/candidate owner is
an explicit invariant failure; neither delivery nor OTP consumption may act for that other Identity.
Released binding facts also refuse signup OTP issuance and verification before use and under the
Source contact lock; retained proof cannot reauthorize that released binding.
Email signup also locks the owner before its candidate and commits the binding fact and Source audit
intent together with app principal promotion. Credential after-commit MFA refresh reloads the owner
under its lock, so a cached association cannot overwrite a newer principal promotion or fail with
its stale optimistic-lock version. This derived refresh is not the Source audit delivery boundary.
The refresh uses a separately loaded persisted owner, preserving unrelated unsaved edits on the
associated instance rather than saving or discarding them.
Signup finalization rebuilds its context and revalidates authorization after acquiring the Ticket
lock, before Source finalization. Both email and telephone Source finalizers refuse an unavailable
owner while holding its lock; suspended owners cannot receive a new binding or Source intent.
The complete candidate failure/concurrency matrix remains acceptance work, not a delivered guarantee.
New forward recognition guards preserve immutable existing binding/release facts and require exact
Source intent or durable completed signup evidence. Unknown history, missing owners and conflicting
effective bindings abort with non-secret row IDs, without choosing a winner or rewriting facts.
Recognition uses one owning database timestamp, not invented historical verification time.
Owned historical probes and empty-fleet reconstruction were verified; shared rollout is unverified.

The owner approved the concrete shared OTP verification failure budget on 2026-10-07. Auth-state
Valkey stores an integer at `otp-verification:<surface>:<purpose>:<channel>:<existing destination digest>`.
The first admissible wrong comparison fixes a 900-second deadline; the fifth failure refuses further
verification, including correct codes, until native expiry. Candidate, flow, browser and owner do
not partition the key, and existing candidate limits remain. Success, resend and refusal neither
reset the counter nor extend the deadline. Atomic Lua validates and increments the count;
[Valkey INCR preserves its existing expiry](https://valkey.io/commands/expire/).
Corrupt state or unavailable dependencies raise before OTP consumption, without a second store or
permissive fallback. A later Source rollback does not refund the conservative failure counter.
Contact-derived key material is read under the Source Contact lock, not from an earlier caller snapshot.
Scopes separate public signup, email authentication, authenticated credential registration,
enforcement recovery and withdrawal reentry. Public signup cannot exhaust authenticated scopes,
but a third party can still deny verification of the same signup destination for the remainder of
the original 15-minute window; the owner accepted this bounded risk. Admission, CSRF, Turnstile,
candidate and delivery controls are retained rather than replaced by the budget. App/com signup,
app/com email sign-in and app/com/org destination confirmation are integrated. Existing CommonOtp
recovery/reentry callers supply their own scopes as a direct interface dependency; COM's interrupted
credential-distribution recovery remains outside the Goal. This does not certify dispatch limits,
real/dummy timing parity or the full fault matrix.

Dummy app/com email sign-in uses the same authentication destination budget for well-formed
six-digit input and always refuses, even when the dummy comparison value matches. It does not
validate a nonexistent persistent Contact: doing so previously stopped before verification and
left the shared counter untouched. Malformed input remains a genuine refusal without destination
counting. This implementation does not claim complete response or timing parity.

Sign-in resend requires confirmed admission and binds its encrypted state to the server-resolved
Auth continuity digest through MessageEncryptor purpose verification. An independently admitted
browser or successor continuity cannot use the predecessor's state. No browser-supplied binding
value, raw sid, new key namespace or unbound-token fallback is introduced. Resend rotates only the
effective binding, preserving independent candidates; dependency/provider failure is explicit.
Version-2 opaque state snapshots the Contact reference, owner and immutable binding fact.
The locked Source row must still match those facts and the normalized destination digest; resend
never re-resolves a released address to another owner. Dummy state remains dummy after subsequent
registration. Equal-width encrypted fields preserve state-length parity. A stale code-entry page
with a released Contact restarts without minting a successor state. Delivery-time lifecycle checks
and full timing parity remain acceptance work. This increment does not change COM
credential-distribution recovery.

The measured receipt/resend/COM-refusal timing gap requires a floor around the full operation,
not only the indexed lookup. Accepted email receipt processing, valid-state resend and
well-formed six-digit verification now have a shared 100ms monotonic minimum. This bounded
latency tradeoff does not extend a database deadline, reset a budget or mask a dependency failure.
Malformed requests stay genuine rejections. The local before/after measurement narrows ordinary
gaps; scheduler/GC tails, production delivery and browser behavior are not certified.

The transaction boundary follows [Rails transaction semantics](https://api.rubyonrails.org/classes/ActiveRecord/Transactions/ClassMethods.html):
one transaction cannot make writes on independent database connections atomic. Source and Chronicle
therefore use durable intent and identity-matched retry, rather than nested cross-database rollback.

The principal and Ticket databases become the authority for effective binding and ceremony facts;
there is no cross-surface universal credential registry. Existing Secret-only lookup guidance is
**fully superseded** by this ADR. The social and WebAuthn identity decisions are **amended**. Pending
candidate, audit, retention, and other-surface Emergency boundaries are **retained**.

Implementation is complete only when T01-T17 and the matching concurrency, failure, purge, delivery,
and route tests pass, the migration is reconstructed from empty and representative old data, and
the identity/binding documents describe the delivered behavior.
