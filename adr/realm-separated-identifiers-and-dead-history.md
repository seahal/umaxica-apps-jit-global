# Realm-separated identifiers, OTP ownership and dead history

Status: accepted by the user on 2026-10-07; implementation in progress.

## Additional implementation authorization

The user approved transaction/generation-bound Email and SMS delivery, including issuer and worker
changes. Delivery must reject cancelled, expired and superseded challenges immediately before
sending; codes travel only through encrypted delivery material, never durable plaintext job
arguments or logs. No HOTP fallback is retained.

Identifier-only irreversible purge preserves its Identity and History. Whole-Identity physical
erasure may delete that Identity's histories only after applicable retention obligations, legal
holds and enforcement protections allow erasure. Recoverable, logically deleted or protected records
do not lose history. Cross-database cleanup must handle partial failure, retries and idempotency.
Unknown legal retention conditions prohibit irreversible real-data deletion. History deletion
removes internal investigation evidence but cannot change live uniqueness or prevent future reuse:
dead history is never a uniqueness namespace.

Realm/channel-limited HMAC maintenance roles, a dedicated execution path and new migration SQL DDL
are approved for local implementation and verification. Ordinary roles remain unable to modify
finalized bindings. Maintenance may change only digest and required update timestamps; owner, PII
and binding facts remain protected. Database trigger enforcement, least privilege and auditable
execution are mandatory; general trigger disabling and arbitrary exception flags are prohibited.
Production DDL, roles, secrets, connections, deletion and deployment are not authorized.

Direct deletion of orphan VisitorEmail test rows 212 and 214 is approved only after revalidating the
test database, both exact IDs, synthetic task provenance and absent owners. Any mismatch aborts
cleanup. This is test-artifact repair, not an application history deletion exception.

## Decision

APP Client, COM Visitor and ORG Operator remain independent identity realms. Each retains separate
Email and Telephone models. No global identifier namespace, cross-realm correlation, shared parent
identifier model or shared stateful Email/Telephone policy is introduced.

`OtpLockable` sharing is superseded. Email and Telephone own independent issuance, attempts,
lockout, resend and lifecycle implementations. Only side-effect-free cryptographic primitives may be
shared. Issuance, reissuance, replacement codes, expiry and cancellation preserve failure counts; an
admissible wrong comparison increments the count, and normal successful consumption may reset it.
Telephone issuance uses `otp_last_sent_at` in all three realms, never `created_at`.

The former CommonOtpPolicy constants are also removed. Each channel owns its existing lifetime,
resend cooldown and reregistration window constants directly. Generic orchestration explicitly
selects the channel's policy; it does not define a common lifetime or probe model capabilities.
Email response timing remains Email-owned. Record-backed HTTP proof removal is still in progress.
Withdrawal cleanup also preserves identifier failure counts and finite lockout deadlines; retiring
an owner is not successful OTP consumption. Its guarded whole-owner physical erase/history
integration is separate from OTP consumption and preserves retained original identifiers until
purge.

Email and Telephone binding transition policies also use separate implementation series,
`EmailContactBinding` and `TelephoneContactBinding`; the shared `ContactBinding` concern is removed.
Their public transition contract and existing database binding protections stay unchanged.

Destination verification counters also have independent `EmailOtpVerificationFailureBudget` and
`TelephoneOtpVerificationFailureBudget` owners. Each refuses the other channel rather than acting as
a shared stateful policy. Their existing scoped Valkey keys and fixed five-failure/fifteen-minute
atomic budget remain unchanged; candidate/flow/browser replacement still cannot evade that budget.
An exhausted scope also refuses correct codes. Neither success nor refusal extends the original TTL,
and malformed stored state or unavailable infrastructure fails explicitly. The bounded third-party
destination-exhaustion trade-off remains documented in `email-otp-race-condition-fixes.md`.

