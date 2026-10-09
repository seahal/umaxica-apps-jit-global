# Avatar organization ownership acceptance

Authority: approved A00–A16 and D-1–D-11 strategic decisions. The existing
[ownership spec](../../specs/avatar-organization-ownership/spec.md) retains historical findings and
rejected options; its Binding-only Grants, residual idempotency gap and shared-DB cleanup proposals
are superseded by those approvals, not acceptance alternatives. The criteria below preserve the
approved decisions for an investigator without the chat. The
[trigger ADR](../../adr/database-trigger-usage-boundary.md) applies with only the narrow
D-3/D-4/D-10 exceptions; no new SQL/trigger permission is granted here. Follow the
[investigation procedure](integrated-stack.md#independent-investigation).

## AV-1 — Concrete organization authority and identities

- Basis: A01/A05, D-1. Scope: app Enterprise and org Bureau; com remains free of Avatar
  dependencies.
- Given an Avatar and each of the four supported source/destination families, provision and transfer
  it through supported interfaces. It always has one organization owner, never an individual or
  fractional owner; Avatar/Persona/ClientPersona/Agent/Enterprise/Bureau identities remain the same.
- Owner persistence has concrete target families: no polymorphic association/STI/type+ID/exclusive
  arc. Shared Ruby interfaces do not become generic persistence. Cross-DB organization/subject
  references retain public identity; local period/Avatar FKs retain concrete DB integrity (ID-3).
- Check schema/associations/resolvers, app initial and org optional provisioning, existing
  [transfer operation tests](../../test/operations/avatar_ownership_transfers_test.rb) and app/org
  controller tests. New concrete-model/provisioning coverage is planned; legacy test names are not
  proof.

## AV-2 — Uninterrupted immutable temporal chain

- Basis: A05, D-3/D-4. Given a new Avatar, creation and its first owner period commit together with
  a creation-consistent boundary. Across Enterprise and Bureau periods, finite immutable start and
  immutable Avatar/owner, strictly later end, `[from,to)` adjacency and final positive infinity
  yield exactly one owner at every valid point, with no gap/overlap.
- Attempt missing owner, equal/reversed/nonfinite start, cross-family overlap/gap, duplicate current
  periods and closed-history update/delete/truncate through SQL: DB rejects invalid commit
  explicitly, leaving prior history unchanged. Do not invent historical timestamps or rely only on
  model validation, partial current uniqueness or per-table exclusions.
- Check actual constraints/deferred triggers and real COMMIT in a new disposable catalog (MIG-3).
  [Existing period tests](../../test/models/avatar_ownership_period_test.rb) are a starting point;
  full concrete cross-table COMMIT coverage is planned, not established by transactional fixtures.

## AV-3 — Concurrency and trigger boundary

- Basis: A04/A13/A15, D-3/D-4/D-11. Given independent connections racing owner changes at READ
  COMMITTED, REPEATABLE READ and SERIALIZABLE as applicable, deterministic success/refusal/retry
  preserves AV-2; stale snapshots never authorize a second current owner. Deadlock/serialization
  failures corrupt no history.
- Each necessary trigger's function and attachment exist together, with documented invariant/events/
  lock mode/order/SQLSTATE and reverse cleanup order. A required integrity counter may change only
  for concurrency, not become owner authority. No audit/notification/business side effects, silent
  correction, recursion/lock-upgrade bug or trigger disabling. Existing trigger inventory includes
  actual objects.
- Check isolated real transactions, direct SQL firing and dump/rebuild. Start at
  [concurrency tests](../../test/operations/avatar_ownership_transfers_concurrency_test.rb) and
  [trigger tests](../../test/models/enforcement_triggers_test.rb); new concrete/MVCC coverage is
  planned. Approximately twenty draft triggers is not a required count. Block runtime acceptance
  without isolation.

## AV-4 — Global registry and concrete transfer cardinality

- Basis: A08, D-7. Given concurrent requests across any of four concrete transfer families, one
  shared type-neutral registry reserves operation public identity/idempotency key and enforces one
  pending operation per Avatar. Every committed registry has exactly its required concrete detail;
  every detail belongs to one registry. Direct SQL or simultaneous inserts cannot create
  orphan/multiple details.
- Source/destination/actor facts stay in concrete detail models. No transfer_type+transfer_id,
  owner_type+owner_id or exclusive arc in the registry. A later lookup that discovers duplicate keys
  is not acceptable eventual consistency; no residual cross-table uniqueness gap.
- Check registry/detail FKs/uniqueness/deferred checks and simultaneous cross-family transactions.
  Comprehensive registry schema/tests are planned; use the existing operation/concurrency tests only
  as legacy behavior references, not substitutes for these new cases.

## AV-5 — Stable-key API and recorded-result retry

- Basis: A09/A10, D-8. Given an authorized initiator with canonical lowercase 36-character RFC UUID
  v4/v7 key and immutable Avatar/kind/input tuple, repeated creation returns the same operation
  identity or recorded result. Change inputs or initiator with that key: refuse without disclosing
  another actor's result. Unsupported version, malformed/noncanonical keys fail the stated API
  boundary.
- Existing keyless callers remain on the explicit additive transition without a promised full retry
  guarantee; per-request random server keys are not client idempotency. Registry public IDs remain
  NanoID. Cancelled/expired operations never revive. Permission to read an original result does not
  authorize executing a new transfer.
- Check public transport and all four concurrent families, original caller inventory/exit
  conditions, key format partitions/length boundaries and authorized/unauthorized replay. Start at
  [app controller tests](../../test/controllers/base/app/avatar_ownership_transfers_controller_test.rb)
  and
  [org controller tests](../../test/controllers/base/org/avatar_ownership_transfers_controller_test.rb).
  UUID/registry transition coverage is planned where absent.

## AV-6 — Transfer acceptance is one local transition

- Basis: A10/A15. Given a pending request within the preserved five-day lifetime, accept after
  locks: revalidate original operation, source generation, source authority and destination
  acceptance authority, then use one DB-derived instant to close/open periods, record result,
  complete transfer and apply Grant/Group consequences in one Avatar DB commit. All four directions
  work.
- Lost-response retry finds the same success; stale generation, revoked authority, cancel, expiry
  (before/at/after) or non-increasing clock leaves history unchanged. Lock order is consistent
  across Group/Avatar writers and acquired facts are revalidated; no claimed Zenith/Avatar
  atomicity.
- Check actual operation/controller and concurrency tests with failures between writes, lock waits
  and recorded-result retry. Full concrete implementation evidence is planned; current model
  validation or a successful sequential transfer alone cannot establish the contract.

## AV-7 — N:M Grants remain generation-bound

- Basis: A06, D-5. Given one Identity with multiple Personas, multiple Personas may be authorized
  for one Avatar and one Persona for several Avatars through explicit supported concrete Grants.
  Each Grant binds Avatar, concrete subject, issuing period/generation, capability,
  validity/revocation and required granting-authority/audit facts.
- After O1→O2→O1, historical O1 Grants remain ineffective; a fresh authorized Grant is required.
  Wrong subject/period/capability, expiry or revocation cannot grant use. Existing
  management/transfer authority is distinct. Exclusive Bindings retain their documented meaning
  rather than becoming Grants by an index drop. No polymorphic subject/owner or disguised
  owner-generation reference.
- Check resolver/policy/provisioning public behavior, N:M positives and denial cases plus direct DB
  integrity. New Grant tests are planned. Independent P10a is not blocked solely by Group semantics;
  transfer/Group integration remains required before Avatar cutover.

## AV-8 — Group account meaning is not assumed ownership

- Basis: A03/A06/A10, D-2/D-5. Given actual account/creator/workspace/owner consumers, change Avatar
  ownership: independently meaningful account context is preserved while incompatible Group access
  does not silently survive. Only proven identical facts may be derived from concrete owner.
- Transitional account_surface/account_public_id never authorize ownership independently. All
  readers and data must migrate before future removal; no automatic Phase G deletion or controller
  redesign. If existing evidence cannot settle domain semantics, mark this criterion BLOCKED with
  exact decision, not PASS, a guessed conversion or NOT_APPLICABLE.
- Check Group policies/resolvers/provisioning and
  [existing Group period tests](../../test/models/avatar_group_ownership_period_test.rb), then
  planned concrete Group and transfer consequence tests. This hold affects P10b/P12b, not
  independent Grants or identifier history. Definition is accepted; the missing domain evidence is
  not resolved here.

## AV-9 — Observable retention deferral

- Basis: A07, D-6. Given an Avatar eligible for purge, run retention repeatedly: no Avatar or
  ownership history is physically deleted; one idempotent actionable/auditable deferral records
  Avatar/reason and observations without needless PII. It neither silently skips an obligation nor
  loops forever on an opaque FK error. Reuse existing deferral facilities if sufficient.
- Ownership during suspension/logical deletion remains valid. Unresolved attribute/handle/media
  deletion/anonymization policy is recorded separately; preserving history is not indefinite PII
  retention permission. Identifier dead history follows CONTACT-7/9 independently.
- Check [retention job tests](../../test/jobs/retention_purge_job_test.rb), actual deferral
  mechanism and repeat/failure paths. Avatar-specific deferral tests are planned where absent. P11b
  has no prerequisite on P11a, but shared RetentionPurgeJob edits require serialized writes and
  neighboring regressions.
