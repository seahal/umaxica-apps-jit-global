# Identifier conventions and scoped column classification

The [identifier ADR](../../adr/identifier-contract.md) owns the approved design. The
[identifier checklist](../checklists/identifier-contracts.md) owns observable acceptance. This
reference connects concrete columns and consumers to those owners; it is not a complete table
inventory or an implementation-completion claim. Types below describe inspected repository schema
definitions unless revision-scoped evidence explicitly records an actual catalog query.

## Applying the contract

Classify by meaning and format authority before changing generation, constraints or consumers. Use
the ADR's eight roles; column suffixes and existing UUID generation are discovery hints, not a
verdict. Standard self-controlled non-secret issuance is NanoID-21 with varchar capacity 25.
Preserve issued references and independently validate accepted compatibility. Never
shorten/case-convert values or invent additional mapping/public-ID layers solely to match spelling.

Use existing PublicId generation/lifecycle behavior where correct. Direct Nanoid calls in
Preference, TOTP and RP-session writers still require shared-generation/consumer review; listing
them here does not exempt them. Ownership-ID DB protection and bulk/collision handling must satisfy
ID-4/ID-5 and the explicit authority map. Model callbacks do not establish DB immutability. New
same-row identifier triggers and shared-role changes are not authorized by this document.

## ORG Telephone transition

| Table / column                                                               | Meaning and required contract                                                                                                  | Current implementation / transition                                                                                                                                                                                                                                       |
| ---------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| operator_telephones.id                                                       | Database-local row PK; single bigint                                                                                           | Keep local joins; no new remote/URL authority.                                                                                                                                                                                                                            |
| operator_telephones.public_id                                                | Owned non-secret resource identity; NanoID-21 issuance, varchar(25) capacity, required/nonblank/unique/immutable after cutover | Nullable expansion and NULL-only operational backfill exist. Nonblank validation/NOT NULL, approved DB immutability and writer/proof cutover remain incomplete.                                                                                                           |
| operator_telephone_ceremony_transactions.telephone_candidate_ref             | Cross-DB reference to the candidate; not an independently generated owned ID or single-column UNIQUE                           | New registration consumers copy public_id. Old canonical decimal PK references are transitional and cannot be rewritten because they are bound into keyed proof. Bounds must preserve explicit old/new contracts; current unbounded storage is not a permanent exception. |
| operator_telephones.number / number_digest                                   | Encrypted PII and realm/channel keyed lookup material, not public opaque identity                                              | Preserve normalization, realm keys, comparisons and live uniqueness. Do not NanoID-convert or expose them.                                                                                                                                                                |
| operator_telephone_ceremony_transactions.otp_verifier / otp_receipt_verifier | Secret proof verification material tied to purpose/actor/session/candidate/generation/deadline                                 | Never emit or regenerate as a public identifier. Keep accepted single-use and bounded original-operation receipt semantics.                                                                                                                                               |

All concrete ORG registration producers/consumers are listed in ID-3a. Source-ID backfill,
proof/receipt drain, queue/writer control and consumer deployment are separate steps in the
[DB workflow](../operations/db-workflow.md). Read-only legacy counts, even all zero, cannot prove
quiescence. New links use public IDs; the existing owner-scoped numeric management URL reader is
temporary ID-3b compatibility, with no failed-public-lookup fallback.

## Passkey values are different contracts

| Table / column                                                     | Format authority / role                                                      | Disposition                                                                                                                                                                                                                                                                                             |
| ------------------------------------------------------------------ | ---------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| client_passkeys / visitor_passkeys / operator_passkeys.webauthn_id | Authenticator/provider credential ID; externally governed value              | Preserve actual credential encoding, comparison, unique scope and verification. Do not truncate to 25 or replace with NanoID. Document unknown bounds rather than fabricate them.                                                                                                                       |
| Same three tables.aaguid                                           | Authenticator metadata identifier; native UUID                               | External/protocol format exception; native UUID remains appropriate. It is not the credential's row PK or management authorization.                                                                                                                                                                     |
| clients / visitors / operators.webauthn_user_handle                | Dedicated immutable WebAuthn user handle, owned by the accepted WebAuthn ADR | Preserve the existing 32-random-byte URL-safe representation and RP binding; no PK exposure or format-only rotation. See the [user-handle ADR](../../adr/webauthn-user-handle.md).                                                                                                                      |
| client_passkeys / visitor_passkeys.public_id                       | Owned non-secret management identity                                         | Existing PublicId issuance/consumers remain. Current 21-character capacity is not proof of the standard 25-character storage contract or DB immutability.                                                                                                                                               |
| client_passkeys / visitor_passkeys / operator_passkeys.external_id | Self-generated UUID; its name does not establish provider format authority   | Not accepted as a permanent external exception. ORG currently uses it in management routes and step-up references. Preserve issued UUIDs and audit all consumers before an authorized bounded transition; do not silently reinterpret it as webauthn_id or create a redundant ID merely for formatting. |

The current ORG management consumers are
[the concrete controller](../../app/controllers/base/org/identity/passkeys_controller.rb),
[shared management orchestration](../../app/controllers/concerns/base_identity_passkey_management.rb)
and [OperatorPasskeyPolicy](../../app/policies/operator_passkey_policy.rb). APP/COM management
primarily uses public_id; that fact alone does not prove external_id unused or safe to drop.
Per-column code exception comments and a complete credential-consumer inventory remain required.

## Other classified areas and remaining inventory

Avatar transfer idempotency keys retain the explicitly approved canonical UUID v4/v7 request
contract in AV-5. That exception does not extend to all internally generated transaction IDs.
Ceremony transaction/grant/result IDs and OTP generations need their actual purpose, entropy and
consumer binding classified before changes; self-generation does not make them external. A native
UUID column cannot store NanoID without an approved identity-preserving schema transition.

Dead identifier history fingerprints are pseudonymous keyed cryptographic material, not resource IDs
or authentication lookup keys. They retain their separate
[realm/channel and retention contract](../../adr/realm-separated-identifiers-and-dead-history.md).
No public_id or uniqueness/index is added merely because the history row exists.

Maintain explicit categories for permanent external exceptions, bounded compatibility with actual
exit conditions, unresolved violations and unverified facts. The physical catalog finding for
staff_identity_audit_events' string PK is an unresolved violation, not an unmanaged-table exception.
Complete all-table ownership, eight-role classification, reference bounds, sequence/partition and
executable regression coverage before declaring I acceptance complete. These scoped mappings do not
provide that global evidence.
