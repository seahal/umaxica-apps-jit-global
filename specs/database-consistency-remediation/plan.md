# Implementation plan and adversarial review

## Execution order

1. Capture baseline and read-only development/test catalog inventories; map every finding to model,
   connection, table and affected column/index/association. Preserve full output locally under
   `tmp/database-consistency-20261019/`; retain digest and summary in evidence, never raw logs
   there.
2. Investigate PublicId capacity using identifier ADR, consumers, actual schema and aggregates.
   Generation remains 21; accepted storage capacity remains 25. Hold any unsafe migration or
   unsupported compatibility expansion. A shared validation change is not justified by checker
   count.
3. Fix three missing-column inverse associations on ClientTokenKind, OperatorTokenKind and
   OperatorTokenStatus. Existing child belongs_to and PostgreSQL FKs use user_token_kind_id,
   staff_token_kind_id and staff_token_status_id. Add regression reads and restriction tests before
   edits. Preserve association names, database owners and restrict_with_error policy.
4. Group simple length/null findings by shared implementation and semantic classification. Test
   missing/empty/false and neighboring boundaries before adding meaningful model validation.
5. Map FK/index findings to query direction and database identity. Cross-database links need no
   impossible FK. Preflight orphans and preserve established lifecycle/audit retention boundaries.
6. Resolve numericality and three-state booleans using domain contracts and direct database tests.
7. Inspect every unique-index predicate, expression, scope, NULL semantics and collision handler.
   Add preflight validation only where it matches the existing public contract and query budget.
   Hold genuine conflicts with checker requirements for user decision.
8. Examine redundant indexes including order, predicate, INCLUDE, opclasses and constraint
   ownership; evaluate affected queries before generating any removal migration. Removal execution
   needs the applicable risk/recovery approval.
9. Review dependent/cascade findings with withdrawal, Accounting, Chronicle, retention and Avatar
   contracts. Prefer an evidenced retention/restriction policy; never infer CASCADE from a warning.
10. Repeat full checker and broaden relevant tests at each boundary; perform final acceptance audit.

## Adversarial review before implementation

| Attack on the plan                                           | Evidence or required defense                                                                                                          | Disposition                      |
| ------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------- |
| Reduce 25 to 21 to remove 216 warnings                       | identifier-contract ADR explicitly separates capacity and issuance; current tests exercise capacity 25                                | rejected                         |
| Add uniqueness everywhere                                    | UniqueIndexChecker requires validators regardless of application exception contract; inspect each handler/predicate and SELECT impact | held per finding                 |
| Add dependent destroy everywhere                             | checker accepts restrict options too; existing FK RESTRICT and audit retention must remain                                            | rejected                         |
| Treat false as missing                                       | presence rejects false; nullable booleans require semantic review and sentinel tests                                                  | required per slice               |
| Add FK across databases                                      | inspect actual connection and database identities, not model naming                                                                   | required per slice               |
| Apply constraints assuming empty production                  | local counts establish only local data; production preflight and lock/recovery plan remain necessary                                  | migration gate                   |
| Interpret 3 ForeignKeyType findings as integer-width defects | actual reports identify missing convention-derived columns; existing child FK names differ                                            | inverse association fix selected |
| Trust test exit alone                                        | initial test setup stopped on stale prepare names; inspect actual run/assertion/error/skip counts                                     | required                         |
| Rewrite unrelated work                                       | DESIGN.md and preexisting diagnostic/evidence files recorded before edits                                                             | preserved                        |
| Count provisional clusters as proven causes                  | ledger labels unresolved cause families as hypotheses; verify individually before closure                                             | required                         |

No external reference repositories are needed for the first association slice; local code and
catalogs are authoritative. No subagent or separate verifier pass is used.

## Baseline aggregation correction

