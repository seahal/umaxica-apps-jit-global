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
- `AvatarProvisioning::Create` writes the concrete Enterprise or Bureau first period in the same
  Avatar transaction, using `Avatar.created_at` as its initial boundary. The legacy period remains
  for the staged reader transition; retained data and direct test factories are not silently treated
  as migrated concrete ownership.
- Check schema/associations/resolvers, app initial and org optional provisioning, existing
  [transfer operation tests](../../test/operations/avatar_ownership_transfers_test.rb) and app/org
  controller tests. New concrete-model/provisioning coverage is planned; legacy test names are not
  proof.

The public concrete-owner regression in `test/models/avatar_test.rb` follows an Avatar's current
Enterprise period to its actual organization, with no Persona/Agent Binding required. The primary
Avatar/Enterprise/period fixtures explicitly describe that ownership and one shared synthetic start
boundary. This reference establishes a testable valid state; it does not replace the required
commit-time rejection of ownerless creation or certify all creation writers.

## AV-2 — Uninterrupted immutable temporal chain

- Basis: A05, D-3/D-4. Given a new Avatar, creation and its first owner period commit together with
  a creation-consistent boundary. Across Enterprise and Bureau periods, finite immutable start and
  immutable Avatar/owner, strictly later end, `[from,to)` adjacency and final positive infinity
  yield exactly one owner at every valid point, with no gap/overlap.
- The local concrete period slice now enforces strict intervals, same-family non-overlap, cross-
  family overlap rejection, an uninterrupted chain, exactly one current period, and direct-SQL
  history protections in PostgreSQL through
  `db/avatars_migrate/20261010130000_create_concrete_avatar_ownership_periods.rb`, its validation
  migration, and the forward immutability repair migration. The concrete Enterprise and Bureau
  models are explicit, and `test/models/avatar_concrete_ownership_period_test.rb` exercises these
  paths against the disposable database. New app/org provisioning is covered by
  `test/services/avatar_provisioning/create_test.rb` and the transfer provisioning regression.
  Transfer registry integration, independent-connection MVCC coverage, and full four-direction
  concrete period transition behavior remain unestablished.
- Attempt missing owner, equal/reversed/nonfinite start, cross-family overlap/gap, duplicate current
  periods and closed-history update/delete/truncate through SQL: DB rejects invalid commit
  explicitly, leaving prior history unchanged. Do not invent historical timestamps or rely only on
  model validation, partial current uniqueness or per-table exclusions.
- Check actual constraints/deferred triggers and real COMMIT in a new disposable catalog (MIG-3).
  Period-row checks have local tests, but their firing scope is not universal Avatar creation
  protection. A committed Avatar-only INSERT has been observed to bypass the existing period-table
  triggers; AV-1/AV-2 acceptance remains incomplete until creation writers/fixtures are prepared and
  a commit-time creation guard is proven. The accepted contract is unchanged.
- Finite starts are independently enforced by validated CHECK constraints introduced through
  `db/avatars_migrate/20261011041046_add_finite_concrete_avatar_ownership_period_starts.rb` and
  `db/avatars_migrate/20261011041103_validate_finite_concrete_avatar_ownership_period_starts.rb`. A
  matching nonfinite Avatar creation timestamp must not bypass them. Check both concrete tables,
  bypass model validation, inspect SQLSTATE/constraint identity, and verify real COMMIT/refusal on
  independent connections. The existing concrete-period test contains the direct bulk-write
  regression cases. This additive CHECK work does not prove the missing-owner or MVCC invariants.

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
- The additive registry/detail schema is implemented in
  `db/avatars_migrate/20261010150000_create_avatar_transfer_reservations.rb`. It uses one shared
  idempotency namespace, one pending reservation per Avatar, concrete detail FKs, and a deferred
  PostgreSQL cardinality trigger that requires exactly one detail of the operation's family at
  commit. `AvatarOwnershipTransfers::ReservationCreator` creates the registry and its concrete
  detail in one Avatar-DB transaction and returns the existing reservation only when the immutable
  request tuple matches. A changed payload is rejected.
