# Avatar Organization Ownership

Status: implementing

Approved decisions govern the staged implementation below.

## Acceptance references

The stable local criteria reference the durable observable definitions in
[Avatar acceptance](../../docs/checklists/avatar-ownership.md). They are definitions, not PASS
results; investigate the implementation and revision-bound evidence separately.

- AC-1: Satisfy AV-1's concrete organization-only identity and provisioning contract.
- AC-2: Satisfy AV-2's uninterrupted immutable temporal ownership contract.
- AC-3: Satisfy AV-3's isolated concurrency and approved trigger contract.
- AC-4: Satisfy AV-4's global registry and concrete-detail cardinality contract.
- AC-5: Satisfy AV-5's staged client idempotency compatibility contract.
- AC-6: Satisfy AV-6's atomic local transfer and revalidated authority contract.
- AC-7: Satisfy AV-7's generation-bound N:M access Grant contract.
- AC-8: Satisfy AV-8's independent Group account semantics and consumer migration contract.
- AC-9: Satisfy AV-9's observable retention deferral and privacy boundary contract.

## Current approved contract

Authority: the user's Strategic Review Final / Implementation Authorization (D-1–D-11), subsequent
Blocker Resolution and Execution Directive, and `nine.md` Sections 5–9. Independent acceptance is
defined in `docs/checklists/avatar-ownership.md` (AV-1–AV-9), with execution results recorded
separately in `evidence/`. Implementation is incomplete; past audit observations and passing tests
do not certify the remaining cutover.

- **D-1:** use the actual local working tree. Recheck repository, branch, HEAD, differences and
  migration state; preserve unrelated work. The historical baseline below is not current state.
- **D-2:** establish Group account meaning from actual consumers. Account selection and owning
  organization are distinct unless authoritative evidence proves identity. Preserve meaningful
  account context through concrete relationships; legacy columns are transitional and cannot
  authorize ownership independently. Only the affected conversion is held when evidence is absent.
  Grants proceed independently. Removal remains Phase G after consumer/data migration. Current
  consumer evidence distinguishes selected account from organization owner:
  `GroupManagement::Create` compares `account_public_id` with `subject_public_id` while separately
  requiring `owner_collective_public_id`; `AvatarGroupPolicy` filters both selected account and
  collective owner. The app Avatar controller resolves the selected account as `ClientPersona`; the
  accepted surface naming ADR identifies org's concrete Persona as `Agent`. Therefore deriving the
  account identity from the owning organization would lose an independent authorization context.
  Preserve that distinction in concrete relationships. This evidence does not prove that every
  persisted row is valid or that conversion/cutover has occurred.
- **D-3/D-4:** narrowly necessary PostgreSQL ownership-integrity DDL and concurrency guards are
  approved, including a dedicated integrity counter only when real concurrent transactions prove it
  necessary. Prefer declarative constraints. No required trigger count, business side effects,
  silent correction or broad raw SQL authority. Every function is attached in the same reversible
  migration and documented/tested for invariant, events, locks, SQLSTATE and isolation behavior.
- **D-5:** explicit lifecycle-aware concrete N:M access Grants are required. Exclusive Bindings
  retain their separate meaning; adding period IDs to Bindings alone is rejected. Grants bind the
  issuing ownership generation and cannot reactivate after O1→O2→O1. Organization management
  authority remains separate from Avatar-use authorization. Persistence polymorphism is forbidden.
- **D-6:** use observable, idempotent purge deferrals. No physical Avatar or ownership-history
  deletion is authorized in this implementation, including an Avatar without concrete history.
  Personal-data deletion/anonymization/retention policy remains a separate unresolved decision;
  history preservation does not authorize indefinite PII retention.
- **D-7:** the residual cross-table idempotency gap is rejected. A concrete type-neutral registry in
  the Avatar DB reserves global operation keys and one pending transfer per Avatar across four
  concrete detail families. It stores no polymorphic owner/actor/detail pair. Direct SQL and
  concurrency must preserve detail cardinality. Separate Zenith DB work is not atomically committed
  with Avatar; retries/reconciliation use immutable request inputs and identity.
- **D-8:** canonical lowercase 36-character UUID v4/v7 client keys use a staged additive API. Same
  key and authorized immutable request returns the recorded operation/result; changed inputs or
  initiator are refused. Legacy keyless callers stay compatible during the documented transition
  without the full retry guarantee. Random server keys per retry are not client idempotency.