Inspecting SimpleWriter established that its unique_key grouping hides model/connection
multiplicity. The 2,119 CLI failure lines represent 2,177 raw failures: MissingIndex 60 rather than
14, MissingDependentDestroy 233 rather than 222, and ForeignKey 27 rather than 26. Preserve both
metrics and expand every raw report into the ledger. Raw reports also include one warning excluded
from default CLI output. No config/log-level workaround is used for remediation.

The gem's ReportBuilder#to_h currently uses attribute values as hash keys, so a diagnostic export
must read report fields explicitly; that serialization defect is not an application finding and is
not repaired in this application scope. The local read-only diagnostic exports fields without
changing checker configuration or execution.

## Next safe behavior slice: revision sequence

The twelve revision tables already require positive PostgreSQL integer sequence values via NOT NULL,
`CHECK(sequence > 0)` and the native 32-bit integer range. The create/revise/restore writers supply
1 or max(sequence)+1, never a request-provided sequence. Model validation currently permits missing
and overflowing values. Add one bounded integer numericality declaration to the existing revision
Concern, preserving integer-string assignment and database enforcement. No schema change or SELECT
is needed. Test all twelve concrete families at 0/1/2 and max-1/max/max+1, plus NULL, empty, false,
negative, fractional and malformed inputs; use actual SQL for independent DB rejection. Existing
promotion/snapshot/immutability/taxonomy tests must remain green. A missing localized attribute
label surfaced during Green and is repaired explicitly in all four canonical locale bundles, not
hidden by an inline translation default.

## Ordered taxonomy position slice

The twelve revision-multiple and twelve version-multiple assignment tables require position NOT
NULL, position >= 0 and native 32-bit integer storage. Align only these ordered models with the
existing numericality pattern used by Publishing media positions; leave unordered assignments and
DB-derived snapshot fields unchanged. Version validation remains creation-only to preserve
ReadOnlyRecord on immutable updates. Characterize zero/string-zero, Rails false-to-zero assignment,
sparse maximum positions, promotion snapshots and immutable updates. Reject missing, negative,
fractional, malformed and overflowing positions; independently exercise raw DB constraints. Preserve
the existing duplicate-term/position RecordNotUnique contract. No new schema, trigger, uniqueness
preflight or general per-column validation mechanism is warranted.

## Concrete-interface validation slice

All four Organization consumers have a name column, but only Enterprise/Company/Bureau have a title;
legacy OperatorOrganization deliberately does not. All three Persona consumers have title and use
separate lifecycle tables. Characterize every host before changing declarations. Move Organization
title rules unchanged to its three explicit concrete owners and make universal name validation
unconditional. Remove only Persona's title capability guard, retaining its unrelated legacy status
guard. This eliminates runtime schema probing from required attributes without introducing a new
validator, scope, callback, SELECT or schema change. Keep legacy duplicate-declaration behavior as
observed through errors. Existing authority/membership and root-unit tests protect graph behavior.

Adversarial checks: do not add title to legacy organizations, remove ownership/identity constraints,
merge surface databases, or change string casting (false/true/zero remain f/t/0). Assert title 0/1/2
and 9/10/11 boundaries, missing/empty/whitespace/format partitions, real persistence and direct DB
NOT NULL rejection. No mechanical Red is needed for this behavior-preserving declaration refactor;
the default checker's nine possible_null findings form the structural reproduction.

The concrete-interface declaration slice above was rejected after C7 projected-record tests:
removing has_attribute? changes previously accepted partial SELECT saves. Keep the original guards
and all nine findings open (D5); do not retry merely because whole-record schema is fixed. The final
preservation slice covers both explicit invalid inputs and omitted, unchanged stored attributes.

## Bounded snapshot-reference length slice

Forty-eight LengthConstraint findings concern the two public-ID snapshot reference columns on all 24
immutable Publishing taxonomy assignment models. These are not PublicId's own generated identity
columns: the existing varchar(21), exact-21 snapshot checks and source vocabulary/term contracts
remain intact. Add maximum-21 creation validation for only those two reference fields after Red. Do
not use exact-length validation: shorter nonblank supplied values are currently accepted and
replaced by the existing authoritative DB trigger. Retain that behavior, including string-cast
false. Do not validate on update: immutable snapshots must retain their existing ReadOnlyRecord
contract even for an attempted overlong replacement. No shared capacity-25 change, schema/data
migration, new hook/trigger, uniqueness validation, callback or extra SELECT is proposed.

