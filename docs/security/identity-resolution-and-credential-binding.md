# Identity Resolution And Credential Binding

## Binding contract and implementation status

The architecture below is the target contract. Phase 19 acceptance remains incomplete; the
implemented paths and limitations are distinguished below. A green narrow test is not evidence that
every binding, retry, migration and cross-database failure path satisfies this contract.

Identity resolution is performed in the database that owns the actor. A pending candidate, an OTP
receipt, an external provider callback, a passkey assertion, and an app Secret are evidence for one
explicit operation; none is a universal actor lookup key. An effective binding is verified,
finalized, owned by one actor, and not released.

APP/COM email sign-in and security-lock recovery resolve only effective email bindings. A
candidate whose binding is not finalized cannot select an actor or receive authentication or
recovery OTP delivery, including when its mutable email status already says `VERIFIED`.
Ordinary unverified and pending-sign-up candidates remain outside these authority paths.
An account registered through another supported proof, such as a verified telephone or external
provider, follows that proof's own authentication contract rather than borrowing a pending email.

Email and telephone bindings enforce both directions of uniqueness: one effective destination has
one Identity, and one Identity has one effective binding of that kind. Social bindings use the
verified issuer and subject, retain release history, and enforce one active social binding per
Client across Google and Apple. A released binding is never reattached by a stale callback or OTP.
Passkeys retain an opaque immutable user handle and four-slot Identity ownership. Discoverable
assertions compare returned `userHandle` bytes with the registered handle; actor-known assertions
recheck credential ownership.

App Secret sign-in is identity-first. The request supplies a finalized email or telephone binding
and a Secret; the server resolves the binding to one Client and verifies the Secret against only
that Client's Argon2id credentials. The removed value-derived `lookup_digest` was a global reverse
lookup and is not part of the current schema or runtime contract.

## Mutation and lifecycle rules

App/com Contact finalization locks the Source owner before the candidate. The signed-result
committers verify retained Ticket provenance and the candidate digest; signup also revalidates its
authorization under the Ticket lock and refuses an unavailable Source owner under its lock.
Binding facts and their Contact audit intent commit in one Source transaction. Settings replacement
retains the old effective binding until successful OTP verification, then releases it, invalidates
its OTP and finalizes the new candidate with both audit intents in that transaction. Reattachment
requires a new authorization and OTP evidence. These implemented checks do not establish the full
candidate uniqueness-loser, cancellation and concurrency acceptance matrix.

Secret claim is irreversible and is bound to the Client, credential, claim operation, admitted
browser, and durable sign-in flow. Secret issuance uses a Client writer lock and the capacity rule
`A <= 20` and `A + R <= 20`; source mutation and its audit-outbox row commit together. Delivery
retry reconciles the committed fact and never recreates consumed material.

## Refusal and retry behavior

Signed Contact-result retries match the retained Ticket provenance and committed Source audit
intent before returning a binding. Released bindings and consumed Tickets without committed Source
facts are refused. Signup OTP rejects a Ticket/candidate owner mismatch and a released binding
before use and under the candidate lock. Shared failure/dispatch budgets across recreated flows,
the distinct verified-result deadline and exact signup OTP recovery remain incomplete.
They must not be inferred from signed Contact-result retry coverage. Unknown audit provenance is
held for reconciliation; no recovery may issue fresh evidence or revive terminal authority.

Email signup can reconcile a committed Source binding after Ticket SQL failure through the same
bound birthdate POST. All checkpoint requirements must already be complete, and exactly one original
anonymous Source intent must match the active owner, effective contact and flow. Authorization is
rechecked under the Ticket lock and intent provenance under owner/contact locks. The binding
timestamp, audit intent and original birthdate remain unchanged. Duplicate intent, release, owner
unavailability and expiry refuse. Telephone and the complete finalization fault matrix remain open.
The COM recovery-distribution continuation is not recovered by this binding-only reconciliation:
ten credentials and an unconsumed reveal survive the Ticket fault, but the original distribution
destination is lost. The owner excluded this COM distribution recovery from the current Goal on
2026-10-07. Its stricter HTTP regression and evidence remain retained in
`plans/backlog/com-recovery-distribution-interruption.md`; no receipt, reveal-transport change or
ten-to-two quantity change is authorized in this cycle.

The effective binding remains authoritative while pending candidates and plaintext Secret payloads
are retained only for their documented deadlines. Cleanup preserves live proof, unresolved outcome,
legal hold, enforcement hold and kill-switch conditions. Chronicle is a delivery/audit dependency,
not a source of effective identity resolution.

## Operational dependencies