- The forward migration
  `db/avatars_migrate/20261010180000_enforce_avatar_transfer_source_period_avatar.rb` adds a
  deferred database guard for the second cross-table invariant: every concrete detail's source
  ownership period must belong to the same Avatar as its registry reservation. The guard raises
  SQLSTATE `23514` and cannot be bypassed by direct SQL.
- `test/models/avatar_transfer_reservation_test.rb` covers direct-SQL cardinality, source-period
  Avatar mismatch, pending/key uniqueness, same-request replay, changed-input refusal, and two
  independent committed connections racing on one key. The exact trigger inventory is asserted by
  `test/models/enforcement_triggers_test.rb`. Existing Request/Accept/Cancel transports still use
  the legacy transfer table; their writer cutover, four-direction period transition, five-day
  expiry, authority/generation rechecks, and retry result mapping remain unestablished until the
  later P12b transition.

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
- The P10a additive slice now provides explicit concrete tables (`avatar_enterprise_persona_grants`
  and `avatar_bureau_agent_grants`), bounded capability and revocation constraints,
  `AvatarAccessGrants::IssueOperation`, and `AvatarAccessGrantResolver`. `AvatarPermissionResolver`
  consults a matching current-period Grant only when an Avatar is supplied; existing
  organization-management authority remains a separate membership decision.
  `test/services/avatar_access_grants_test.rb`, `test/resolvers/avatar_permission_resolver_test.rb`,
  and the transfer regression cover the implemented public behavior (`24 runs, 132 assertions` in
  the latest focused run).
- Check resolver/policy/provisioning public behavior, N:M positives and denial cases plus direct DB
  integrity. The legacy Binding meaning remains unchanged. The Request/Accept/Cancel transport still
  has to cut over to the registry and concrete period generations before the complete O1→O2→O1
  acceptance path can be claimed. Group membership attach, reorder, and detach now recheck the
  concrete Avatar Grant under the locked Avatar state while preserving existing organization-owner
  authority; the public service and policy coverage is in
  `test/services/group_avatar_memberships_test.rb` and
  `test/policies/group_avatar_membership_policy_test.rb`. Transfer registry cutover and full Group
  transition consequences remain required before Avatar cutover. P10a and this Grant integration are
  independently reviewable and are not blocked solely by the unresolved Group account semantics in
  AV-8.

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
  independent Grants or identifier history. Current `GroupManagement::Create` and
  `AvatarGroupPolicy` compare/filter selected subject account separately from owning collective; the
  app Avatar controller resolves that account as `ClientPersona`. The owning specification records
  these concrete observations. Account identity must not be replaced by owner identity. These
  observations do not establish data reconciliation, a concrete account relationship, migrated
  consumers, or passing transfer consequences; those remain required for this criterion.

## AV-9 — Observable retention deferral

- Basis: A07, D-6. Given an Avatar eligible for purge, run retention repeatedly: no Avatar or
  ownership history is physically deleted; one idempotent actionable/auditable deferral records
  Avatar/reason and observations without needless PII. It neither silently skips an obligation nor
  loops forever on an opaque FK error. Reuse existing deferral facilities if sufficient.
- Ownership during suspension/logical deletion remains valid. Unresolved attribute/handle/media
  deletion/anonymization policy is recorded separately; preserving history is not indefinite PII
  retention permission. Identifier dead history follows CONTACT-7/9 independently.
- Check [retention job tests](../../test/jobs/retention_purge_job_test.rb) and the focused
  [Avatar retention tests](../../test/jobs/avatar_retention_purge_test.rb). The implemented
  `avatar_purge_deferrals` table records an idempotent `(avatar_id, reason_code)` observation and
  increments it under a row lock; ownership history is never physically deleted by the purge job. An
  eligible Avatar without concrete ownership history also remains intact, with an explicit
  `retention_policy_pending` deferral; encrypted moniker history is preserved. The absence of
  ownership periods does not authorize deletion. Personal-data retention duration and final
  deletion/anonymization policy remain unresolved and are not inferred from this deferral mechanism.
