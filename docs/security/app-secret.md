# app Secret implementation boundary

Physical collection of an unconfirmed candidate requires both its own discarded
audit and its allocation's terminal audit to be committed in Chronicle. Partial
delivery leaves the candidate intact. Withdrawal uses its credential-specific
terminal audit. DELETE and the surviving purged outbox remain one Source
transaction; full audit identity checks and retention holds still apply.
Signup payload-failure allocations remain held while the original flow can
continue. After its verified terminal outcome and proof-retention deadline,
collection uses the original `payload_unavailable` audit rather than changing
its reason to match the later flow outcome.

This document describes the current Phase 1 foundations and distinguishes the
approved target from unfinished journeys. See the [rebuild ADR](../../adr/app-secret-phase1-rebuild.md)
and [issuance count policy](app-secret-issuance-count-policy.md).

The protected Base presentation endpoint retires an unavailable candidate payload
with the existing `payload_unavailable` audit reason. It repeats current owner,
session and scoped Step-Up checks, atomically discards unconfirmed candidates and
releases their reservation. Explicit user cancellation retains `flow_canceled`.
Signup delivery uses the same retirement mutation after rechecking its original
flow, browser nonce, pending Client and saved registration. It leaves the saved
Passkey and uncleared registration requirement intact. Unavailable signup payloads
now return 410 after retirement, rather than the generic 403 authorization denial;
invalid authority remains a 403. Explicit new delivery attempts after this failure
still need an implemented UI and replay-safe operation contract.
No field, event name or reason enum was added by this correction. The current
HTTP and operation results are recorded in
[payload failure evidence](../../evidence/2026-10-05-app-secret-payload-failure-boundaries-6K3P.md).

The user accepted the operational lifetimes on 2026-10-05 (UTC): issuance and
presentation payload 600 seconds, terminal purge delay 86400 seconds, delivered
source outbox retention 604800 seconds, and processing proof retention 2592000
seconds. Each remains mandatory explicit configuration. Presentation and confirmation
also obey the shorter bound operation and flow deadlines; retransmission does not
extend them. Saved unused Secrets have no short lifetime. Holds, unresolved claims
and live continuations take precedence over physical collection eligibility.
This approval does not authorize shared-database application or deployment.

Application cleanup uses the existing Solid Queue retention queue, rather than a
database VACUUM job. Authentication exclusion and source audits commit synchronously.
The periodic retention job rescans for delivery and dependency-gated deletion.
`ClientSecretIssuanceCollectionJob` advances a bounded cursor past retained allocations
and captures a fixed upper ID bound; allocations created during a pass wait for the
next periodic pass. Continuations recheck expiry, retention, holds and durable audits.
Expired allocations clear their encrypted payload and record retirement through the
existing expiry invalidator even when an earlier allocation remains live. Failed
enqueue leaves source state available to a fresh scan. A real Solid Queue worker
verified continuation and later deletion while preserving retained authority and the
purge outbox. Other lifecycle stages and replay-barrier retirement remain incomplete.
Allocation collection also compares Chronicle action, operation, timestamp, actor,
subject, result, reason, metadata and changeset against the delivered source event.
A matching UUID with conflicting facts leaves the allocation uncollected.
The lifecycle credential and signup phases also advance bounded cursors past
held credentials and live signup allocations. Existing claim and purge operations
retain their own locks and authority checks. Each batch delivers source audits
before attempting credential collection; unresolved outcomes never regain eligibility.
Retired signup allocations, including zero-count omissions, are collected only
while the original matching Ticket flow is locked and terminal. Source retirement,
payload erasure, absence of candidates/receipts, proof retention after both the flow
and purge deadlines, durable reason-bearing terminal audits and credential-purge
audits, and holds gate deletion. Cancellation does not fabricate signup activation.
The canceled zero-count path is operation/job-tested. Public operations additionally
verify CANCELLED/EXPIRED/FAILED with counts 0/1/2, including unconfirmed and confirmed
candidates; candidate purge audits must be delivered before allocation collection.
Receipt collection now has its own bounded fixed-horizon lifecycle continuation.
An HTTP integration journey establishes two real canonical root logins, retains
the first receipt under legal hold and collects the later receipt through the
continuation while preserving both usable root tokens. Remaining race/deadline
coverage and replay-barrier retirement still need work.
The writer concurrency matrix covers A=18/19/20 for manual/manual,
manual/registered-Passkey and registered-Passkey/registered-Passkey operations
from separate browser sessions and PostgreSQL connections. Queue barriers start
both competitors without sleep-based scheduling. Positive allocations serialize
to one reservation and one explicit conflict; capacity-zero Passkey operations
record omissions with no encrypted payload or reserved capacity. A and R remain
separate, including a two-slot Passkey reservation at A=18. This is allocation
coverage, not proof of every confirmation or root-issuance race.
Additional separate-writer tests prepare and present an actual manual candidate,
race storage confirmation against an admitted browser's claim, and retry the
confirmation after claim. Unconfirmed input is refused; confirmation never
reactivates a claim, duplicates its audit or releases claimed authentication
material. Claim remains distinct from session issuance.