- **D-9:** inventory, dry-run, resumable idempotent operational backfill, reconciliation and cutover
  are separate from schema migrations. Preserve identities, reliable dates, actors and valid states;
  ambiguous rows are reported unchanged. Quiesce writers before cutover; no legacy authority
  fallback afterward. Prepare forward-only recovery. Production operations need separate approval.
- **D-10:** verified cutover requires a DB write barrier on legacy owner tables, including INSERT,
  UPDATE, DELETE and TRUNCATE. Prefer effective ordinary-role permissions; the named narrow
  rejection-trigger fallback is authorized when role architecture is insufficient. Activate only
  after writer/backfill verification. No automatic table removal.
- **D-11:** real COMMIT tests use run-owned disposable PostgreSQL databases and independent
  connections, with normal migrations and actual constraints/triggers. Test relevant READ COMMITTED,
  REPEATABLE READ and SERIALIZABLE conflict/retry behavior. No shared DB cleanup through disabled
  triggers, DROP or TRUNCATE; inability to provision isolation is BLOCKED, not mocked PASS.

Ownership is organization-only, concrete Enterprise/app or Bureau/org, temporal and immutable. Each
Avatar has one uninterrupted `[valid_from, valid_to)` chain, finite immutable starts, strictly later
ends, infinity for the final period, no overlap/gap and exactly one current owner at COMMIT.
Creation and first period share one Avatar transaction. Transfers preserve all identities and all
four directions; revalidate authorities, expiry and source generation under locks and use one
database-derived instant. Keep the five-day Request/Accept/Cancel contract and com boundary. Do not
invent historic dates, fraction/individual ownership, generic owner pairs or cross-DB atomicity.

## Historical audit (superseded proposals)

The following findings/options preserve the original audit record. They are not pending approvals or
current implementation instructions where they conflict with the adopted decisions above. In
particular the D-5 Binding-only proposal, D-7 accepted gap, D-8 arbitrary key format and D-11
shared-database trigger suppression are rejected. Historical table/data counts must be rechecked.

### Original audit purpose

The approved change unifies Avatar ownership on concrete, period-based ownership tables for
Enterprise and Bureau (approved requirements R1–R10 of the implementation instruction). This
document records only what the Phase A audit found that the approved requirements do not settle.
Each item states the finding, the evidence, the options, and a recommendation, so that it can be
approved or redirected without re-reading the code.

Audit baseline: branch `feature`, commit `809ed57629f03052ba311c8c953f4aa682c93ebf`, PostgreSQL
17.7, development Avatar database.

### Original items requiring a decision

### D-1. The audit baseline differs from the instruction

- The instruction names repository `seahal/umaxica-apps-jit-global` and commit `6eb02aa9…`, with 557
  uncommitted paths. The worktree's remote is `seahal/umaxica-app-jit`, the commit is `809ed576…`,
  and 77 paths are uncommitted. Only one of them is Avatar-related
  (`lib/avatar_legacy_client_id_detector.rb`).
- Decision needed: confirm that this worktree is the intended target.

### D-2. `avatar_groups.account_surface` cannot be made concrete without a redesign

- Finding: `avatar_groups` stores `account_surface` (`app`, `org`, `com`) with `account_public_id`.
  This is a type-discriminated reference to a Client Persona or an Agent. Group policies and
  services use it as the "selected account" scope, separately from the group's owner.
- Every concrete form conflicts with an approved rule:
  1. Two nullable columns with an exactly-one check is an exclusive arc, which is prohibited.
  2. Splitting `AvatarGroup` into a Persona-scoped and an Agent-scoped table changes controllers and
     routes, which the instruction excludes without approval.
  3. Deriving the account type from the group's owner table (Enterprise-owned means Persona,
     Bureau-owned means Agent) removes the discriminator, but requires relaxing or dropping the
     `NOT NULL` column and its check, which is a destructive schema change.
- Recommendation: option 3, performed in Phase G together with the other legacy-column removal.
  Until then the column stays, and the group's owner is read only from the new concrete tables.

### D-3. Raw SQL in migrations