Short-lived OTP proof belongs to the existing realm/channel ceremony transaction, not the durable
identifier. The approved extension adds `purpose`, `otp_generation`, `otp_verifier`,
`otp_expires_at`, `otp_consumed_at` and `otp_cancelled_at` alongside existing transaction, actor,
session, candidate, operation and lifetime facts. Purposes are `sign_up`, `sign_in`, `recovery`,
`withdrawal` and `credential_registration`. A server-generated six-digit random code is stored only
as a binding-specific keyed verifier. The verifier key is separate from identifier lookup and
history keys. Delivery carries transaction/generation binding. Verification checks the entire
binding and consumes under the owning database lock, so replay and concurrent second success are
refused. Existing session-bound Step-Up Email OTP remains independent.

The ceremony's separate `otp_receipt_verifier` and `otp_result_expires_at` retain bounded evidence
after consumption. The challenge verifier is still erased. The receipt uses a channel-domain HMAC
over the original binding-specific code verifier, verification time and fixed result deadline, not a
copy of the challenge hash. Changing both receipt timestamps with SQL cannot extend its authority
without the external verifier key. Its deadline is the earlier of verification plus sixty seconds
and the original transaction expiry; reads never slide it. Receipt APIs require the same code,
purpose, actor, session, operation and candidate, plus a still-pending original parent. Normal
verification and delivery continue to refuse consumed proof. Both fields and the original terminal
facts, including the original parent deadline, are immutable through model writers and six
independent realm/channel database UPDATE triggers. The user approved this bounded forward DDL on
2026-10-08 after twelve direct-SQL erasure regressions reproduced the gap. The triggers protect
verified and cancelled OTP facts and their original binding, including Email's bootstrap parent
reference, without granting privileges or permitting owner, PII or binding substitution. Ordinary
parent lifecycle completion remains permitted. Rollback removes only the newly added functions and
triggers; it neither rewrites proof nor disables existing protections. Transport and verification
explicitly reject non-finite parent and OTP deadlines. Database checks enforce
pending/verified/cancelled proof partitions, keyed-hash format, nonempty binding and finite
parent/proof/receipt deadlines, with receipt duration at most sixty seconds. Typed UUID generation
replaces the obsolete decimal counter and JSON version/shape. These checks were extended after six
direct-SQL malformed-verifier failures. This foundation does not certify that every legacy
signup/registration caller has migrated to ceremony-owned proof.

`EmailSignUpOtpIssuer` is the independent Email issuance implementation for APP and COM. Its session
binding derives from a domain-tagged original signup flow public reference and nonce digest;
admission requires the actual browser nonce, not that public reference. Flow, owner and Source locks
preserve ownership and recheck the original deadline after waiting. The Source retains failed
attempts and only its explicit last-sent timestamp changes; random proof and generation live on the
typed Email ceremony. Resend replaces generation on that same ceremony rather than creating another
identifier-owned code. Its in-memory result redacts code inspection. APP/COM signup Email creation,
resend and verification controllers now use this series. Their GET form query is read-only and
checks availability, not authorization to consume proof or establish a Root. Remaining
channel/registration dependencies and cross-database fault verification still prevent claiming
complete OTP ownership migration.

The corresponding `EmailSignUpOtpVerificationCommitter` requires that original nonce and fresh
flow/owner/candidate admission. Its independent Email destination budget admits fresh atomic
consumption; a candidate reset follows that Ticket boundary and fresh authority/receipt checks. The
reset compares failure-count/lock/update-time facts observed during consumption, preserving failures
that arrive later. A failed Ticket consumption leaves candidate failures unchanged; a later Source
failure can leave an already-consumed bounded receipt for the original retry. These are separate
database operations, not a distributed transaction. `already_verified` is bounded same-proof
evidence, never another successful verification or reset. It rechecks the receipt deadline after
destination-budget waiting. `EmailSignUpOtpDeliveryGuard` separately checks the current parent nonce
binding, owner, candidate, destination and generation under locks immediately around its transport
block. The immutable Email delivery value uses `sign_up_flow_ref`, `sign_up_email_transaction_ref`
and `sign_up_email_otp_generation`, not a HOTP counter. These pieces are carried by the concrete
APP/COM Noticed producers and Mailers. The Mailer checks the original transaction immediately around
delivery, after rendering. The in-memory random code is encrypted before queueing; neither its keyed
verifier nor identifier HOTP fields reconstruct it. Signup does not emit the old identifier
verification link, which belongs to authenticated credential registration rather than the original
guest signup parent. This production-path integration has targeted controller coverage;
cross-database failure handling remains separately under verification.