The local Base HTTP concurrency journey starts with a legitimate Base admission,
claims through Auth with CSRF enabled, and submits the resulting handoff from two
in-flight copies of the same pre-completion browser. Separate writer connections
produce one canonical root token, one matching receipt and one browser's login
cookie; the other result is a conflict. Separate cancellation/expiration cases
hold the Client lock until PostgreSQL confirms a pending HTTP callback is blocked,
commit the Ticket terminal transition, then release that callback and send another
stale result directly. Neither establishes a root token, receipt or cookie, and
the claim retires without becoming reusable. The blocked callback returns 400;
the later terminal result follows the existing authorization-denial redirect to
the guest landing page, which is also followed and checked. No response contract
is changed for these tests. The configured two-connection test pool supports two
parallel completions or one lock observer plus one blocked terminal callback.
These local-flow checks do not establish every OIDC cancellation/issuance race.
Input boundaries are also exercised through admitted HTTP with CSRF and the
existing online limits enabled: missing/null/empty, numeric zero, array/object,
31/33 characters, excluded Base58 characters, NUL, case mismatch and an unknown
well-formed value are rejected without changing credential facts, claims, tokens
or Source audits. Distinct request addresses keep independent cases below the
online limits; these tests do not simulate rate-limit infrastructure failure.
Native form tests cover 31/32/33 characters and the Base58 alphabet in the DOM.
The Secret input has no supplied value attribute or application Secret state;
its initial value is empty. A well-formed unknown value remains a server-side
decision, and native constraints do not normalize case or modify submitted text.
If allocation expiry precedes later signup cancellation, collection preserves the
original `flow_expired` audit. It accepts that reason only for an unconfirmed
allocation whose immutable expiry preceded its recorded discard time. It does not
rewrite the earlier source retirement to match the later Ticket terminal reason.

E2E execution was explicitly excluded from this implementation request on
2026-10-05 (UTC). Earlier browser observations remain evidence only for the cases
actually run; current verification continues with public-operation, HTTP and real-DB tests.

## Current implementation

ClientSecretCredential belongs to Client through client_id in app Zenith and to
its issuance. Confirmed, unclaimed, unrevoked and undiscarded rows contribute to
active capacity. Pending candidates do not authenticate. Account availability is
a separate login condition and does not erase the active count.

The old app Secret kind/status tables and usage counters are absent from the new
disposable-DB schema. The migration does not convert legacy values. Current
migration-based reconstruction passed across a new 20-owner disposable fleet,
with no pending versions. A separate Source reconstruction stopped at the old
three-table checkpoint, ran the app-only rebuild and verified unchanged OIDs for
114 unrelated tables, including Client and Passkey, before applying subsequent
Source migrations. The fresh DB model/lookup/count selection passed 29 tests.
These checks use schema reconstruction rather than legacy credential inheritance;
that is not approval to apply the irreversible migration to a shared database.
The unconnected app Emergency login operation, old app CRUD services and legacy
LOGIN inventory task have been removed. The shared management registration concern
has only com/org service branches. Other old app kind/status, recovery and
withdrawal references still require retirement during the application cutover.
The historical Ticket Emergency proof table remains present in the disposable
schema; it is not the new canonical success receipt and still needs scoped cleanup.

Manual POST retransmission after storage confirmation is currently an open
defect: confirmation clears its Rails operation locator and a later create can
reserve another allocation. A public HTTP test reproduces the extra allocation.
The pending revised form/session and Source outbox proposal binds a server-issued
operation to the current session, preserves ordinary retries and refuses stale
forms. That shape change has not been approved or implemented; prior successful
manual journeys do not establish this post-confirmation retransmission boundary.

The old app `/identity/recovery-secret` reveal route is retired, including
authenticated requests with a valid old reveal reference. It no longer consumes
the old receipt or returns plaintext on GET. The com reveal route and its existing
single-delivery contract remain separate. The replacement explicit POST presentation now uses a dedicated no-store document; it does not put plaintext in Inertia props.

Signed-in app Passkey registration no longer uses the bootstrap Step-Up exemption
on its registration, options or verification endpoints. A normal Secret-derived
Client root session without another available Step-Up method receives a terminal refusal
instead of a redirect to its own registration page. A separately verified,
session-bound Passkey Step-Up finalized by Base can authorize registration from
a normal Secret-derived session. Initial signup without a Client root session
does not use this refusal branch. Other bootstrap entry points still require
their own audit; this change does not establish complete credential-addition safety.
BaseStepUpAdmissionIssuer also rejects bootstrap admission for a Secret-derived
Client Token after rereading it under the Ticket lock. This covers both Passkey
and TOTP registration and creates no ceremony transaction or Step-Up session.
The existing non-Secret first-registration contract remains separate; a normal
Secret login cannot use that contract to acquire its own new Step-Up method.

ClientSecretLookupQuery resolves an indexed digest and verifies the complete
32-character value using the existing HMAC primitive and Argon2 verifier. Invalid
formats or unavailable credentials return no match; infrastructure failures are
not silently converted into a normal mismatch. This query neither claims a
Secret nor establishes a session.

