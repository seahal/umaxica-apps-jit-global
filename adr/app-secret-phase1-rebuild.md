# app Secret Phase 1 rebuild

## Status

Accepted target domain contract, recorded 2026-10-03 (UTC). Implementation is
partial. Disposable-DB HTTP checks cover manual issuance, protected delivery,
storage confirmation, canonical local Secret login and audited physical recovery.
Signed-in and signup Passkey registration distribution are connected; signup
completion, cancellation and expiry have HTTP evidence. Concurrency, browser
confidentiality, proof collection and complete other-surface regression remain open. The [persistence shape proposal](../plans/analysis/app-secret-persistence-shape-proposal.md)
identifies additional formats still requiring explicit approval.

This replaces the app purpose and legacy app-only state described in
[Emergency Secret Credential Commit Acknowledgement](emergency-secret-credential-commit-acknowledgement.md).
Its historical record is retained. com recovery and org Emergency contracts are
outside this replacement.

## Decision

The user accepted the four operational lifetimes on 2026-10-05 (UTC): 600 seconds
for issuance/presentation, 86400 seconds before eligible terminal collection,
604800 seconds for delivered source outboxes, and 2592000 seconds for processing
proof retention. Explicit configuration is required; authority deadlines and
unresolved dependencies still restrict these lifetimes. Solid Queue performs
application audit delivery and physical collection through periodic recovery
scans and bounded continuations. This decision introduces no database VACUUM task
and grants no shared-database application or deployment authorization.

ClientSecretCredential is an app Client-owned, server-generated, case-sensitive
32-character Base58 single-use credential for normal Sign in. Generate with
SecureRandom.base58(32), without user selection, normalization or truncation.
Its issuance origin is historical evidence, not a credential kind. A later
Passkey deletion alone does not revoke a previously confirmed Secret.

Secret proves neither Step-Up nor account/credential recovery. A normal session
established with Secret may subsequently perform Step-Up using a different
method accepted by the existing operation requirement. Authorization evaluates
method, scope, freshness and actor/session/transaction binding; it does not
become an AAL-number comparison. Storage declaration is not authentication.

Rebuild the old app Secret tables without inheriting values or retaining kinds,
statuses, variable usage counters, old Emergency claims, compatibility reads or
dual writes. Neither five-minute validity nor five-failure locking is copied.
Client, other authenticators, sessions, Chronicle history and com/org data remain
outside the destructive target. Only identified disposable databases may execute
the irreversible rebuild; recovery recreates that disposable database and cannot
restore discarded old Secret values.

## Persistence and acceptance boundaries

Zenith owns Client, credential lifecycle, issuance/reservation and its source
outbox. Even a short-lived reservation belongs there because credential capacity
must be atomic with the Client and credential facts. Ticket is PostgreSQL and
authoritative for its own SignInFlow, Token and successful login receipt. Neither
cache substitution nor merging these databases is part of this decision.

Use fact timestamps rather than an app Secret status discriminator. confirmed_at
records explicit storage declaration for the fixed presented set. claimed_at
and claim_operation_id record irreversible acceptance. There is no consumed_at
column duplicating acceptance or Ticket's independent successful commit fact.
Retention uses discard_at and purge_eligible_at; physical deletion is a separate
audited fact. Pending candidates cannot authenticate.

Look up the indexed HMAC-SHA256 digest of the complete input, then verify the
complete value using the stored Argon2 password digest. The current existing
SignSecretLookupDigest primitive derives its key from Rails secret_key_base; no
new key is introduced. Lookup narrows the candidate without comparing twenty
password hashes. Full verification remains required. Neither digest is public
metadata or an audit field. Credential lookup does not itself authorize login.

After complete verification, an atomic Zenith claim is the single-use acceptance
point. Bind it to the legitimate server operation, existing flow and browser.
Ticket failure or an unknown result never unclaims or revives that Secret.
Reconciliation of the same operation is distinct from accepting a new input.
Only the canonical AuthenticationBase#log_in boundary establishes the root
session, with existing limits, cooldown, flow validation and post-commit cookies.
Ticket receipt represents that successful commit, not an attempted login.

There is no cross-database transaction. Zenith changes and Zenith outbox commit
together; any Ticket state needing its own audit commits with a Ticket source
outbox. Chronicle receives idempotent deliveries by immutable event ID. Enqueue
is not delivery. Physical deletion waits for preceding terminal audit delivery,
then commits DELETE and its purged-event source outbox together. That outbox must
survive credential deletion. One audited app purge path owns physical deletion.

## Delivery and capacity

The [count policy](app-secret-issuance-count-policy.md) defines A/R, 2/1/0
Passkey registration allocation, manual one-item addition, no minimum balance,
and shared Client locking. Confirm the fixed candidate set atomically.

Delivery uses a short-lived encrypted server payload and an explicit protected
presentation request. GET/HEAD/OPTIONS and prefetch do not generate or consume
values. Missing, expired or undecipherable payload fails explicitly, without a
new-random fallback. Ordinary retry and explicit reissue are different operations.
Plaintext does not belong in URL, logs, cookies, browser storage or Inertia history.
Signup delivery requires its existing initial-registration authority; signed-in
management always requires current operation-specific Step-Up and ownership.

Saved credential validity, issuance/presentation expiry, Step-Up freshness,
flow/claim acceptance and cleanup/Chronicle retention are different lifetimes.
Unresolved durations require explicit configuration decisions before applicable
operation or production use. Old Emergency's five minutes supplies none of them.

## Standards and limits

UMAXICA Secret corresponds to the Look-Up Secret authenticator classification in
[NIST SP 800-63B-4 section 3.1.2](https://pages.nist.gov/800-63-4/sp800-63b/authenticators/#look-up-secrets).
That classification does not confer conformance. The standard describes single
successful use, secure generation/delivery, hashed storage and protected-channel
verification. Online delivery requires AAL2 or higher and post-enrollment binding.
UMAXICA operation-specific Step-Up alone does not establish that assurance claim.
Crypto approval, channel assurance, binding, browser exposure, issuance and
single-use completion remain items to evaluate rather than declare satisfied.

The 32-character Base58 design has approximately 187.5 bits of nominal entropy
when generated uniformly. It is a high-entropy saved credential, not a short OTP.
This calculation does not prove RNG approval, delivery safety or deployment
conformance. Look-up secrets are not phishing-resistant, and possession does not
guarantee permanent account recovery.