The independent Telephone signup series is also wired into APP/COM creation, resend and verification
controllers. `TelephoneSignUpOtpFormQuery` is read-only. Signup SMS uses the encrypted version-three
envelope `{version:3,to,title,body,otp_binding,otp_code}`; its fixed binding tuple is
`[surface,"sign_up",original_flow_ref,telephone_transaction_uuid,generation_uuid]`. All values are
server-issued, and the random code occurs only inside the encrypted envelope. The worker derives the
candidate from that typed transaction and keeps its fresh original-parent, owner, destination,
generation and code checks held through transport. Old version-two signup counter tuples are
refused, not reconstructed. Current credential-registration SMS uses its own version-four envelope.
Version-one generic SMS is a separate transport, not a signup fallback; complete legacy credential
payload retirement remains acceptance work.

Both signup verifiers admit wrong guesses against a still-live consumed receipt through their own
candidate and destination failure budgets. They do not bypass rate limits merely because normal
single-use verification refuses consumed proof. Expired receipt reads admit neither comparison
attempts nor renewed authority. Correct retained evidence remains non-fresh success and does not
reset failures. Both channel verifier encodings normalize keyed expiry timestamps to UTC, so a
request timezone cannot invalidate valid proof when a worker or retry uses a different timezone.
Email authentication, resend and reentry no longer include `CommonOtp` merely to obtain response
timing. Their Email-only `EmailOtpResponseTiming` retains existing explicit response floors and
dummy comparison, without Source proof access, failed-attempt state or callbacks. Dummy generation
uses CSPRNG output rather than HOTP. Telephone policy does not include it. The unused `CommonOtp`
implementation is removed after all production inclusions disappeared. Both candidate creators
require a new, unowned Source; neither transfers an existing identifier or replaces a preattached
persisted/unsaved owner.

Signup issuance and verification preserve the existing durable parent-expiry contract. After an
admitted operation discovers an overdue parent, its channel-specific operation calls
`SignUpTermination` outside the proof-operation locks. The existing named transition schedules
retention and artifact cleanup; it does not reset failed attempts or create dead History merely for
logical deletion. A malformed browser binding does not gain this mutation path. Existing terminal
parents remain absorbing, including after an earlier clock is restored in a test. Signup delivery
guards preserve the same expiry boundary after refusal. They recheck the original typed
session/actor/candidate, operation/purpose and generation before terminalizing an overdue parent;
the child and Source locks are released before compensation acquires dependent locks. This is not a
fallback transport or a new code issuance path.

Signup Source finalization validates the original live checkpoint, cleared OTP requirement,
browser/owner/candidate binding and historically consumed typed ceremony. It does not require a
fresh sixty-second verification receipt at late passkey/checkpoint completion. Independent Telephone
finalizers no longer clear identifier OTP fields or failure counts; APP retains its required active
passkey and named Client promotion. Existing Source audit intent commits with the binding and
supports only original-operation idempotent reconciliation after Ticket failure.

Email keeps its existing separate verified-status and finalized-binding facts. Its OTP HTTP
controllers now call `mark_sign_up_verified!` instead of directly assigning a status FK; this named
writer checks the original browser and consumed bounded receipt without resetting failures.
`finalize_sign_up_binding!` accepts only the known pending or already OTP-verified signup status,
requires durable original proof and finalizes the binding; APP owner promotion uses
`Client#finalize_email_sign_up!`. A verified but unfinalized Email does not gain effective-binding
lookup authority. The complete HTTP fault matrix remains separately under verification.