Tests cover all 24 includers through explicit single/multiple family matrices: ordinary promotion,
20/21/22 and 25-character boundaries, nil/empty and false normalization, DB rejection independently
of AR, DB-derived overwrite of short values, deferred completeness and immutable updates. Existing
DB constraints are kept. Confirm actual varchar input rejection occurs before the derivation trigger
rather than assuming supplied long snapshots would be harmlessly normalized. Add scoped/established
attribute labels only if needed to expose real error messages in both languages. Review actual
runtime target coverage after the change; do not reorder validators or configure away reports.

## 2026-10-20 resumption and next bounded slice

Refresh all observations against the retained dirty worktree before attributing progress. Reuse the
stable finding identity formula. The current catalog contains the previously drafted FK/index
changes; absence of a report is not evidence that this session applied or approved its migration.
Retain the historical ledger and add a dated current disposition with all old and new identities.
The user reconfirmed preserving duplicate-error and public-ID capacity contracts on 2026-10-20.

Next candidate: content_digest on the twelve revision and twelve version families. The accepted
`adr/publishing-twelve-family-encrypted-persistence.md` specifies canonical plaintext SHA-256;
`PublishingRevisionContentDigest` produces lowercase 64-character hexadecimal strings, ordinary
create/revise operations compute them, and restore/promotion copy a stored digest. Actual
varchar(64), NOT NULL and lowercase-hex CHECKs remain authoritative. No request supplies this field
to those writers. Characterize normal generated digests, independent SQL refusal at 63/64/65,
NULL/empty and wrong-alphabet partitions, and version mutation refusal before implementing creation
validation.

Adversarial review: an unconditional update validator would turn immutable version mutations into
RecordInvalid and interfere with promoted-revision DB guards. Limit this slice to creation,
preserving those existing update contracts. Express the two independent invariants (length 64 and
lowercase hex alphabet) in the existing shared encrypted-content Concern. Do not add redundant
presence solely to satisfy NullConstraintChecker: that checker does not recognize length/format
rejection of nil, so its 24 findings must remain visible. No schema, digest algorithm, encryption,
duplicate preflight, additional SELECT, callback, trigger or lifecycle change is needed. Preserve
missing-digest DB failure for validation-disabled writes. Whole-suite and production migration
acceptance remain separate.

## C11 — explicitly required creation fields

The user delegated validation decisions and requested NOT NULL findings be addressed on 2026-10-20.
Implement only the actual nil invariant for locale on all twelve entry/slug/revision/version
families: SQL permits nonnil empty/whitespace/string-cast false/zero, so presence or locale
whitelisting would silently narrow valid persistence. Exclude nil on creation; retain immutable
version/update refusal and projected existing-record behavior. Publications require effective_from,
with no default or writer callback: add creation-time presence, preserving nullable effective_until
and existing window logic. All 60 columns already have database NOT NULL; this slice needs no
migration or production data assumption. Red tests characterize all families, six nonnil locale
partitions, independent SQL null refusal, and immutable version updates. Reproduce missing model
rejection before implementation. No authentication/withdrawal/retention or database-boundary change
is authorized by this slice.

## C12 — required Avatar catalog booleans

The nine capability/display/terminal flags on AvatarLifecycleState have no DB defaults and are all
NOT NULL. Seed/catalog contracts distinguish false from nil. Add creation-only inclusion in
true/false, never presence, with all nine false/true and raw DB NULL characterizations before Red.
Keep partial existing-record saves, all canonical reference rows, lifecycle transitions,
authorization and audit writers unchanged. The Avatar lifecycle ADR and ownership checklist govern
the boundary; no state axis, value, transition edge or event writer changes, so the state-machine
diagrams remain accurate. The asset is the authoritative catalog; actors and request entry points
are unchanged. An omitted flag must fail before insert, rather than silently selecting an authority
default. Independent SQL must continue rejecting NULL, and existing restricted/terminal-state tests
must stay green.