- Finding: `generic/migrations.mdc` forbids raw `execute(...)` without explicit approval, and
  `generic/rails-change-discipline.mdc` prohibits new raw SQL DDL. The required cross-table
  invariants (no overlap across the Enterprise and Bureau tables, no gap, a current owner always
  exists, closed periods are immutable, no `DELETE` or `TRUNCATE`) cannot be expressed with `CHECK`,
  `UNIQUE`, `EXCLUDE`, or foreign keys alone.
- `adr/database-trigger-usage-boundary.md` permits triggers for exactly this case, and five existing
  migrations in `db/app_principals_migrate` already create triggers with `execute`.
- Planned scope: about twenty triggers in the Avatar database, covering the two Avatar period
  tables, the two group period tables, the four transfer tables, the two binding tables, `avatars`,
  and `avatar_groups`. Everything expressible declaratively (interval checks, `EXCLUDE` with
  `btree_gist`, composite foreign keys, partial unique indexes) uses the migration DSL.
- Decision needed: confirm that the instruction's trigger requirement is the explicit approval the
  migration rule asks for.

### D-4. A trigger increments a lock counter

- Finding: locking the `avatars` row alone does not protect a `REPEATABLE READ` transaction. It can
  take the lock after a concurrent transfer commits and still decide from its older snapshot. The
  row must actually change for PostgreSQL to raise a serialization failure.
- Design: a `bigint` column `ownership_write_lock_counter` on `avatars` and `avatar_groups`,
  incremented by the period and transfer triggers. It is never read to decide ownership.
- Conflict: the trigger ADR says triggers must not maintain derived columns and must raise rather
  than write. The counter is a concurrency token, not a derived fact, but it is a write performed by
  a trigger.
- Options: (a) accept this as a recorded exception in the ADR; (b) have the application increment
  the counter, in which case direct SQL that skips the increment loses the `REPEATABLE READ`
  protection.
- Recommendation: (a).

### D-5. Usage entitlement: no per-Avatar grant exists today

- Finding: `AvatarPermissionResolver` grants every Avatar permission to a member whose membership
  kind is OWNER in the owning organization, and nothing to anyone else. `AvatarPersonaBinding` and
  `AvatarAgentBinding` are not read on any authorization path. They are exclusive assignments (one
  active binding per Avatar and per Persona or Agent), not usage grants. The `member_avatar_*`
  tables are not read by the resolver either.
- Consequence for R7: the only entitlement that could revive after an O1 → O2 → O1 round trip is the
  binding.
- Design: each binding records the ownership period it was granted under
  (`avatar_enterprise_ownership_period_id` on Persona bindings, `avatar_bureau_ownership_period_id`
  on Agent bindings). Accepting a transfer revokes the bindings of the closing period, and the
  database rejects an active binding that points at a closed period. No new grant tables are added.
- Decision needed: confirm that R7 is satisfied by period-scoped bindings, and that separate Persona
  and Agent grant tables are not required in this change.
- Related debt, not changed here: both binding tables reference `persona_id` and `agent_id` as
  cross-database `bigint` values, which `adr/cross-db-reference-policy.md` classifies as an existing
  violation.

### D-6. Retention purge of Avatars

- Finding: `RetentionPurgeJob` lists `Avatar` among the models purged with `delete_all`. Foreign
  keys with `ON DELETE RESTRICT` reject that delete, so the job fails again on every fifteen-minute
  run. With the new history tables the delete can never succeed.
- Design: remove `Avatar` from the generic delete path. For each Avatar past `purge_eligible_at`,
  record one row in a new table `avatar_purge_deferrals` (Avatar, reason
  `ownership_history_retention_undecided`, first and last observation time) and emit a log event. No
  Avatar or ownership row is deleted.
- Decisions needed: approve the new table; and decide separately which Avatar attributes count as
  personal data to be erased or anonymized while ownership history is kept. That second question is
  not answered by this change.

### D-7. Cross-table uniqueness of transfer identifiers

- Finding: with four transfer tables, uniqueness of the public identifier and of the idempotency key
  can only be declared per table. "At most one pending transfer per Avatar" is safe at every
  isolation level, because it is serialized on the Avatar row (D-4).
- Residual gap: two requests from the same requester that reuse one idempotency key for two
  different Avatars, landing in two different tables, at the same instant, under `REPEATABLE READ`,
  could both be stored. An advisory lock closes the gap under `READ COMMITTED` (the application
  default) and `SERIALIZABLE`. A later replay that finds two rows fails closed. Ownership itself is
  never affected.