ORG Telephone registration now also uses its own ceremony-bound random proof, explicit numeric
candidate reference, encrypted version-four generation binding, read-only form query and named
`OperatorTelephone#finalize_telephone_registration!` writer. Its finalizer retains the existing
passkey-only/current-Root policy and commits Source before Ticket receipt. ORG has no existing
registration audit outbox; this change does not invent an APP/COM audit dependency or claim one.
APP/COM/ORG management-create callers also enter their own registration ceremonies. Their focused
controller and authorization matrix passed 65 tests and 435 assertions (seed 50641). Complete
Source-proof retirement remains under verification.

The independent Email credential-registration series now owns the APP/COM settings HTTP proof. It
keeps the original Root and browser digest on the ceremony using the existing `session_ref` column:
before, a plain Root public reference; after, JSON encoding of the fixed tuple
`[1,original_root_public_ref,browser_digest]`. The digest domain includes realm, channel,
transaction UUID, Root reference and original high-entropy Base browser nonce. The immutable codec
has no lifecycle or policy state; old plain-Root encoding is not accepted by the new series.
Issuance and verification preserve the existing live Root/device/candidate requirements while
placing the random verifier, consumption and bounded receipt on the Email ceremony. APP/COM settings
Email HTTP callers now use this series and store the original child UUID in their surface-local
session. They do not issue or verify Source HOTP or registration JSON. Those legacy columns and
remaining Telephone/ORG callers still require retirement before overall completion. The Email
registration delivery binding moves from `{contact_ceremony_transaction_ref,contact_otp_counter}` to
`{contact_ceremony_transaction_ref,contact_otp_generation}`. Both UUIDs are authoritative ceremony
facts supplied by issuance; the random code travels only in the existing encrypted transport
payload. The dedicated late guard resolves the original Root from the typed session tuple and keeps
current owner/device/Root/candidate/transaction locks through transport. Notifier and actual APP/COM
Email HTTP integration tests passed. Email registration reissuance retains the original OTP deadline
while replacing generation and keyed verifier; it does not renew the parent or reset candidate
failures. The Email-specific primitive also rejects expired, cancelled and consumed challenges
rather than recreating them.

Telephone registration has its own resend writer and ceremony primitive. It rechecks the original
actor, current Root/device, browser, candidate, destination and pending transaction under their
owning locks, retaining both original deadlines. It rotates the generation and keyed verifier,
preserves candidate and destination budgets, and refuses consumed, cancelled or expired proof. It
does not import Email cooldown or bootstrap policy. A Source timestamp-write failure rolls back the
replacement Ticket proof before the owning transactions leave their locks; this is not a
distributed-commit guarantee. APP/COM resend and all three realms' primitive checks passed in the
226-test focused selection recorded in
`evidence/2026-10-08-telephone-fixed-deadline-resend-5R9B.md`.

New registration issuance also supersedes the original browser's previous pending challenge for the
same actor/candidate/Root. Both independent channel issuers derive the previous transaction's exact
session tuple from its UUID and the supplied original browser nonce before cancellation; they do not
cancel another browser's challenge. Cancellation and replacement share the owning Ticket
transaction. Six failing stale-delivery cases reproduced the former gap across all realms and both
channels; `credential_registration_otp_supersession_test` retains foreign-browser cases.

Bootstrap ownership moves from no original-parent association to nullable
`bootstrap_ceremony_transaction_ref` on each realm's Email ceremony, with a same-realm foreign key
to the Step-Up ceremony's unique transaction UUID. Ordinary registration and other OTP purposes
leave it null; a CHECK restricts a non-null parent to registration/credential-registration. The
parent reference joins the keyed verifier and receipt binding, and model terminal protection.
Issuance caps the child deadline to the original parent's deadline. The independent Email finalizer
retains current policy, original Root/browser/admission, return-target and live credential checks,
or the original bootstrap permission, rather than accepting another pending permission on the same
Root. Source binding and audit commit before original Ticket receipts; retry checks bounded keyed
evidence and exact audit provenance. A consumed registration receipt can prove only its original
credential-registration result, not ordinary OTP verification or another operation. Concurrent
indexes and subsequent FK/CHECK validation are separate forward migrations. The APP/COM Email
settings controllers use the stored original parent, not a new permission found on the same Root.
Delivery, verification and resend independently refuse an original cancelled, expired or invalid
parent. The named Source model transition validates typed ceremony evidence before changing the
binding; operations do not write verified status directly. Whole-suite verification and
comprehensive fault coverage remain final acceptance work; targeted success is not overall
completion.