## C13 — exact family-local vocabulary key uniqueness

The user prioritizes UniqueIndexChecker and delegates ordinary validation design; D1's twelve term
slug exception contracts remain unchanged. First classify all unique reports, including
PK-containing FK-target indexes, partial predicates, NULLs, expressions, callback-derived values and
duplicate-error handlers. Do not infer that every unique index needs an extra validation query.

First candidate: the twelve Vocabulary.key ordinary, nonpartial UNIQUE indexes. The accepted
taxonomy ADR defines family-local uniqueness, independent of locale and archival. No application
vocabulary creation operation or collision-retry/error handler was found; the existing duplicate
test explicitly uses save!(validate: false), requiring DB RecordNotUnique to remain authoritative.
Add normal model preflight for the administrative vocabulary name, after Red, with no
kind/locale/archive scope and no case folding. This deliberately makes ordinary duplicate model
saves invalid; raw/validation-disabled writes retain RecordNotUnique. This is distinct from D1's
explicit normal TaxonomyTerm.create! exception contract. Verify that normal cross-family keys,
unchanged-key saves, archival reservation, immutable-key refusal and label edits, format/nil inputs,
exact duplicate DB refusal and all twelve concrete models behave correctly.

Measure added SELECTs via sql.active_record subscriptions and test unique-key race fallback by
direct DB writes; preserve DB indexes and don't claim preflight prevents concurrent collisions.
Classify PK-containing indexes as DB composite-FK targets, not invitations for redundant id
uniqueness queries. This slice has no migration, production data operation, callback, trigger or
deletion-policy change.

## C14 — explicit resource/principal Grant pairs

The user authorizes implementing every safely resolvable UniqueIndex finding and requires reverting
only newly introduced changes that break existing behavior. Retain D1, create_or_find_by!/replay and
slug/promotion collision handlers unchanged. Start with 21 simple surface-local Grant tables: a
nonpartial unique pair of resource FK and principal FK, both NOT NULL, with only belongs_to
associations and no existing validators/callbacks. Use explicit declarations in each concrete model,
not a generic grant Concern, scope on the principal FK and validate the resource FK. The DB index
and normal race refusal stay. Normal duplicate model writes get RecordInvalid under delegated
validation design; caller/authority regression failures require reverting only that declaration.

Characterize allowed same-resource/different-principal and same-principal/different-resource pairs,
normal unchanged saves and direct DB duplicate refusal. Red must reproduce duplicate model validity;
Green also covers nil/empty/zero FKs, scope-changing collisions, record preservation and actual
owner query refusal to treat a delegated Grant as ownership. Run all six creator/model/policy
boundaries and known replay/lock/slug regressions; no authority, identity, role, lifecycle, deletion
or schema change.

## C15 — one ownership/lifecycle row per resource

The twelve concrete Ownership/Lifecycle resource FK indexes are ordinary, nonnullable, single-column
UNIQUEs. Six creators allocate a fresh resource before these rows. Existing owner and lifecycle
backfills lock the resource and explicitly return an existing row; they do not use exception-driven
create_or_find_by! for these tables. Add explicit resource-FK uniqueness only after characterizing
allowed separate-resource rows, unchanged saves and direct DB duplicate refusal. Verify normal
creator/backfill idempotence, conflict handling and both sides of a resource-key update collision.
No principal scope applies: one row per resource is global within that concrete table. No lifecycle
state value, edge, writer, authority/membership query or ownership transfer behavior changes; no
state-machine diagram update is needed. Revert the added declaration if caller regression appears.

## C16 — partial live RP-cell session uniqueness

