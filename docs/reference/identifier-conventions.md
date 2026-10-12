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

`PublicId.generate` owns standard generation with size 21 and the installed library's safe
alphabet/CSPRNG path, explicitly non_secure=false. Preference, TOTP, RP-session and ORG Telephone
backfill writers call that mechanism without sharing their distinct lifecycle policies. Existing
resource values and callback timing are preserved. Ownership-ID DB protection and bulk/collision
handling must satisfy ID-4/ID-5 and the explicit authority map. Model callbacks do not establish DB
immutability. New same-row identifier triggers and shared-role changes are not authorized by this
document.

The public generation contract is tested in `test/lib/public_id_generation_test.rb`. The existing
invariant suite's `test/security/invariants/identifier_generation_invariant_test.rb` parses Ruby
ASTs under `app/` to reject direct Nanoid calls outside the shared mechanism. It does not classify
every identifier or prove dynamic aliases, crypto quality, database constraints or protocol
exceptions. The rest of ID-8 remains independently required.

## ORG Telephone transition

| Table / column                                                               | Meaning and required contract                                                                                                  | Current implementation / transition                                                                                                                                                                                                                                                                         |
| ---------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| operator_telephones.id                                                       | Database-local row PK; single bigint                                                                                           | Keep local joins; no new remote/URL authority.                                                                                                                                                                                                                                                              |
| operator_telephones.public_id                                                | Owned non-secret resource identity; NanoID-21 issuance, varchar(25) capacity, required/nonblank/unique/immutable after cutover | The additive expansion, approved immutability trigger, and two-step nonblank/NOT NULL migrations are represented in the current schema workflow. The NULL-only operation remains the pre-cutover maintenance path; writer/proof drain and any real-data cutover remain separately controlled and unclaimed. |
| operator_telephone_ceremony_transactions.telephone_candidate_ref             | Cross-DB reference to the candidate; not an independently generated owned ID or single-column UNIQUE                           | New registration consumers copy public_id. Old canonical decimal PK references are transitional and cannot be rewritten because they are bound into keyed proof. Bounds must preserve explicit old/new contracts; current unbounded storage is not a permanent exception.                                   |
| operator_telephones.number / number_digest                                   | Encrypted PII and realm/channel keyed lookup material, not public opaque identity                                              | Preserve normalization, realm keys, comparisons and live uniqueness. Do not NanoID-convert or expose them.                                                                                                                                                                                                  |
| operator_telephone_ceremony_transactions.otp_verifier / otp_receipt_verifier | Secret proof verification material tied to purpose/actor/session/candidate/generation/deadline                                 | Never emit or regenerate as a public identifier. Keep accepted single-use and bounded original-operation receipt semantics.                                                                                                                                                                                 |

All concrete ORG registration producers/consumers are listed in ID-3a. Source-ID backfill,
proof/receipt drain, queue/writer control and consumer deployment are separate steps in the
[DB workflow](../operations/db-workflow.md). Read-only legacy counts, even all zero, cannot prove
quiescence. New links use public IDs; the existing owner-scoped numeric management URL reader is
temporary ID-3b compatibility, with no failed-public-lookup fallback.

## Preference and Client Passkey owned identities

`client_preferences`, `visitor_preferences`, `operator_preferences`, and `client_passkeys` have
owned management `public_id` values. Their identity meaning is independent of a user, visitor or
operator's email/telephone identifier and independent of a passkey provider's `webauthn_id` or
`external_id`. The current P12a transition keeps the existing values and uses an explicitly
enumerated `PublicIdNullOnlyBackfillOperation` only for a pre-cutover NULL rehearsal; normal reads,
creates and updates never repair a missing identity.

Each owning database uses an additive migration that first installs `NOT VALID` checks for
`public_id IS NOT NULL` and nonblank values, then a separate validation migration changes the column
metadata to `NOT NULL` and removes both temporary checks. The validation migration is
non-transactional because PostgreSQL check validation must not run while writes are blocked by a
migration transaction. Its reverse path restores both temporary checks before returning the column
to nullable metadata. The run-owned rehearsal confirmed zero NULL/blank rows, successful NULL-only
assignment in the disposable pre-cutover state, and successful down/up application.