Actual APP/COM browser receipt-fault journeys now passed targeted checks: Source facts and audit
commit before either Ticket lifecycle receipt; wrong retained-code guesses still reach independent
failure budgets, then correct original-code retry reconciles without Source/audit rewrite or new
Root freshness. Receipt admission checks bounded pending facts, original Root/browser/Parent/
Session/admission, current policy and Source audit provenance; it does not authorize finalization or
assert that the submitted code is correct. Verification and finalization retain keyed comparison.
The bootstrap Session's persisted state is `PENDING` and its deadline is `discard_at`, not the child
ceremony's lowercase pending state and `expires_at`.

ORG settings Email now uses the same explicitly typed Email proof series without APP/COM binding
columns or a bootstrap permission. Its existing passkey-only requirement is canonical in
`OperatorEmailPolicy`. `OperatorEmailRegistrationOtpFinalizer` checks original Operator/Root/
device/browser/candidate, current policy and current passkey; `finalize_email_registration!` owns
the Source status write. Source commits precede the original Ticket receipt. Locked pending
identifiers are retained with their failure state rather than purged to clear the registration. No
new ORG identifier fields or user-facing endpoints were introduced. Telephone settings in all three
realms have their independent issuer/verifier/finalizer and bound SMS series wired. Focused HTTP
coverage passes, while broader authentication regression verification remains open. The unused
shared signup/registration issuer, finalizer, delivery and `SignOtpCeremony` definitions are removed
after caller migration; the post-removal focused selection passed 333 cases. Source HOTP/context
columns and their remaining fixture references still await complete retirement. Full verification
remains open.

Internal Email and Telephone transactions can name the supported OTP operations independently of the
signed registration protocol. `IdentityEmailCeremonyContract::OPERATIONS` and its Telephone
counterpart remain restricted to registration/replacement: recovery or withdrawal proof cannot
become a signed registration permission.

APP/COM withdrawal and enforcement-recovery reentry now use Email ceremony-owned random proof with
an opaque browser reference, not the identifier's HOTP. Issuance preserves existing failures and
updates the explicit issuance timestamp only; an admitted success resets candidate failures.
Destination budget admission precedes atomic consumption and expiry is rechecked after the admission
wait. The realm-specific Notifiers carry encrypted code, the Source recipient GlobalID and
`email_ceremony_transaction_ref`/`email_otp_generation`, never plaintext code or recipient address.
Their existing argument-redacted Noticed job invokes the concrete Mailer without another queue.
Concrete Mailers lock the original Source and transaction, check owner/candidate/destination, and
recheck proof immediately before sending, including expiry crossed while rendering. Reentry does not
accept the historical counter-based payload. Other legacy caller migrations remain incomplete and
their acceptance remains unchecked. No normal authentication session is issued by reentry proof.

The keyed verifier also binds the candidate's normalized destination digest. Changing a pending
ceremony's destination invalidates both verification and delivery of its previously issued code; the
same candidate reference alone is insufficient. Terminal proof protection includes that digest.
There is no alternate verification format for codes issued before this binding change.

The existing APP/COM sign-in challenge remains owned by its admitted Auth ceremony. It generates the
random decimal code directly with the CSPRNG, without even an ephemeral HOTP generator.
`AuthEmailOtpVerificationResult#success?` means the first consumption only. A subsequent original
ceremony retry returns `already_verified`, not a second consumption. The controllers explicitly use
`verified_evidence?` to continue from that still-current immutable receipt; this does not create
fresh verification, slide its result deadline or bypass the Root establishment checks. Concurrent
verification returns exactly one successful consumption and one retained receipt.