Review all twelve concrete cell Session models against the physical `revoked_at IS NULL` unique
op_session_binding_id index and RpCallbackCommitter. The writer serializes under the anchor lock,
returns already_enrolled for a still-live session, and closes expired unrevoked rows before creating
another session. It does not use a duplicate exception to find the same session. Test exact
predicate semantics: an expired but unrevoked row still occupies the slot; any number of revoked
history rows and different anchors remain valid. Candidate eligibility must be revoked_at.nil?,
never active?. Only create-time preflight is proposed: adding a conditional uniqueness query to
every refresh update would add avoidable SELECTs and alter existing update contracts.
Revoke/refresh/tombstone/cookie/OP root boundaries and the anchor's atomic insert_all ownership stay
unchanged. Independent DB writes remain authoritative. Revert the declaration on any existing
authentication/callback regression.

## C17 — one appeal/principal effect per Enforcement Case

The three realms' six Case-FK indexes are plain nonpartial UNIQUE constraints. A Case permits one
appeal and one PrincipalEffect; neither index is the close-before-apply open-effect predicate. The
existing Appeal review/redaction and Case associated-effect validation must remain unchanged. Add
explicit Case-FK uniqueness only after same/different-Case and raw DB duplicate characterization;
normal model duplicates get RecordInvalid, raw writes stay RecordNotUnique. Run appeal reviewer
separation/audit behavior, associated-effect apply ordering/failure and realm model regressions. No
new state value/transition, close-before-apply sequence, access gate or audit writer is changed. The
partial AuthenticationMethod/Identifier effects remain separate: preflight must not reject a draft
that is intentionally allowed to supersede an open effect in the later close-before-apply boundary.

## C18 — active account-assignment pairs

PersonaAssignment/IndividualAssignment/AgentAssignment have active pair indexes on resource and
identity, revoked_at IS NULL. Their shared concern sets timestamps but has no duplicate preflight.
Bootstrap's create_unique explicitly handles both RecordInvalid and RecordNotUnique and performs its
existing lookup; keep that writer untouched. Add create-only, candidate-active, exact pair
uniqueness to the three concrete models. Preserve alternate pairs, revoked history, revoke/reassign,
raw DB duplicate refusal and bootstrap replays across app/com/org. No assignment becomes ownership,
no identity mapping/role/state writer or cross-DB reference changes. Revert on any selector
regression.

## C19 — pending ownership-request slots

Six existing intent tables use one pending request per concrete resource. No creation/recovery route
or transfer protocol is introduced: only the exact status == PENDING candidate and existing-row
predicate is validated, on create. Expiry alone does not free a slot; terminal history is
unrestricted by this index. Characterize cancelled/expired history, different resources, direct DB
duplicates and cancel/recreate before Red; keep party/expiry checks, existing zero-principal
semantics and status writers unchanged. This does not authorize ownership transfers or add lifecycle
edges.

## C21 — active Avatar capability tuples

Two concrete ownership-generation grants have exact partial uniqueness on period, subject public
reference and capability where revoked_at IS NULL. IssueOperation creates under the current-period
and membership locks and does not consume uniqueness exceptions for replay. Add create-only,
candidate-unrevoked tuple validation. Characterize distinct capabilities, revoked history, raw DB
unique refusal and real reissue after revocation; retain issuer membership, closed-period and
wrong-surface refusals in the existing service suite. No ownership-generation/subject mapping, role,
permission, temporal policy or audit writer changes. Match index eligibility, not effective_at?.

## C22 — legacy Member public-reference uniqueness

The Member public_id index is global, not scoped by owner or retention timestamp. This existing
model does not use PublicId issuance; do not add a generator, format/length change, immutability
hook, owner or retention rewrite merely to resolve uniqueness. Add only ordinary public_id
uniqueness, characterizing distinct references, unchanged-ID relabelling, cross-owner raw
UNIQUE/NULL refusal and normal duplicate validation. No Member collision-retry/application creator
was found. This bounded validation does not claim the separate legacy identifier/NULL/association
gaps are resolved.

## C23 — MediaFile storage-key creation preflight