Ownership policy covers ordinary authenticated reads. ClientSecretNameCommitter
also locks and rereads the current Token, requires existing scoped Step-Up and
an available owned credential, and commits only name plus source audit. It
rejects cached evidence from expired, revoked or restricted sessions. Base app PATCH `/secrets/:id` now calls this operation after its scoped Step-Up gate.

ClientSecretManualReservationIssuer reserves one slot after rereading the current
session and existing operation-specific Step-Up under the Client lock. The caller
supplies a server-issued operation UUID and an explicit expiry duration; this is
not a browser-selected authorization identifier. An authorized retry returns the
same fixed allocation, including its expired or terminal state, without extending
the deadline. Another live operation conflicts even when numerical capacity remains.
At twenty active Secrets manual addition fails without a zero-count issuance.
Reservation and its source event commit together on Zenith. No candidate or
plaintext is generated by this step. Base app POST `/secrets` applies scoped Step-Up and issuance rate limiting, reserves one slot, and prepares the encrypted fixed candidate collection. POST `/secret_issuances/:id/presentation` performs single delivery; PATCH `/secret_issuances/:id` records storage declaration.

ClientSecretManualIssuanceInvalidator requires the owning current session and the
same scoped Step-Up before canceling an unconfirmed manual allocation. It discards
pending candidates, removes the encrypted payload and commits cancellation plus
source audit in one Zenith transaction. Cancellation releases R, preserves A and
the current session, and cannot be cleared or replaced through an ordinary model
save. An authorized replay returns the same terminal facts without extending
retention. Confirmed or omitted allocations are refused; an expired allocation
remains expired rather than being recorded as user-canceled. A canceled or omitted
issuance cannot create a storage-confirmed candidate through model validation.

Stored presentation, storage-declaration and cancellation timestamps are immutable
through ordinary writers, update_column(s) and touch. Clearing or replacing a fact is refused, so a
confirmed issuance cannot regain its reservation and a presented issuance cannot
return to the unpresented phase through such an update. Re-saving the same fact
is allowed through ordinary assignment and validated save. Direct persistence of
an already recorded timestamp is rejected. Those guards alone do not implement protected presentation or
direct-SQL enforcement.

ClientSecretStorageConfirmationCommitter implements signed-in storage declaration
for a presented manual or Passkey-registration issuance. It locks the Client,
rereads and locks the owning Ticket Token, and locks issuance and candidates in
that order. Current session availability, restriction, operation-specific scope,
freshness and session binding are verified again. Signup issuance is not admitted
by this operation. It requires exactly the planned candidate count and one matching
`secret.presented` source fact per candidate at the issuance presentation time;
another candidate set, missing evidence or a terminal candidate is refused.

Storage declaration, every candidate's activation and source audit commit in one
Zenith transaction. An audit failure rolls back the entire batch. A/R is checked
before and after conversion; no session or authentication freshness is changed.
An authorized duplicate confirmation returns the same confirmed facts without
additional events. An expired, canceled, omitted or unpresented allocation cannot
be confirmed. This operation does not generate, encrypt or present plaintext and
is connected to protected Base management HTTP requests. Signup uses its
separately authorized flow confirmation path; it does not bypass this signed-in
operation's Step-Up requirement.
Separate writer/barrier tests cover confirmation racing cancellation: one terminal
result wins, the losing mutation is refused, and reservation, eligibility and
source audit agree. The earlier provenance gap is superseded by the current
registration ceremony and its bound issuance operation. The actual signup and
signed-in HTTP journeys verify saved Passkey registration followed by delivery
and storage declaration; prepared batch tests alone do not establish that binding.

Credential confirmation uses a narrow model write interval around a validated
save. Source declaration and creation events are required; the interval closes
on success and failure. Ordinary assignment, raw attribute assignment,
update_columns and touch cannot change confirmed_at. The installed Rails
readonly writer and persistence hooks were inspected for this boundary; no
validation-skipping UPDATE or framework-wide configuration change is used.

ClientSecretIssuanceExpiryInvalidator performs autonomous retirement of an expired
allocation under the same Client-first writer lock order. It clears any remaining
opaque payload and discards unconfirmed candidates with matching source events.
Expiry already frees R before this cleanup runs. Cleanup neither creates a
cancellation fact nor changes any confirmed credential's lifetime. Anonymous actor
columns and an explicit executor job identifier distinguish autonomous work from
the original human operation. A replay requires existing retirement evidence and
does not extend the purge deadline. Audit failure rolls back the cleanup. The
caller must provide the retention duration; a periodic job and its production
duration policy are not connected yet.

ClientSecretRevocationCommitter implements a draft owner/session/Step-Up protected
retirement operation. It locks Client, current Ticket Token and credential in
that order, changes revocation and discard facts together, and writes separate
revoked/discarded source events under one operation reference. It preserves the
current session and accepts an explicit caller-supplied retention duration instead
of inventing a production default. Repeating retirement does not extend its
deadline or create more audit events. Last-login-method protection uses the existing
guard; confirmed available app Secrets now contribute to login inventory while
remaining absent from Step-Up inventory.