Live lookup uses six independent keys: `{APP,COM,ORG}_EMAIL_ADDRESS_HMAC_KEY` and
`{APP,COM,ORG}_TELEPHONE_NUMBER_HMAC_KEY`. Concrete models or explicit realm arguments select the
key, never request hosts. Missing keys fail closed, without legacy global-key fallback. Emergency
rotation stops and recalculates only the affected realm/channel, retaining the single-digest-column
maintenance-window approach of `identifier-hmac-emergency-rotation.md`.

Active Record Encryption requires independent APP, COM and ORG current-write/previous-read keyrings.
Realm-owned encrypted PII is assigned by its actual domain ownership, not merely its database
location. Shared-domain data requires an explicit assignment; it is not assigned APP merely because
a shared record lives in APP Ticket storage. No realm ciphertext falls back to the old global
keyring. The inventory identifies 51 concrete models and 108 encrypted attributes. This change
assigns only the six identifier models to realm keyrings; other encrypted attributes retain their
existing non-identifier keyring. This is not a fallback for identifier ciphertext. Shared-domain
records, including AccountAccessEvent and AvatarMoniker, are not silently assigned to APP by their
database. The detailed inventory is in `docs/security/identifier-encryption-inventory.md`.

The identifier keyrings require `{APP,COM,ORG}_ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY` and
`{APP,COM,ORG}_ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT`. Optional
`{APP,COM,ORG}_ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY_PREVIOUS` is a JSON array of previous secrets.
Current writes use the last key and reads try the owning realm's current/previous keys only.
Derivation binds the realm/domain even if configured values accidentally coincide. Invalid
previous-key JSON fails with a sanitized configuration exception; neither the input nor parser cause
is disclosed. The existing non-identifier keyring also places previous secrets before its current
secret; global previous encryption schemes are disabled because Rails otherwise attaches them to
explicit attribute providers. Missing required realm configuration raises; there are no derived
local defaults.

Each realm/channel enforces live normalized uniqueness in its own database. Dead history never
participates in lookup, authentication, recovery or uniqueness.

Signup service admission requires the initiating browser nonce from the concrete APP/COM locator
session. A public flow ID cannot substitute for it. The digest comparison runs before work and again
after refreshing the locked Ticket, preventing stale model snapshots from admitting a rotated nonce.
Malformed encoding is refused before Rails blank/format predicates. This admission hardening does
not complete the outstanding migration of signup proof out of identifier rows.

## Irreversible history boundary

The six independent models are `ClientEmailHistory`, `VisitorEmailHistory`, `OperatorEmailHistory`,
`ClientTelephoneHistory`, `VisitorTelephoneHistory` and `OperatorTelephoneHistory`. Their shared
column interface does not imply shared stateful model inheritance:

```text
id
user_id | visitor_id | staff_id  # owning realm identity FK
fingerprint
attached_at
detached_at
created_at
```

There is no raw or encrypted identifier, live lookup digest, live public ID, status, history public
ID or `updated_at`. Fingerprints have neither uniqueness constraints nor standalone indexes. History
insertion is allowed only at irreversible physical purge: lock the identifier, derive its
fingerprint from normalized PII, insert history, physically delete the identifier and commit on the
same owning database transaction. Logical deletion and recoverable retention do not create history.
History cannot restore or reactivate an identifier; later reuse can create additional history rows.