- Options: (a) accept the gap as documented; (b) add a shared key-registry table, which is one more
  table and close to a supertype table.
- Recommendation: (a).

### D-8. The idempotency key changes the request contract

- Finding: R6 requires an idempotency key on transfer requests. The current `create` endpoints on
  the `app` and `org` surfaces accept none.
- Design: a required request parameter, 8 to 128 characters from `A-Z a-z 0-9 . _ ~ -`, scoped to
  the requesting Persona or Agent. The stored fingerprint is a SHA-256 of the Avatar, the source
  ownership period, and the target organization.
- Decision needed: approve the added required parameter (a change to an externally visible contract)
  and the key format. The alternative is a server-generated key in the form, which keeps the
  contract for browsers but gives API clients no replay protection.

### D-9. Conversion of existing data is a task, not a migration

- Finding: the development database has zero rows in every ownership table. The shared test database
  holds one fixture Avatar with no ownership period. Production has not been inspected.
- Design: schema migrations only add structures. A read-only inventory task and a separate
  conversion task move rows from the legacy tables into the concrete tables. The conversion stops,
  without guessing, on a missing owner reference, a status that disagrees with the period, an
  overlapping or gapped timeline, an Avatar with no period, or a pending legacy transfer.
- Consequence: between the schema migration and the conversion, a legacy Avatar without a concrete
  period cannot receive a new binding or transfer. The cutover therefore needs a write pause.
- Decisions needed: approve running the conversion as an operator task; production inventory and
  cutover remain separately approved steps.

### D-10. Legacy structures remain until Phase G

- Tables `avatar_ownership_periods`, `avatar_ownership_statuses`, `avatar_ownership_transfers`,
  `avatar_group_ownership_periods`, and columns `avatars.owner_organization_id` and
  `avatar_ownership_periods.owner_organization_id` stay in the database. Their Ruby models are
  removed in Phase D, so no application path reads or writes them.
- Nothing at the database level blocks direct SQL writes to the legacy tables after cutover.
- Decision needed: whether to add write-rejecting triggers on the legacy tables at cutover, or to
  rely on the removal of the models until the tables are dropped.

### D-11. Test-suite consequences

- Deferred constraint triggers fire at `COMMIT`. Transactional tests never commit, and Rails
  disables triggers while loading fixtures, so existing tests that create an Avatar without an owner
  keep passing. The new invariants are therefore verified only by non-transactional tests on
  independent connections.
- Those tests cannot delete the ownership history they create. Cleanup needs
  `session_replication_role = replica` in test code, or the rows are left in the test database.
- Decision needed: which of the two cleanup approaches is acceptable.

### Historical draft disposition

Six migration drafts are preserved under `specs/avatar-organization-ownership/migration-drafts/`,
outside Rails migration discovery. Four are generator stubs. Their contents have not changed during
the authentication acceptance repair. They were moved because test preparation was discovering and
attempting to apply this unfinished feature despite the pause recorded above.

| File                                                                      | State                |
| ------------------------------------------------------------------------- | -------------------- |
| `20261009180016_add_avatar_ownership_write_lock_counters.rb`              | written              |
| `20261009180021_create_avatar_concrete_ownership_periods.rb`              | written              |
| `20261009180026_create_avatar_group_concrete_ownership_periods.rb`        | empty generator stub |
| `20261009180032_create_avatar_concrete_ownership_transfers.rb`            | empty generator stub |
| `20261009180037_validate_avatar_binding_ownership_period_foreign_keys.rb` | empty generator stub |
| `20261009180042_create_avatar_purge_deferrals.rb`                         | empty generator stub |

The historical audit required restoring these drafts to `db/avatars_migrate/` only after decisions
were approved, all six migrations are complete, and their production safety has been reviewed. In
particular, indexes on existing binding tables need concurrent creation, and trigger DDL needs the
explicit approval described in D-3. Empty stubs must never be recorded as applied migrations.

The authentication acceptance run attempted these drafts on its verified disposable test catalog:
the write-lock-counter migration applied, and the ownership-period migration was rejected by
`strong_migrations` at its non-concurrent binding index. That catalog is not a clean reconstruction
baseline. A new disposable catalog is required for subsequent empty-database migration acceptance;
the old catalog must not be rolled back or dropped as part of this source-file repair. No shared or
production database migration was performed by this repair.
