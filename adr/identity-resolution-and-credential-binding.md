# Identity Resolution and Credential Binding

## Status

Accepted (2026-10-06) as the target architecture for the `two.md` implementation cycle.

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
Client; passkeys have four slots per Identity. Pending candidates and OTP evidence remain outside
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

The principal and Ticket databases become the authority for effective binding and ceremony facts;
there is no cross-surface universal credential registry. Existing Secret-only lookup guidance is
**fully superseded** by this ADR. The social and WebAuthn identity decisions are **amended**. Pending
candidate, audit, retention, and other-surface Emergency boundaries are **retained**.

Implementation is complete only when T01-T17 and the matching concurrency, failure, purge, delivery,
and route tests pass, the migration is reconstructed from empty and representative old data, and
the identity/binding documents describe the delivered behavior.