MediaFile.storage_key is globally unique and assigned from Shrine before validation. Add creation-
only uniqueness: post-promotion metadata updates must retain the existing DB exception behavior. The
current sync callback uses update, so applying uniqueness to updates could turn a DB exception into
an ignored false return. Preserve that callback and its DB-authoritative failure path instead of
introducing this regression or unrelated attachment changes. Characterize real upload metadata
resynchronization under deliberately conflicting stored metadata, raw UNIQUE/NULL, distinct keys and
unchanged-key updates before Red. No file, storage namespace, object deletion or identifier contract
changes. One initial model preflight; no extra metadata-promotion UPDATE probe.

## C24 — revision sequence creation preflight

Each of twelve concrete EntryRevision models opts into entry-scoped sequence uniqueness on create.
Keep declarations in concrete models rather than expanding legacy Concern inclusion hooks. Writers
serialize the entry before max-plus-one allocation; sequence collisions are not an idempotency
signal there. EntryVersion and promotion exception handling are excluded from this change. Verify
all families, raw UNIQUE, adjacent/cross-entry sequences, unchanged-key edits, numeric boundaries,
revision creation and promotion/immutability. One additional revision-create SELECT; no update
probe.

## C25 — RP sender key creation preflight

Keep each cell's sender scope explicit: SID and subject include issuer/realm/client_id; receipt JTI
includes issuer/realm/client_id/event_type. Creation-only validation preserves identity
immutability, anchor tombstone updates and receipt updates. Main callback/logout anchor writes
remain atomic insert_all with unique_by, bypassing preflight. Identity creation and receipt creation
each gain one indexed SELECT. Existing endpoint catches ActiveRecordError and retains retryable 503
on persistence failure; duplicate delivery checks and anchor locks remain unchanged. Verify all
twelve cells, raw DB enforcement, sender/event partitions, normal duplicates and real
callback/logout retries. No issuer resolution, identity ownership, session/root issuance or realm
boundary changes.

## C26/C27 — concrete Avatar uniqueness

C26 adds creation-only transfer_reservation_id uniqueness to the four detail models. Existing
ReservationCreator returns existing same-input reservations; only reservation constraint names
participate in its collision retry. Preserve those handlers and all direction-specific fields.

C27 adds creation-only avatar_id uniqueness to Enterprise/Bureau ownership periods, with the exact
valid_to = infinity predicate and candidate guard. Future-start open periods still occupy the key;
finite periods are outside this index (DB temporal constraints remain authoritative). Verify real
transfer close-before-create, all directions and actual two-worker concurrency/commit checks. No
ownership boundary, membership, source immutability, existing trigger or state writer changes.

## C28 — processor-delivery attempt ordinals

Notification creation uses find_or_create_by! and keeps its DB-exception collision retry; leave
those two notification index reports open. Attempt creation instead runs under the notification row
lock, uses retry_count + 1, and returns without creating when a lease remains in flight. Add
create-only attempt_number uniqueness scoped to notification FK and delivery_generation in both
concrete attempt models. Keep the existing retry, lease, receipt, audit, erasure and retention
writers unchanged. Characterize actual begin_attempt!, repeated claims, retries, generation
partitions and raw DB uniqueness; run the existing delivery/concurrency/job suites. One indexed
SELECT per created attempt, none on terminal-state updates. No schema or deletion-policy changes.

## C29 — OP client activation keys

The named activation writer locks the realm epoch row and find_or_initialize_by the exact
client/epoch before updating. It does not use a uniqueness exception for idempotence. Add
create-only client_id uniqueness scoped to contract_epoch in three concrete models. Existing
same-row enable/disable and missing/current/older-epoch admission decisions stay with the current
writer/query. Test exact client/epoch partitions, false updates, raw uniqueness and normal
preflight, then the real writer/admission gate. One added SELECT on initial creation, none on
same-row updates. Do not alter singleton protocol-epoch realm indexes merely to satisfy preflight:
with id restricted to one they encode a DB invariant already implied by the primary key.