This scoped transition does not claim that all identifier consumers, all public-ID immutability,
provider credential formats, shared/production data, or the remaining P12a inventory are complete.
See
[ID-4b](../checklists/identifier-contracts.md#id-4b--owned-preference-and-client-passkey-identities-become-required)
for the independently reviewable acceptance conditions.

The three setting-database preference identities now also have an explicit storage-capacity
boundary. `app_preferences.public_id`, `com_preferences.public_id` and `org_preferences.public_id`
retain their unbounded PostgreSQL string representation for this additive transition, while named
`char_length(public_id) <= 25` checks reject oversized direct or bulk writes. The checks are added
as `NOT VALID`, validated in separate migrations and retained as database constraints; they do not
truncate existing values, change the NanoID-21 issuer or authorize a broad narrowing of the other
unbounded catalog candidates. See
[ID-4d](../checklists/identifier-contracts.md#id-4d--setting-preference-identities-have-bounded-database-capacity)
for the observable boundary and reversibility evidence.

## Staff identity audit-event bigint transition

`org_zenith.staff_identity_audit_events` is a fixed identity-audit catalogue whose legacy string key
was the one cataloged application-owned string primary key found by the P12a inventory. The
identity-preserving transition is now represented by three explicit stages. The additive migration
`20261012085039_convert_staff_identity_audit_events_to_bigint.rb` adds `legacy_id`, `id_bigint` and
`event_id_bigint` with reviewed B-tree indexes. The bounded
`StaffIdentityAuditEventBigintBackfillOperation` preserves every old code and maps each audit
reference without guessing or rewriting values.

After complete mapping, `20261012100000_cut_over_staff_identity_audit_event_bigint_keys.rb` swaps
the event table to a bigint `id` primary key and the audit table to a bigint `event_id` reference.
The separate validation migration
`20261012100100_validate_staff_identity_audit_event_bigint_foreign_key.rb` validates the staged
checks and foreign key, sets the required columns non-null, and removes only the temporary mapping
columns. `legacy_id` and `legacy_event_id` remain required correspondence values. The old string
primary key and foreign key are removed only inside this reviewed cutover; the migration refuses an
incomplete or conflicting mapping before changing authority.

The maintenance operation continues to support the additive state for an explicitly staged backfill
and returns an explicit, idempotent no-op in the final schema. A fixed reference catalogue does not
receive a sequence merely because its key is now bigint; the reviewed mapping supplies the IDs. The
disposable down/up rehearsal includes a synthetic event/reference pair and verifies that both the
bigint identities and legacy codes survive. No production/shared data, consumer cutover outside
these two tables, or complete ID-1 inventory is implied.

## Current public-ID capacity inventory

The 2026-10-12 run-owned catalog recheck found 238 `public_id` columns: 183 at `varchar(21)`, 52
unbounded `varchar` columns, one `varchar(255)` on `app_zenith.clients`, one `varchar(25)` on
`org_zenith.operator_telephones`, and one `varchar(16)` on `org_zenith.operators`. Aggregate values
observed in that disposable catalog had no length above 25. This is an inventory fact, not a
permission to narrow every column: each unbounded column still requires semantic role and consumer
review, and the migration rules require an explicit safe method before any narrowing. The operator's
16-character value is a separate human-entered code contract and is not a NanoID capacity defect.
See the revision-scoped
[`V4D8` evidence](../../evidence/2026-10-12-identifier-capacity-inventory-V4D8.md).

The app and com principal identities are now covered by the same bounded database boundary:
`app_zenith.clients.public_id` and `com_zenith.visitors.public_id` retain their current string
columns but reject `char_length(public_id) > 25` through named, validated PostgreSQL checks. The
checks are additive and identity-preserving; they do not narrow the type, change realm uniqueness,
alter the ORG human code, or authorize a broad migration across the remaining unbounded candidates.
See
[ID-4e](../checklists/identifier-contracts.md#id-4e--app-and-com-principal-identities-have-bounded-database-capacity)
for the observable contract and migration rehearsal.

The current P12a capacity slice extends that same database boundary to the explicitly classified
self-controlled `public_id` columns listed in
[`CAPACITY_TABLES`](../../test/models/public_id_capacity_contract_test.rb): the selected app/com/org
Zenith, ticket and signal records, app `members` and `logout_transactions`, plus Avatar groups,
Avatars, group memberships, handles, posts and post versions. Every listed table has a named,
validated `char_length(public_id) <= 25` PostgreSQL check installed through an additive migration
pair in its owning database. This is a storage ceiling for existing string columns, not permission
to issue arbitrary short values, a replacement for model validation, or a global type-narrowing
approval. Provider/protocol IDs, the ORG operator human code, retired `legacy_replaced_clients` and
`legacy_operator_department_accounts` retain their separate legacy contracts until a semantic,
consumer and retention review supports a later slice. The current run-owned catalog has no rows in
either table, but retained foreign keys still make the tables part of the schema boundary. See
[ID-4f](../checklists/identifier-contracts.md#id-4f--classified-self-controlled-identifiers-have-bounded-database-capacity)
for the exact table inventory and acceptance evidence; the baseline disposable run is recorded in
[`N9K4`](../../evidence/2026-10-12-public-id-capacity-gate-N9K4.md), with the four-table extension
recorded in [`V2J6`](../../evidence/2026-10-12-public-id-capacity-extension-V2J6.md).

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

The following additional mappings are source-observed, not a complete writer/API inventory or
catalog-conformance claim. Their current UUID generation is not a provider-format justification.

| Producer / column                                         | Role and meaning                                                                  | Required boundary and remaining work                                                                                                                                                                                                                                                                                      |
| --------------------------------------------------------- | --------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Client/Visitor/Operator Email ceremony transaction_id     | Owned ceremony identity in the concrete realm/channel transaction family          | The generic `EmailCeremonyTransactionable.create_transaction!` default remains UUID-compatible for purposes that have not yet been classified. The credential-registration issuer now supplies a new NanoID-21 reference explicitly; preserve existing UUID rows and proof-bound consumers.                               |
| Client/Visitor/Operator Telephone ceremony transaction_id | Owned ceremony identity in the concrete realm/channel transaction family          | The generic `TelephoneCeremonyTransactionable.create_transaction!` default remains UUID-compatible for purposes that have not yet been classified. The credential-registration issuer now supplies a new NanoID-21 reference explicitly; preserve existing UUID rows and proof-bound consumers.                           |
| The same Email ceremony grant_jti                         | Identity of the ceremony's grant, distinct from transaction_id and result_jti     | The creation method generates a separate UUID and grant_claims publishes it as jti. Do not reuse the resource ID or merge grant lifetime with result lifetime. Trace explicit supplied/import values and token validators before changing issuance.                                                                       |
| The same Email ceremony result_jti                        | Result identity, absent until consumption                                         | consume_registration_result! creates it under lock; consume_result! accepts an explicitly supplied result. Preserve NULL before result and one-time consumption; do not create dummy IDs or blanket immutability that blocks initial result establishment. Full result producer/consumer provenance remains to be traced. |
| chronicles.event_uuid                                     | Owned audit-event identity                                                        | ChronicleCapturable.capture generates a UUID; ChronicleIntentWriter persists it, and result/failure/invalidation writers retain the same event identity. Preserve existing audit references. Current model uniqueness is not proof of DB immutability or bounded capacity.                                                |
| chronicle_outbox_entries.event_uuid                       | Shared reference/correlation to an audit event, not the outbox row's own identity | Multiple outbox records may refer to the same event; retain the ordinary lookup index rather than adding blanket single-column UNIQUE. Follow fallback/retry consumers before changing producer format or storage bounds.                                                                                                 |

The Email concrete classes bind app/com/org explicitly through ceremony_surface; neither request
host inference nor cross-realm lookup is admitted by these mappings. Generation standardization must
not rewrite values already bound into OTP verifiers, signed claims, jobs or stored results. The
reviewed app Ticket dump has unbounded varchar transaction/grant/result fields and native UUID
otp_generation; the Chronicle dump has unbounded varchar in the two event_uuid columns above. Those
are pending capacity/compatibility work, not permanent exceptions or evidence that migrations
already changed them. The separately named client_chronicles.event_uuid native UUID is not covered
by these producer mappings and must not be converted on the basis of the shared column name.

`app_ticket.logout_transactions.public_id` and the three realm-specific
`*_enforcement_cases.public_id` columns are self-controlled, non-secret transaction or policy
identities. New LogoutTransaction issuance uses `PublicId.generate`, retries only a collision on its
named public-ID unique index within the shared finite budget, and rejects post-creation identity
changes through the model update boundary. EnforcementCaseApplicable uses the same issuer for APP,
COM and ORG cases and rejects post-creation identity changes. Their existing issued values and
realm-local uniqueness remain intact; protocol secrets, principal references and policy state are
separate fields. The focused regression coverage is in
[`test/models/logout_transaction_test.rb`](../../test/models/logout_transaction_test.rb) and
[`test/models/enforcement_case_public_id_test.rb`](../../test/models/enforcement_case_public_id_test.rb).

`OrgNormalSignInTransaction` has a separate session-scoped `public_id` used to bind the ORG Entra
handoff to the next passkey phase. New values use `PublicId.generate`; the value is an internal
opaque transaction identity, not an Entra/OIDC provider value, protocol secret, nonce, CSRF token,
PKCE value or database primary key. Existing serialized sessions remain readable, and the signed
binding continues to enforce its existing ORG flow and phase contract. The focused boundary is
covered by
[`test/controllers/auth/org/in/passkeys_controller_test.rb`](../../test/controllers/auth/org/in/passkeys_controller_test.rb)
and
[`test/services/org_normal_sign_in_binding_codec_test.rb`](../../test/services/org_normal_sign_in_binding_codec_test.rb).

`SignInSequenceCarrier` stores a separate surface-scoped workflow `id` in the Rails session. New
sequence starts use `PublicId.generate`; this value is an internal workflow identity and is not a
provider/protocol value, secret, database primary key or public API reference. Existing UUID-valued
session payloads remain readable through the compatibility reader. The public `start!` boundary is
covered by
[`test/services/sign_in/sequence_carrier_test.rb`](../../test/services/sign_in/sequence_carrier_test.rb).

The pending-MFA payload created by `AuthenticationBase#set_pending_mfa!` has its own session-scoped
workflow `public_id`. New payloads use `PublicId.generate`; the value is not a provider/protocol
value, secret, database primary key or public API reference. The existing actor, surface, expiry and
session-issuance fields remain authoritative, and the public APP challenge boundary covers the
format contract in
[`test/controllers/auth/app/in/challenges_controller_test.rb`](../../test/controllers/auth/app/in/challenges_controller_test.rb).

`SocialAuth` stores `social_auth_flow_id` as a separate session-scoped link-intent correlation
identity. New link intents use `PublicId.generate`; the value is not the OAuth `state`, provider
value, Apple nonce, PKCE verifier, CSRF token, protocol secret, database primary key or public API
reference. The existing intent, provider, TTL, callback-state, authorization and cleanup contracts
remain authoritative. The public SocialAuth link integration boundary covers the NanoID-21 format in
[`test/integration/social_auth_link_test.rb`](../../test/integration/social_auth_link_test.rb).

Identity ceremony candidates use purpose-specific reference contracts. The TOTP enrollment
candidate, secret-credential candidate, and concrete APP/COM/ORG passkey candidates are
self-controlled, non-secret opaque references; new rows use `PublicId.generate` (NanoID-21), while
their existing unique B-tree indexes remain the database authority. The shared creation boundary
performs normal model validation, permits only the named `ref` uniqueness collision to reach the
database retry path, and retries that constraint only within `PublicId::MAX_COLLISION_RETRIES`.
Other validation or uniqueness failures propagate to the owning ceremony contract. Existing rows are
not rewritten and no migration, trigger or raw SQL was added. Focused coverage is in
[`test/services/identity/totp_ceremony_contract_test.rb`](../../test/services/identity/totp_ceremony_contract_test.rb),
[`test/services/identity/secret_credential_ceremony_contract_test.rb`](../../test/services/identity/secret_credential_ceremony_contract_test.rb),
[`test/operations/identity_passkey_registration_committers_test.rb`](../../test/operations/identity_passkey_registration_committers_test.rb)
and
[`test/operations/identity_totp_enrollment_issuer_test.rb`](../../test/operations/identity_totp_enrollment_issuer_test.rb).

`IdentitySocialCeremonyCandidate.ref` remains a UUID v4 capability reference. The APP social-link
completion form sends this value to a controller that intentionally accepts only the existing
`AuthAdmissionBinding::REFERENCE_PATTERN`; widening that shared capability boundary merely to
standardize a stored value would change an established browser security contract. The social
candidate is therefore an explicit protocol/capability exception, not evidence that its existing
UUID rows should be rewritten. The contract is covered by
[`test/services/identity/social_ceremony_contract_test.rb`](../../test/services/identity/social_ceremony_contract_test.rb)
and the end-to-end link boundary in
[`test/integration/social_auth_link_test.rb`](../../test/integration/social_auth_link_test.rb).

Credential-registration Email and Telephone transaction references are a bounded P2 slice of the
broader ceremony-purpose inventory. The six concrete realm/channel issuer paths now generate a new
`transaction_id` with `PublicId.generate` (NanoID-21), while existing UUID-v4 transaction values
remain accepted by the session and delivery-binding readers. The transaction reference is separate
from the OTP `generation`, which remains a UUID-v4 one-time proof identity, and from grant/result
identities. The transaction binding still includes the surface, channel, Root reference and browser
nonce; no host inference or cross-purpose fallback was added. The issuers retry only a collision on
the concrete transaction table's named, single-column `transaction_id` unique B-tree index, using a
fresh reference inside a database savepoint and the finite `PublicId::MAX_COLLISION_RETRIES` budget.
Unrelated validation or uniqueness failures propagate. Focused coverage is in
[`test/operations/contact_registration_otp_issuer_test.rb`](../../test/operations/contact_registration_otp_issuer_test.rb),
[`test/operations/email_credential_registration_otp_issuer_test.rb`](../../test/operations/email_credential_registration_otp_issuer_test.rb),
[`test/operations/telephone_credential_registration_otp_issuer_test.rb`](../../test/operations/telephone_credential_registration_otp_issuer_test.rb),
[`test/values/credential_registration_otp_session_value_test.rb`](../../test/values/credential_registration_otp_session_value_test.rb),
[`test/values/contact_registration_otp_delivery_binding_value_test.rb`](../../test/values/contact_registration_otp_delivery_binding_value_test.rb)
and
[`test/values/email_credential_registration_otp_delivery_binding_value_test.rb`](../../test/values/email_credential_registration_otp_delivery_binding_value_test.rb).
Other ceremony transaction, grant, result and OTP-generation issuers remain unclassified and must
not be changed by inference from this slice.

The APP TOTP enrollment child transaction is a separate self-controlled, non-secret ceremony
identity. `IdentityTotpEnrollmentIssuer` now supplies a NanoID-21 `transaction_id` for new child
rows while the step-up parent transaction, `grant_jti`, OTP secret/proof, candidate reference and
result identities retain their existing contracts. The signed grant/result payloads carry the opaque
transaction value without imposing a UUID format, and the replay store resolves it only in the APP
TOTP transaction table. A child transaction-ID collision is retried only for that table's named
unique B-tree index, inside a savepoint and within the finite shared collision budget; other
validation or uniqueness errors propagate. The generic TOTP transaction factory remains UUID-
compatible for unclassified callers. Focused coverage is in
[`test/operations/identity_totp_enrollment_issuer_test.rb`](../../test/operations/identity_totp_enrollment_issuer_test.rb)
and the surrounding TOTP ceremony tests; no protocol-secret or cross-surface format was widened.

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
staff_identity_audit_events' string PK remains an unresolved violation during the additive mapping
stage, not an unmanaged-table exception; see the staged transition above. Complete all-table
ownership, eight-role classification, reference bounds, sequence/partition and executable regression
coverage before declaring I acceptance complete. These scoped mappings do not provide that global
evidence.