The owning PostgreSQL database provides row locks, partial unique indexes, foreign keys and CHECK
constraints. Ticket and Chronicle writes are represented by immutable operation identifiers and
persisted receipts where a boundary crosses databases. The application must use the configured
primary connections and must fail explicitly when a required dependency or configuration is absent.
Real provider, OTP delivery, FQDN, Origin and key verification remain deployment prerequisites.

## Verification

Targeted Contact signup, settings, removal, signed-result and Source audit tests are recorded under
`evidence/`; their individual scope and remaining gaps are part of the result. Historical Contact
recognition now has new forward migrations that validate exact Source finalization/release intents
or completed Ticket signup proof (including OTP, birthdate and telephone passkey requirements).
They preserve existing security facts, recognize proven missing facts using one Source database
timestamp, and abort unknown completion/release, orphan owners and effective conflicts with row IDs.
Status alone is not proof. Seventy owned historical-data probe scenarios passed; the full empty
20-database fleet reconstructed from migrations and the focused Contact/OTP matrix passed.
Shared-environment application and the complete candidate/failure matrix remain unverified.
The shared OTP verification failure-budget shape and same-scope destination-exhaustion tradeoff are
approved. App/com email/telephone signup, app/com email sign-in and app/com/org authenticated
destination confirmation now use a shared five-failure counter with a fixed 15-minute deadline,
retaining candidate limits. Recovery/reentry CommonOtp callers have separate purpose scopes.
Email resend now selects only the effective binding and leaves independent candidates untouched;
dependency/provider failures are reported and raised rather than labeled invalid browser state.
These fixes do not certify the complete OTP lifecycle or late-delivery checks.
Accepted email receipt processing, valid-state resend and well-formed six-digit verification
share a 100ms monotonic response floor across APP/COM real and dummy branches. It covers the
operation rather than only lookup. Malformed input remains a genuine rejection; dependency
exceptions still propagate and database/verification deadlines are unchanged. Local HTTP
measurements narrowed ordinary timing gaps but do not establish equal tails or production parity.
App/com resend endpoints now also require confirmed sign-in ceremony admission; a signed resend
state alone cannot authorize an independent unadmitted browser or allocate a dispatch slot.
Resend state issuance and parsing additionally require the server-resolved Auth continuity digest
in the existing MessageEncryptor purpose. Two independently admitted browsers cannot exchange
states, and continuity rotation invalidates predecessor state. No raw sid or binding parameter is
accepted from the request; old unbound state refuses instead of using a compatibility fallback.
Version-2 encrypted state also snapshots the Contact public reference, owner and immutable binding
fact. Resend locks that exact Contact and checks those facts and the destination digest rather than
resolving the address again. Released/reassigned destinations cannot rotate a successor owner's OTP;
stale code-entry pages restart without minting state. Dummy state stays dummy even if that
destination later acquires an effective binding. Both modes use equal-width encrypted fields, and
the observed encrypted lengths match. These fields are not cleartext page props. Full lifecycle
and late-delivery checks remain unfinished acceptance obligations.
App/com dummy email sign-in also counts well-formed six-digit failures against the same destination
scope and can never succeed, including for the dummy comparison value `000000`. Malformed input
does not spend destination budget. Dummy verification does not validate a nonexistent persistent
Contact or create an Identity; dependency failure remains explicit.
Successful APP email ceremony JSON reports `authentication_evidence_recorded` and the canonical
`redirect_url` while the admitted flow waits at its checkpoint. It does not serialize an absent
root token as `null` or report root session-limit resolution as completed on Auth. Existing root
sessions remain unchanged until Base handles finalization and capacity.
The complete verification matrix,
full real/dummy lifecycle and
timing parity, the complete concurrency/fault matrix and renewed empty development/test fleet and
schema-drift checks are not complete. The owner retained the accepted provider GET callback contract
for this cycle; see `adr/social-omniauth-callback-transport.md`. The older receiver-POST regression in
`social_auth_link_test.rb` remains evidence of the deferred plan expectation, not by itself evidence
of an exploitable defect. Any future change needs a concrete attack path accounting for current
state, nonce, PKCE and transaction/browser binding, not a generic HTTP-method argument.

No complete T01-T17 or Definition of Done claim follows from these targeted results. The governing
design records remain `adr/identity-resolution-and-credential-binding.md`,
`adr/social-identity-linking-requires-step-up.md`, and `adr/webauthn-user-handle.md`.

The security boundaries are informed by [RFC 9700 section 4.7.1](https://www.rfc-editor.org/rfc/rfc9700.html#section-4.7.1)
for binding authorization state to the initiating browser and the
[OWASP CSRF Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html)
for session-bound request protection. These references support the local contract; they are not a
claim of protocol standardization or whole-system compliance.