Ordinary model destruction and the dedicated channel purgers use independent Email and Telephone
archive callbacks, explicitly registered by each concrete model. The callback locks the persisted
owner and freshly loaded Source row, rejecting unsaved owner/primary-key substitutions and deriving
the fingerprint from database PII rather than unsaved caller edits. A scheduled recoverable or
retained row cannot bypass its deadlines through ordinary destruction. Protected Email, existing
legal holds and enforcement protections refuse deletion without retaining a history-only result. A
later destruction refusal rolls back the inserted history. Due ORG whole-Identity erasure now locks
and reloads the Operator, rechecks both retention deadlines and enforcement, and performs identifier
purge, deletion of that Operator's two history collections and Operator deletion in one Zenith
transaction. Protected Email refuses the transaction, retaining both the Identity and its existing
histories. Existing idempotent cross-database child cleanup runs before that local commit; it can
partially succeed, but a failure leaves the Operator available for retry. No distributed transaction
is claimed. This removes investigation evidence for the erased Identity but changes no uniqueness or
reuse reservation: histories never reserve identifiers. APP/COM withdrawal retirement now preserves
original encrypted identifiers and immutable lookup digests rather than replacing them with
synthetic PII before archive creation. Independent named Email and Telephone model writers lock the
fresh terminated owner before the Source row, clear the legacy challenge, preserve failure counts
and locks, suspend authentication and schedule physical collection using the owner's retention
deadline. A longer explicit Source deadline is not shortened; an unknown/infinite owner deadline
remains unbounded rather than authorizing deletion. Logical retirement creates no history. After
permitted identifier-only collection, the history fingerprint matches the original PII and its
Identity remains present. Existing Client/Visitor model destruction admits physical erasure only
after a fresh owner lock, both retention deadlines and absence of active legal/enforcement holds.
The explicitly registered final callback deletes only that Identity's two history collections after
dependent Source destruction and before parent DELETE, within the same Source transaction. Protected
Contact failure rolls back earlier Source archives and preserves prior history. Idempotent
cross-database cleanup precedes Source children; dependency failure leaves the owner and history
available for an identical retry, without claiming a distributed rollback. RetentionPurgeJob still
retains APP/COM Identity tombstones; no automatic whole-Identity erasure or public history endpoint
is introduced. Raw/bulk parent deletion is not an admitted erasure interface and restrictive history
FKs remain unchanged.

Fingerprints use independent `{APP,COM,ORG}_{EMAIL,TELEPHONE}_HISTORY_KEY` secrets: normalized
identifier -> keyed HMAC -> randomly salted Argon2id at the repository's pinned production costs.
Live keys are not reused. Fingerprint generation and valid candidate matching explicitly refuse a
history secret equal to any configured live identifier HMAC secret. Absent live lookup keys do not
become a history dependency: history still requires its own secret and never substitutes a live key.
Candidate matching, where authorized, is scoped to a particular identity; there is no cross-identity
fingerprint lookup API.

History is pseudonymous personal data, not anonymous data. Its purposes are limited to internal
lifecycle/security investigation, authorized operator investigation and formal legal/audit/privacy
procedures. It is excluded from ordinary Web, BFF, native/public API, export, activity and MCP
interfaces. Formal access/erasure requests are assessed separately; product invisibility does not
mean legally absolute nondisclosure. No IP, User-Agent, request parameters or partial identifier
attributes are retained. Append-only records remain deletable under applicable retention and legal
procedures, respecting existing holds; permanent retention and new per-row hold flags are not
assumed.

## Superseded guidance and deployment

The shared-policy and attempt-window-reset portions of `email-otp-race-condition-fixes.md` are
superseded; its row-lock atomicity requirement remains. References to `OtpLockable` consolidation in
older plans describe historical decisions, not current recommendations. The user-named
`plans/rails-model-gentle-creek.md` and `checklist-4-swift-map.md` were absent at the inspected
commit.

This cycle is undeployed. No historical data compatibility, dual reads/writes, HOTP fallback or
legacy global-key fallback is required. Migration-owned schema changes are still required; this
decision does not authorize production mutation, external writes, secret rotation or broad DB
resets.

The three OTP mailers also reject the old plaintext verification-token field, including mixed
plaintext/encrypted payloads. The optional encrypted field is the sole token source; absence means
no verification link. Current adapters and Noticed issuance encrypt before queueing.