Retirement now uses a dedicated validated model transition, with the source events
and credential save in one Zenith transaction. Invalid persisted metadata rolls
back both. Ordinary assignment, raw attribute writers, update_column(s) and touch
cannot introduce, clear or replace a persisted revocation. The narrow lifecycle
write interval belongs to the validated transition and closes on failure as well
as success. Source audit remains a persistence prerequisite, not browser authorization.
The management operation still verifies the current session and Step-Up.

Once a finite discard_at has been persisted, ordinary assignment, direct attribute
updates and touch cannot clear or replace it, including restoration to Infinity.
Changing a nonsecret name does not change the discard fact or restore eligibility.
Initial cancellation, expiry and audited revocation can still set the first discard
timestamp. This model guard does not authorize those operations or protect arbitrary
bulk SQL writes.

HTTP retirement delegates physical deletion to the audited Secret purger; the
generic retention job skips direct app Secret deletion. A source outbox record
alone is not Chronicle delivery or permission to physically delete a credential.
Complete proof and outbox collection remains unfinished.

OIDC Secret integration remains partial. The app Ticket schema now provides a
nullable unique `ClientOidcAuthorizationTransaction#secret_sign_in_flow` reference
with an enforced restrictive foreign key. It preserves the existing exclusive
ceremony purpose/transaction references and protects linked flow proof from generic
retention deletion. Claim/evidence/receipt HTTP wiring through OIDC authorization
resume is not yet implemented; this schema association does not authorize login.
The public `bind_oidc_flow!` operation now validates a full saved value and locks
the owning Client, pending app transaction, existing flow and admitted ceremony.
It rejects unknown values, mismatched admission, a different Client and reached
deadlines. It commits/reuses one server-issued primary flow before an independent
claim, bounded by transaction/challenge/ceremony and normal sign-in deadlines.
It creates neither a claim nor authentication evidence/session. The separate
`call_for_oidc!` operation now binds an irreversible source claim to the same
persisted transaction/flow/ceremony under locks; its domain model independently
re-reads the pending transaction relation and deadlines. It rejects re-use and
already-authenticated transactions without changing their existing evidence.
Auth Secret POST now calls this OIDC claim path, reuses its bound flow and records
flow/ceremony evidence together under the owning Client and Ticket locks. The
existing Auth checkpoint/handoff registers the protocol method `passcode` while
the internal method remains `secret`; Auth issues no token. Base forwards only
transactions with the dedicated flow reference and expected protocol method to
the Secret-aware canonical issuance boundary. Completed Base issuance/receipt,
session-limit continuation and terminal reconciliation remain unfinished and are
not advertised as successful end-to-end OIDC Secret login.

Chromium component coverage executes the shipped `secret_presentation` entrypoint
and checks removal on pagehide, persisted pageshow and accepted native submit.
An initial pageshow and native validation failure preserve the current display.
The tested entrypoint leaves synthetic values absent from history state, URL,
localStorage and sessionStorage. These component checks use dispatched lifecycle
events; they do not establish actual authenticated navigation/back restoration,
Rails response caching, service-worker interception or analytics confidentiality.

Before audit delivery, provision the shared security retention policy explicitly:
`CHRONICLE_SECURITY_RETENTION_DAYS=<approved-days> bin/rails app_secret:provision_audit_policy`.
The task requires a positive integer, preserves a matching existing policy and
rejects a different duration or permanence instead of changing audit history.
The deployed duration requires a separate operational decision. This task is
operator preparation; requests and delivery jobs never create missing policies.

Zenith source outbox records typed event and actor facts with no raw Secret,
digest or user-provided name. Ticket's success-receipt model validates a completed
normal Secret flow and matching root session. Canonical Base login writes the
receipt in its Ticket session transaction, as verified by the HTTP journeys.
Source outbox persistence is not Chronicle delivery.

## Target journeys still requiring completion

Base app owns `/secrets` management. List and nonsecret detail require normal
authentication and ownership. Manual addition, presentation, confirmation,
rename and deletion require current operation-specific Step-Up. No signed-in
bootstrap exemption applies. Deletion immediately revokes and discards; jobs
perform the subsequent audited physical recovery. Reenable, secret editing,
plaintext redisplay and generic rotation are not offered.

Signup and signed-in settings share the 2/1/0 count policy. Both registration
paths are connected and have HTTP tests covering A=0..20. The displayed
collection is fixed before presentation, and confirmation
activates all candidates or none. Signup cannot finalize before required storage
declaration or normal omission. A saved Passkey is not automatically removed
when its associated delivery is interrupted.

Plaintext presentation uses an explicit protected request, no-store response and
an approved encrypted server-payload format. Browser history, restored pages,
Service Worker caches, analytics and error collection need real-browser evidence.
Never silently regenerate a missing payload. Reissue invalidates the previous
unconfirmed attempt; confirmed plaintext cannot be recovered.