## C30 — Secret issuance operation/attempt tuple

Manual and Passkey reservation/reattempt writers hold their existing actor/session/flow locks and
return the matching prior operation before creating a successor. They do not consume tuple
RecordNotUnique as a retry signal. Add only create-time attempt_number uniqueness scoped globally to
origin_operation_id (not client_id); keep immutable persisted facts and raw DB exceptions. Retain
the existing validate:false public-ID retry test: a collision on this tuple must not regenerate a
public ID. Verify operation/attempt partitions, cross-owner refusal, omission state, all named
reservation writers, capacity concurrency and cancellation/invalidation. Do not modify secret count,
expiry, confirmation, presentation, authorization or audit writers. One new indexed SELECT on
creation and no preflight on persisted transitions.

## C31 — OP inbound event receipt scope

Match the full event_id/issuer/realm/client_id index in all three concrete models with create-time
preflight; unlike RP event receipts, event_type is not part of this key. Existing invalidation
checks duplicate event IDs and returns before creation on redelivery; delivery catches all
ActiveRecordError persistence failures and enqueues durable retry. Preserve this behavior, event
epoch/root cutoff, receipt recording order and multi-DB boundary. Test sender/client/event
partitions, event-type exclusion, raw DB uniqueness, actual redelivery and durable retry/sweep. One
indexed SELECT on insertion, none on persisted updates or already-recorded delivery checks.

## C32 — exact session-limit resolution partial keys

Add concrete create-time sign_in_flow_id uniqueness only for state_id in OPEN_STATES and actor_ref
uniqueness only for waiting_slot=1. Each existing-row predicate and candidate guard independently
matches its index; active_at expiry is deliberately not substituted. Preserve the named issue!
locks, prior-flow replay, WaitingSlotOccupied refusal, cancellation/expiry releases and terminal
history. Two added indexed probes on open-child creation, none on persisted transitions/replay.
Verify all three realms, raw uniqueness, individual key collisions, elapsed-but-open rows, terminal
candidate eligibility, real issue/cancel/reissue and root promotion/refusal/browser/cookie/audit
boundaries. No state edges, root issuance or transition writers change.

The Mermaid README summary still says code pending while the concrete resolution diagrams and lower
detailed transition inventory confirm the implemented waiting-slot policy. Current code and
all-surface tests implement it. Treat that summary as a pre-existing documentation discrepancy; this
slice preserves the current policy and graph rather than choosing a new state contract.

## C33 — Step-up session transaction references

The three Step-up session transaction refs are nullable, ordinary globally unique FKs. The Base
issuer may reuse a persisted session and assign a fresh transaction reference, so creation-only
validation would leave the real update path unprotected. Add uniqueness with allow_nil (not
allow_blank), covering changed values and relying on AR's unique-index optimization for unchanged
persisted values. Keep generated Passkey challenge refs DB-authoritative: their update path retries
a named RecordNotUnique constraint and must not receive a validator. Characterize real FK parents,
multiple nil values, raw unique updates, normal duplicate creation, existing-row changes, distinct
replacement and clearing nil; run all realms, Base issuer, Passkey collision retry and revocation.
Do not alter transaction creation, named writers, root/session issuance, purpose or lifecycle.

## C34 — one root token per sign-in flow attachment

All three sign-in flow token_id indexes are partial only for nonnil values. The real root issuance
and sequence gate attach tokens to existing flows with update!, then persist later flow transitions.
Creation-only validation would miss those writes; unconditional validation would add probes on
unrelated transitions because Rails' unique-index optimization does not recognize partial indexes.
Use uniqueness with allow_nil and a will_save_change_to_token_id? guard, covering each new or
changed nonnil assignment while preserving unchanged rows. Check all realms, raw uniqueness,
multiple nil parents, creation/update collisions, distinct attachment and query budget, then root
establishment, capacity/cooldown, session-limit promotion and cookie/audit refusal boundaries. No
root creation, completion, state edge, token identity or named writer change.
