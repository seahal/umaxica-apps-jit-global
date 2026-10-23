# Passkey Current State, Registration Limit, and Chronicle Delivery

## Status

**Accepted (2026-10-19).** This decision applies to the APP, COM, and ORG Passkey credential records
and their lifecycle audit delivery. It records the intended contract and the implemented schema
direction; deployment and production queue operation still require the evidence listed below.

## Decision

### Capacity restored (2026-10-23)

[Passkey authenticator account label](passkey-authenticator-account-label.md) restores the ten-per-owner capacity of this ADR on APP, COM and ORG
(owner decision, 2026-10-22); the 2026-10-21 four-slot partial supersession below is itself
superseded. Enforcement remains unverified.

### Partial supersession (2026-10-21, superseded for capacity on 2026-10-23)

[Passkey Identifier-First Sign-In](passkey-identifier-first-sign-in.md) replaces the ten-per-owner
capacity below with a four-slot target on APP, COM and ORG. The original ten-credential decision
and rationale remain historical. Four-slot enforcement and safe handling of existing counts above
four require later investigation; no deletion, migration or new database mechanism is approved
here. Owner serialization, credential uniqueness, lifecycle deletion and Chronicle/outbox contracts
remain accepted. The successor records a design target, not delivery.

Passkey tables represent credentials that are currently retained and usable or are retained for an
explicit lifecycle reason. Chronicle is the historical audit authority. A terminal Passkey row is
not retained indefinitely merely to preserve history.

Each identity may retain at most ten Passkeys; every retained row counts, whatever its status.
`PasskeyRegistrationOperation` locks the owning identity (`Client`, `Visitor` or `Operator`) and
inserts the credential and any lifecycle outbox fact in the same principal transaction. The model
validation that refuses an eleventh row therefore runs serialized for that owner, and two concurrent
registrations for the last place commit exactly one. Registration-count triggers and model create
callbacks are not used.

The limit is enforced by the application, not by the database (user decision 2026-10-19, overriding
the finite-slot schema first specified in two.md REQ-P02). A write that does not go through the
operation can exceed ten. The gap and its revisit conditions are recorded in
`plans/backlog/2026-10-19-passkey-limit-enforcement-gap.md`; a static guard rejects direct Passkey
creation in application code.

Existing `webauthn_id` uniqueness is preserved, and `external_id` is unique in each independent APP,
COM, and ORG principal database. This is per-database uniqueness; it does not claim a cross-database
global index.

Settings removal and definitive sign-up cancellation physically delete the Passkey row. Withdrawal
may first revoke a credential while authentication is stopped; retention purge physically deletes it
after the applicable hold and dependency checks. Deleting a row frees its place under the limit. A
deleted credential may be registered again by the same or another identity only through a fresh,
server-verified WebAuthn ceremony. Chronicle history and AAGUID do not create a re-registration
blacklist.

New lifecycle facts use the common Chronicle: registration by signup or settings, actual description
change, user removal, revocation, cancellation, and final purge. A principal-side transactional
outbox row commits with the Passkey mutation. An asynchronous delivery job writes Chronicle by
`event_uuid`, verifies the immutable event identity, and acknowledges the source only after the
Chronicle row exists. At-least-once delivery and duplicate execution are therefore safe without a
distributed transaction. The source occurrence time is retained; delivery time is not substituted.

The old ClientChronicle and OperatorChronicle histories remain readable, but new Passkey lifecycle
facts are not dual-written there. APP Activity Log merges eligible common APP Passkey facts with its
legacy ClientChronicle read path under the current Client scope. COM and ORG Activity Log redesign
is outside this decision.

Only minimal stable references are sent to Chronicle. Raw credential IDs, public keys, challenges,
tokens, OTPs, cookies, and unnecessary PII are excluded. UUID preservation is limited to the
explicitly permitted `external_id` sanitizer key. The retention duration for Passkey Chronicle
history remains **TBC** and is not implied by the principal retention period.

## Relationship to earlier decisions

[`declarative-database-constraints-for-integrity-and-cardinality.md`](declarative-database-constraints-for-integrity-and-cardinality.md)
prefers finite database slots for per-owner limits. Passkeys deliberately do not use them: the limit
is an owner-locked application check, and the general no-count-trigger principle remains in force.
This is a recorded exception to that preference, not a change to it.

It supplements the existing Chronicle consolidation and audit guidance. It does not move unrelated
audit events, create a cross-database transaction, or change WebAuthn RP ID, Origin, User
Verification, MFA, Step-Up, or surface authentication boundaries.

## Review obligations and limits

- Every deployed Passkey registration writer must use `PasskeyRegistrationOperation`.
- Outbox delivery, retry, backlog monitoring, and production worker execution require operational
  evidence; static schedule configuration is not proof of runtime health.
- Existing historical rows must not be given invented identifiers during Activity Log merging.
- Chronicle retention, legal holds, and external storage retention remain separate decisions.