Auth app exposes GET `/sign/in/secret/new` and POST `/sign/in/secret`; GET
`/sign/in/secret` has no compatibility alias. The method selector preserves the
other five methods and links with a generated regional `_url` helper. Local Base
and OIDC admission journeys are connected and HTTP-tested with CSRF enabled.
Full verification must lead to irreversible Zenith claim and then canonical
Base login. After claim, cancellation, Ticket failure and response loss never
restore usability. The same durable operation may reconcile its existing result;
a new flow cannot reuse the submitted Secret.

Chronicle delivery needs immutable-ID deduplication, retries and periodic source
outbox scanning. Purge must wait for prior terminal delivery and atomically write
its own source event with deletion. Incomplete issuance payloads, reservations
and flow proofs require cleanup compatible with their remaining acceptance
windows. ClientSecretAuditDeliveryJob and ClientSecretLifecycleJob now implement source scanning, receipt reconciliation and delegated credential purge. Real-job tests verify revocation audit before physical DELETE, preservation and later delivery of the purged outbox, retry deduplication, and a real source-DB acknowledgment failure after Chronicle persistence. Complete proof/outbox cleanup and the remaining crash boundaries still require implementation verification.

## Assurance and verification

The [NIST classification and conformance limits](../../adr/app-secret-phase1-rebuild.md#standards-and-limits)
are separate from application authorization. A normal Secret-derived session
may perform a later allowed Passkey/TOTP Step-Up; Secret itself is excluded.
Storage declaration is a user assertion, not proof of authentication or actual
safe storage. Losing every other Step-Up method may prevent credential changes.

Current evidence files cover persistence, count/query, indexed lookup, ownership,
name mutation, Step-Up admission, cancellation, expiry retirement and source audit
boundaries. Separate writer connections cover manual allocation, cancellation
versus reservation, and expiry cleanup versus reservation. The 2026-10-05 continuation also verifies manual HTTP delivery through canonical Base login and receipt consumption, rejects a second-flow reuse, and checks completion replay without another root Token. Signed-in Passkey registration uses real WebAuthn verification and HTTP delivery at every active count from zero through twenty; nineteen/twenty notices and zero-generation omission are asserted. Signup delivery, confirmation/claim races, complete proof/outbox cleanup and browser secrecy remain outstanding. Tested revocation purge and source acknowledgment failure are documented in the continuation evidence. Completion requires
those public journeys and app/com/org regressions without weakened gates.

## Shared recovery framework separation

RecoveryPasscodeTopUp explicitly refuses ClientSecretCredential before producing
a result; the app-specific count, ownership, legacy-kind association and recovery
identity preload branches have been removed. SignRecoveryPasscodeRequirement no
longer accepts app Secret. This is removal of the old Recovery contract, not an
implementation of the new app issuance coordinator. No app minimum-two guard is
introduced. com retains its existing ten-item target, counts, persisted credentials
and empty repeat result; org without a Recovery kind retains its empty result.
The replacement public-operation tests use real com persistence and verify these
contracts instead of app legacy kinds/statuses or copied test helper code.

### Signup activation binding

Telephone signup keeps the Passkey requirement pending until the fixed Secret set
is explicitly presented and declared saved, or delivery is normally omitted at
capacity. Confirmed signup candidates remain authentication-ineligible until the
durable signup flow completes. `ClientSecretPasskeyReservationIssuer.complete_sign_up!`
then records `signup_completed_at` and `secret.signup_completed` in the source
transaction. The lifecycle job reconciles completion after a lost response.
Authentication reads the permanent source fact, so later removal of the completed
short-lived signup flow does not disable unused saved credentials.

The HTTP signup journey now exercises birthdate finalization through Auth evidence
handoff. Evidence permits continuation to Base; it is not reported as an already
issued session. Signup count matrices, cancellation cleanup and browser history
checks remain separate acceptance work.

Signup cancellation, expiry and failure retire the batch after verifying the
terminal ticket under the same flow exclusion boundary. Both unconfirmed and
confirmed-but-not-activated candidates remain authentication-ineligible, their
plaintext payload is erased and their source terminal audits record the reason.
Reservations exclude discarded issuances immediately, independently of queue
execution. The recurring retention entry runs Secret lifecycle reconciliation
before generic ticket deletion. Unconfirmed expired candidates require delivered
terminal Chronicle evidence before the sole Secret purger deletes them.

Generic app flow deletion locks each Ticket batch and retains sign-in flows
referenced by any remaining source claim or Auth ceremony, and signup flows
referenced by any remaining Secret issuance. This protection applies beyond the
lifecycle reconciliation batch, including unknown outcomes. It currently retains
terminal references conservatively until their dependent records are collected;
the bounded proof collector is still unfinished. Unreferenced due flows continue
to be deleted, and com/org flow deletion retains its existing contract.

HTTP coverage includes registration completion, cancellation after saving and
expiry after saving. Other interruption points and recovery attempts remain open.

Signup activation also requires the locked source Client to be registered
(`VERIFIED_WITH_SIGN_UP` or `ACTIVE`) and currently allowed to log in. Ticket
completion alone cannot activate a saved batch while the Client remains
`UNVERIFIED_WITH_SIGN_UP` after a cross-DB interruption. Refusal writes neither
the activation fact nor its success audit; a later valid source registration
permits the same saved batch to complete once without replacement values.

### Claim failures and session-limit continuation

A source claim survives rollback of its outer Ticket transaction. When Ticket has
confirmed a failed flow and the original persisted browser ceremony still matches,
reconciliation may restore the flow's missing Client binding solely for terminal
retirement. It does not recreate authentication evidence or issue a token. Missing
proof and completed flows without matching receipts remain unknown and claimed.
Terminal audits distinguish `flow_failed`, `flow_expired` and `flow_canceled`.

Expired app sign-in flows use `expire_sign_in!`, a terminal-only mutation under
the canonical Ticket flow lock. It checks the writer DB deadline and refuses a
live flow or any flow with an issued token/session, including completed logins.
The ordinary unexpired transition guard is unchanged for all surfaces. Delayed
HTTP completion with expired result binding returns the existing invalid-request
response, creates no root token/receipt and cannot restore the claimed value.
Reconciliation retains the expiry reason even if Ticket terminalization committed
before a later source retirement attempt.

Session-limit waiting preserves the claim. Revoking one session may still leave
all normal slots occupied; the existing limitation page then returns 422 with its
inline capacity notice and offers the remaining sessions. Sufficient revocation
resumes the same flow through canonical issuance. Explicit cancellation locks and
fails that flow, cancels its Secret ceremony and retires the source claim. A late
callback with the pre-cancellation browser locator cannot mint a token or receipt;
the existing authorization failure handler redirects it to the public Base root.

Separate PostgreSQL connection barriers exercise concurrent Secret POSTs and
concurrent duplicate Base completion callbacks. Current HTTP evidence establishes
one new root token and one matching receipt, with cookies only on Base. These tests
also verify that normal Secret consumption leaves the new token usable.

The OIDC Secret happy path is now connected through Auth evidence delivery, Base canonical root issuance, a same-Ticket-transaction receipt, and post-commit source retirement. The current HTTP integration test verifies these persisted facts. OIDC cancellation, expiration, session-limit continuation and concurrent result retries are not yet verified; earlier descriptions of missing Base issuance are superseded for this happy path only.

The expired OIDC claim integration example now executes the lifecycle and audit delivery jobs. It verifies terminal Chronicle persistence before credential deletion, preservation of the purged outbox after deletion, and duplicate-safe delivery. Collection of the remaining flow, claim/receipt and issuance proof records is still incomplete.

The existing OIDC transaction purge operation now protects app transactions still
referenced by a Source Secret claim, a Ticket Secret receipt or a session-limit
resolution. It locks app candidate transactions before checking dependencies;
expired transactions cannot acquire a new accepted claim while this lock is held.
This prevents deletion of the evidence needed to reconcile an irreversible claim.
The com/org purge branches retain their existing expiry-based behavior. Bounded
collection of the app dependency records themselves remains unfinished. The expired
claim HTTP example also verifies that the authorization transaction becomes
collectible after terminal reconciliation and credential deletion when no other
dependency remains. Conversely, the successful OIDC HTTP example executes the
real lifecycle job, deletes the consumed credential, and confirms that its
surviving Ticket receipt still protects the authorization transaction and leaves
the established root session active. These are dependency-order checks, not a
completed receipt or issuance collector.

Retired unconfirmed issuance collection is now connected to the lifecycle job.

The explicit `ClientSecretIssuancePurger.call_confirmed!` entry also guards
confirmed positive allocations against collection while credentials or login
receipts remain. It requires the original authority deadline and allocation
expiry plus explicit proof retention, completed signup when applicable, and
delivered matching storage/creation audit and durable credential-purge events.
The lifecycle job invokes this entry after receipt reconciliation. A real manual
reservation, protected presentation, storage confirmation, management revocation,
Chronicle delivery and credential DELETE now precede successful allocation
collection in the public-operation/job regression. Signup and Passkey-specific
collection paths, all timing boundaries and concurrency remain unverified.
The protected replay barrier remains retained.
The Source Client and allocation locks cover the retirement deadline, absence of
credential dependencies and retention/enforcement holds. Terminal source events
must be acknowledged and present in Chronicle before deletion. Allocation DELETE
and `secret.issuance_purged` outbox persistence share the Source transaction; the
outbox survives and is delivered on a later scan. Complete flow-proof collection
remains unfinished; omitted collection and receipt
collection have separate guarded paths described below.
The allocation collection tests additionally verify refusal before Chronicle
delivery, legal-hold refusal, rollback of both DELETE and its outbox, and a
successful retry after rollback. Confirmed and omitted facts are explicitly
preserved by this unconfirmed-allocation entry, even if their retention timestamps are finite.
Reservation callers also refuse an operation with a surviving
`secret.issuance_purged` event. Physical collection must not turn a retransmission
into a new allocation. These source events remain replay barriers; future outbox
collection must preserve them while an operation can still be accepted. The manual
reservation regression performs real expiry, audit delivery and physical
collection before attempting the same operation again. The Passkey reservation
regression now performs the same sequence for both signup and signed-in operations
while their independent authorization remains current. Full browser retry
behavior and bounded replay-barrier collection remain outstanding.

The real Rails manual-delivery browser journey is now verified in
`e2e/app-secret-delivery.spec.ts`: native protected POST presentation and saved-value
confirmation, no plaintext in history state, local/session storage, URL, cookies
or Cache Storage, and no restoration after back navigation. Chromium may refuse
the no-store POST document with `ERR_CACHE_MISS`; the resulting document contains
no delivered value. This journey starts from a properly signed established-session
fixture with scoped Step-Up facts, so it does not prove root issuance or a fresh
Step-Up ceremony in the browser. Active Service Worker interference, forced
persisted BFCache restoration, multiple tabs/reload, response loss and logging or
analytics capture remain unverified. See the browser runtime evidence for the
exact command and artifact protections.

The periodic retention entrypoint now schedules the Secret lifecycle scan when
only source outbox rows remain. It must not depend on a surviving credential or
issuance row: the final DELETE may have left its purged event pending. The
outbox-only recovery test executes the real periodic job on an empty Secret fleet,
verifies Chronicle delivery and verifies duplicate-safe repeat execution.

Omitted allocation collection is separately connected through
`ClientSecretIssuancePurger.call_omitted!`. It uses the explicit proof-retention
setting after the latest allocation/completion fact and bound Ticket deadline.
An existing session uses its actual `discard_at` contract; positive Infinity
retains the allocation until that session retires. Signup uses the existing flow
expiry and requires its durable completion and matching source completion audit.
Source Client, Ticket authority and allocation locks protect these checks.
Missing or malformed expiry on an existing authority fails explicitly. A missing
session/flow has no accepted continuation; its source completion facts and durable
audit still gate collection. Uncompleted signup allocations remain retained.
Matching omission audit must be delivered and present in Chronicle; legal and
enforcement holds still apply. DELETE and the count-zero issuance_purged outbox
commit in one Source transaction. Public runtime observations verify deadline
refusal, missing-audit refusal, atomic rollback/retry, periodic-job connection and
retention through an actual bound session deadline.
Additional runtime fixtures verify the explicit positive-Infinity session sentinel,
actual token revocation, legal-hold refusal/release and rejection of a completed
signup audit without its required omission audit. These do not establish an
actual completed-signup collection journey. These use isolated fixtures,
not a new browser signup journey. Confirmed manual-batch collection has a public
operation and lifecycle test. Full signup/hold/race coverage and eventual
live-owner replay-barrier retirement remain unfinished.

Delivered source outbox collection is now connected to the bounded lifecycle scan.
It requires the configured retention deadline, Chronicle commit, no legal or
enforcement hold and no credential, issuance or Ticket receipt dependency.
`secret.issuance_purged` records remain explicit replay barriers while their Client
exists. When the Client is physically absent, the source event can be collected
only after delivery, retention, absence of dependent facts, enforcement guards
and durable Chronicle verification. The normal issuers require the owning Client
lock, so an absent owner cannot authorize replay. Live-owner barrier retirement
still requires implementation. Barriers now participate in the bounded cursor scan;
the cursor advances past retained barriers, so they cannot
occupy every scan slot and prevent later eligible events from being collected.
`ClientSecretAuditOutboxPurgeJob` processes a bounded ID-ordered batch and queues
the next cursor even when a preceding row remains held or dependent. Each scan
captures an upper ID bound; new events belong to a later periodic scan. The
periodic lifecycle job starts a fresh scan, so a lost enqueue is recoverable.
Every continuation rechecks the purge suspension flag and the purger's current
holds, dependencies and Chronicle evidence. Cursor progression grants no deletion
authority. Public runtime jobs have verified dependent-row continuation with an
inline job adapter and an actual Solid Queue worker on the guarded disposable fleet.
The latter verifies durable enqueue while the worker is stopped and collection
after it starts, with zero failed jobs. A separate queue connection-failure
observation verifies visible enqueue failure, preservation of unprocessed Source
events and recovery through a fresh periodic scan followed by the actual worker.
Interruption during a claimed execution and Minitest coverage remain pending.
Physical credential and source outbox collection compare the durable Chronicle
event with the complete immutable Source fact: UUID, action, operation, time,
result, reason, actor, Client subject, allowlisted metadata and empty changeset.
A matching UUID and success result alone do not authorize deletion. Conflicting
target metadata keeps the Source record and credential intact; public purger
tests verify refusal followed by successful collection after restoring the
matching durable record. This strengthens existing records without changing
their schema or Chronicle payload.

Independent Chronicle history survives source outbox deletion. The current public
tests verify undelivered/deadline refusal, collection without dependencies and
preservation of credential dependencies and replay barriers. Complete receipt
collection, replay-barrier retirement and the remaining hold/crash/deadline-boundary
tests remain unfinished.

Successful receipt collection is now connected to the lifecycle scan through the
explicit `APP_SECRET_PROOF_RETENTION_SECONDS` setting (2592000 seconds accepted
on 2026-10-05 UTC). It locks Source Client, associated OIDC authorization, completed
Secret flow and receipt in that order. All flow/authorization acceptance deadlines
and matching consumed/purged Chronicle times must precede the retention deadline;
the credential must already be physically absent and holds prevent collection.
Generic app flow purge now retains flows referenced by receipts. The real OIDC
HTTP journey uses the existing coordinator's explicit short TTL arguments in its
isolated test and verifies receipt retention while continuation remains possible,
actual lifecycle deletion after expiry, and preservation of the established root
token. Hold/failure/race/boundary coverage, replay-barrier retirement and other
proof/issuance collectors remain incomplete.

The manual-delivery browser file now verifies the real Rails Service Worker on
the Base test origin. Its active controller covers protected presentation and
confirmation; delivered values are absent from Cache Storage. With the browser
offline, navigation to the allocation locator receives a 200 response from the
Service Worker and contains no plaintext. This supersedes the active-worker gap
for the shipped offline-fallback worker and this manual journey. It does not prove
behavior against arbitrary injected workers, forced persisted BFCache restoration,
simultaneous submissions, response loss or analytics/log capture. Browser session
fixtures are independent for each example.

Committed-response loss is now exercised at the browser network boundary. The
test forwards the real protected POST to the loopback Rails listener with the
original Host and request headers, discards the received response and aborts its
browser delivery. Resuming in a new tab of the same context displays no value.
The real Source DB retains one issuance and one presented but unconfirmed,
authentication-unavailable candidate, with no encrypted payload. This verifies
the absence of automatic confirmation, regeneration or repeat reveal after this
delivery interruption; explicit cancellation/reissue and sign-up interruption
still require additional coverage. Transport exceptions are sanitized before
Playwright reports them because its diagnostic call logs can include test cookies.

The response-loss journey also performs explicit cancellation through the native
allocation form, starts a new manual operation and confirms its newly presented
candidate. Actual Source reads verify two allocations, the original canceled and
authentication-unavailable, the replacement confirmed, exactly one active Secret
and the original single root session. This is an explicit replacement operation,
not a fallback that saves an unseen value. Signup interruption and equivalent
browser sign-in was unverified at that checkpoint. The later HTTPS browser
journey below covers normal Secret root login and reuse refusal.

The browser delivery file additionally verifies unconfirmed reload and a second
tab in the same browser context. The sibling GET contains no value; reloading the
original POST redirects to the nonsecret allocation page. A real Source DB read
then confirms exactly one candidate, no storage confirmation, the immutable
presentation fact and no encrypted payload. This supersedes the multiple-tab and
reload gap for this manual-delivery sequence only. Simultaneous tab submission,
active Service Worker interference, forced persisted BFCache restoration, response
loss and log/analytics capture remain unverified.

OIDC session-limit continuation is connected to the bound Secret flow. Both active and total session capacity are checked; remaining capacity refusal renders the existing inline notice while preserving the irreversible claim. The HTTP regression verifies successive session selections followed by canonical issuance, receipt and consumption. Cancellation and concurrent resolution/callback exclusion remain unverified.

OIDC session-limit cancellation is connected through the limitation DELETE endpoint. It terminates the pending flow and resolution under issuance locks, retires the claim with verified cancellation audit, and rejects the prior result on replay. Concurrent OIDC cancellation versus issuance remains to be tested.

Secret OIDC limitation PATCH revalidates its authority immediately before selecting
and revoking an existing session. Client, authorization, resolution and flow locks
are held through that mutation, with the same order used by cancellation. A stale
resolution object cannot authorize mutation after its flow expires or cancellation
commits. Canonical issuance still revalidates the flow separately after this step.
Sequential stale-object tests pass. Separate PostgreSQL connection barriers now
also verify that a selection blocked on the Client lock cannot invoke its mutation
after cancellation or expiration wins. This is a public model-operation test with
persisted pending-flow setup; concurrent complete HTTP cancellation and root
issuance callbacks still require verification.

The local HTTP journey now follows actual Secret Sign in through an independent,
signature-verified Passkey Step-Up and subsequent manual Secret delivery,
confirmation, rename and revocation in the same Base browser session. Before that
Step-Up, direct create, rename and revoke requests return 401 without issuance or
audit changes. The initial issuance in this example uses a scoped freshness
fixture; the subsequent Secret-established root acquires freshness through Auth
verification and Base completion. This evidence covers Rails HTTP and persisted
state, not a browser engine's history or storage behavior. Real-browser residual
plaintext acceptance checks remain unfinished.

The HTTPS Chromium journey in `e2e/app-secret-sign-in-entry.spec.ts` now reaches
six distinct rendered authentication controls and the Secret form in both US and
JP regions using server-issued Base admission. Another case uses browser manual
issuance, protected presentation and explicit storage confirmation, then a guest
flow through Auth evidence and native result handoff to canonical Base root login.
The persisted receipt matches exactly one normal Secret root token and the
consumed claim; another guest flow rejects the same saved value with HTTP 422.
The existing 30-second cooldown remains enabled and is awaited before guest entry.
Only the initial management session and Step-Up are fixture state; fresh browser
Step-Up and signup are not proven by this case. External Jump and Turnstile are
test adapter substitutes behind a loopback HTTPS proxy. See
`evidence/2026-10-05-app-secret-browser-admission-9D3F.md` for commands and limits.
