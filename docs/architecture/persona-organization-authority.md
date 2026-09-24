# Persona and Organization Authority

This document is the current implementation reference for the adopted surface-local authority model.
It describes the shape authored in Phase 2 and clearly separates that shape from the runtime
cutover, which is not enabled yet.

## Vocabulary and boundaries

`Persona` and `Organization` are Ruby interfaces, not persisted base models. The concrete resources
and principals are independent per surface:

| Surface | Principal  | Persona                      | Organization                 | Database     |
| ------- | ---------- | ---------------------------- | ---------------------------- | ------------ |
| `app`   | `Client`   | `ClientPersona` (`personas`) | `Enterprise` (`enterprises`) | `app_zenith` |
| `com`   | `Visitor`  | `Individual` (`individuals`) | `Company` (`companies`)      | `com_zenith` |
| `org`   | `Operator` | `Agent` (`agents`)           | `Bureau` (`bureaus`)         | `org_zenith` |

`ClientIdentity`, `VisitorIdentity`, and `OperatorIdentity` remain RP/IdP binding records. They are
not authority principals or owners. `OperatorOrganization` is the legacy org-principal model mapped
to `organizations`; it is not the common Organization interface.

The surfaces do not share authority tables, STI, polymorphic authority references, or foreign keys
across databases. Existing assignment and membership graphs are transitional and are not a fallback
authority source for the new tables.

## Approved owner-authority decision (2026-09-23)

After each resource-family cutover, the concrete ownership table for that family is the sole owner
authority. The approved mappings are `Client -> Persona/Enterprise`, `Visitor -> Individual/Company`,
and `Operator -> Agent/Bureau`. Identity bindings, assignments, memberships, administrator
relations, legacy owner fields, and legacy `Organization` hierarchy data are migration evidence
only. Legacy `Organization` is not `Bureau`, and no lifecycle transition promotes a member or
administrator to owner.

The ownership fact is retained independently from authority eligibility. Suspended principals do
not exercise an existing relation; inactive/discarded/deleted principals and inactive/retained
resources are not automatically adopted as new authority candidates. Candidate mapping is
deterministic: exactly one explicitly valid candidate may map, while zero, ambiguous, inactive-only,
cross-surface, membership-only, administrator-only, legacy-only, and contradictory candidates are
rejected or held for manual review/ownerless disposition. No first/last/oldest/newest tie-breaker is
allowed.

An existing ownership row records an ownership fact only. It is not sufficient evidence that the
principal may currently exercise authority: the cutover guard separately requires the owner to be
eligible under the configured active status, login, and access checks. An ownership row whose
principal is ineligible remains retained data but keeps the resource unresolved for family cutover.

Cutover is family-scoped. The new relation is created and backfilled before authorization reads it;
unresolved authority-required active rows must be zero before the family consumer switches. At that
point legacy authority reads and writes stop for that family. Rollback is allowed before the first
consumer read; after that point recovery is forward-only to prevent split-brain authority.

The owner-authority cutover does not by itself replace the selector/switcher candidate graph.
`BaseSelectorAuthority` and `BaseSwitcherAuthority` resolve an act-as context through the existing
surface-local identity, assignment, membership, and avatar contracts. Those relations can represent
legitimate delegated or member access and are not owner authority. Replacing this path with an
owner-only query would be an unapproved access-contract change. A future consumer cutover must name
an owner-specific authorization consumer and separately review its interaction with delegated access
before changing selector or switcher behavior.

## Phase 2 schema authored

The three migrations create eleven concrete authority tables per surface:

| Surface | Ownership                                            | Grants                                                                                                                                                                                                                                | Transfer request                                                                       |
| ------- | ---------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| `app`   | `client_persona_ownerships`, `enterprise_ownerships` | `client_persona_administration_grants`, `client_persona_delegation_grants`, `client_persona_usage_grants`, `client_persona_view_grants`, `enterprise_administration_grants`, `enterprise_delegation_grants`, `enterprise_view_grants` | `client_persona_ownership_transfer_requests`, `enterprise_ownership_transfer_requests` |
| `com`   | `individual_ownerships`, `company_ownerships`        | `individual_administration_grants`, `individual_delegation_grants`, `individual_usage_grants`, `individual_view_grants`, `company_administration_grants`, `company_delegation_grants`, `company_view_grants`                          | `individual_ownership_transfer_requests`, `company_ownership_transfer_requests`        |
| `org`   | `agent_ownerships`, `bureau_ownerships`              | `agent_administration_grants`, `agent_delegation_grants`, `agent_usage_grants`, `agent_view_grants`, `bureau_administration_grants`, `bureau_delegation_grants`, `bureau_view_grants`                                                 | `agent_ownership_transfer_requests`, `bureau_ownership_transfer_requests`              |

Each surface also has one synchronization table (`client_authority_locks`,
`visitor_authority_locks`, or `operator_authority_locks`). These rows serialize quota-affecting
writes. `AppZenithRecord`, `ComZenithRecord`, and `OrgZenithRecord` are the canonical connection
owners; the semantic RP/principal base classes inherit from them and remain separate Ruby
interfaces. The lock rows are not ownership and do not grant access.

The authored table contract is:

- ownership rows have a concrete resource FK, a concrete principal FK, a nonnegative
  `ownership_revision`, timestamps, and a unique resource FK;
- ownership rows are never independently deleted; transfer updates the existing row, and terminal
  owner references remain inert retained data where the lifecycle contract requires them;
- grant rows have concrete resource/principal FKs, timestamps, and a unique resource/principal pair;
- transfer rows have concrete source/destination FKs, public ID, explicit status, requested and
  expiry times, expected ownership revision, terminal timestamps, and a partial unique pending row
  per resource;
- ordinary FKs, reverse-principal indexes, nonnegative revision checks, distinct source and
  destination checks, and `requested_at < expires_at` checks are explicit;
- authority migrations disable the automatic single-column indexes generated by `t.references`; only
  the explicit unique, composite, partial, or reverse-principal indexes required by the access and
  due-work queries are created. This avoids maintaining a redundant index beside a leftmost unique
  or composite index;
- no revoked-history JSON, generic role discriminator, shared table, fake ID, or bearer capability
  is stored in these tables.

The migrations are schema-only and reversible. They do not backfill or choose owners. The
repository-only direct-binding backfill operation is separately exercised against isolated test
databases; it does not enable runtime authorization or perform production backfill.

`AuthorityOwnerDirectBindingBackfillOperation` requires a human-reviewed `owner_public_id` for every
backfill mutation, including resources with an otherwise unambiguous legacy identity binding. That
input is resolved only against the configured surface-local principal class and is rejected when it
is missing, inactive, or from another surface; legacy identity bindings, memberships, assignments,
administrator relations, and legacy `Organization` remain candidate evidence rather than automatic
owner authority. The six concrete resource families now have separate lifecycle tables with the
states `active`, `inactive`, `discarded`, `deleted`, and `retained`. A missing lifecycle row is
unresolved, never an implicit `active` state. New creator operations insert the explicit `active`
lifecycle row in the same surface-local transaction as the resource and ownership relation.
`AuthorityResourceLifecycleBackfillOperation` requires an explicitly reviewed state for an existing
resource and is idempotent; it never replaces an existing state. `AuthorityOwnerCutoverGuard` is a
read-only family guard and fails closed for missing or non-active lifecycle rows.
`AuthorityOwnerPredeploymentBackfillOperation` is the atomic pre-deployment unit for applying both
reviewed inputs to one resource: a rejected lifecycle state rolls back an owner row created in the
same unit, and replaying the same pair is idempotent. It is not a runtime authorization switch.
`AuthorityOwnerFamilyCutoverOperation` is the separate family-level boundary: it rechecks the
read-only guard under a resource-table lock and creates one immutable surface-local singleton
marker. That marker is the persisted point of no return; backfill is rejected afterwards and
recovery is forward-only.
`AuthorityOwnerFamilyBackfillOperation` validates a complete explicitly reviewed mapping for one
resource family, rejects duplicate resource entries, and applies the batch atomically. A rejected
row rolls back earlier rows from that batch, while replaying the same complete mapping is
idempotent. It remains a pre-cutover migration operation: it does not infer owners, switch
authorization consumers, or permit rollback after a family marker has been established.
The read-only `authority:cutover_guard` task evaluates all six families and emits a readiness report
without changing ownership, lifecycle, authorization consumers, or cutover state.

## Ownership and creation contract

The intended writer path is:

1. authenticate and authorize the concrete surface principal at the controller/use-case boundary;
2. acquire the surface-local principal lock on the canonical surface writer connection;
3. lock and re-read principal eligibility, then count ownership rows under that lock;
4. create the concrete resource, its lifecycle row, and its one ownership row in the same writer
   transaction;
5. commit both rows together, without creating implicit grant rows. A runtime rollback test must
   prove that principal, resource, and authority rows use the same checked-out writer connection;
   equal database names alone are insufficient evidence.

Phase 2 includes explicit creators for all six concrete resources. They require the authenticated
actor and owner to be the same concrete principal, require the fixed surface status to be `ACTIVE`,
`login_allowed?`, and `access_enabled?`, require an active matching RP binding for Persona
resources, enforce the adopted 10 Persona / 2 Organization owned resource limits, and use fixed
concrete classes. The selector bootstrap calls these creators only for newly created resources with
an eligible principal, so those resources receive their ownership and `active` lifecycle rows in
the same surface-local transaction. Withdrawal, inactive, or access-restricted legacy bootstrap
flows retain their legacy graph construction until family cutover. Existing resources remain
migration candidates; bootstrap does not infer or repair their legacy authority. This is
creation-path integration, not an authorization cutover: the family gate, reviewed backfill,
consumer switch, and runtime connection rollback proof remain prerequisites for changing
authorization reads.

The bootstrap also acquires the existing surface-local authority lock for the complete graph
transaction. This serializes concurrent bootstrap calls for one principal before the account and
collective existence checks; the lock is a concurrency mechanism and does not grant ownership or
act-as access.

The lock order for the current creation slice is principal lock, principal row lock and eligibility
re-read, quota read, resource insert, ownership insert. The six creators use the canonical surface
writer transaction and `lock.find` for the concrete principal before checking the fixed `ACTIVE`
status, `login_allowed?`, and `access_enabled?`. Administrative access locks and inactive principal
statuses therefore cannot be bypassed by a new authority creation. Future transfer and lifecycle
operations must use the same surface-local lock first, then resource, ownership, request, and grant
rows in a fixed documented order. Operations must not rely on Ruby uniqueness validation or an
existence check without a database lock/constraint.

Quota policy queries are owner-scoped. `AccountQuotaPolicy` and `OrganizationQuotaPolicy` resolve
the concrete surface principal to the corresponding ownership table and count only resources
reachable through that owner's ownership rows; an optional resource relation is intersected with
that owned set. A grant row, an unowned resource, or a resource owned by another principal does not
consume the quota. The lifecycle contract is now enforced at this policy boundary: only resources
with an explicit `active` lifecycle row count, and a missing lifecycle row or ineligible principal
fails closed. All six concrete creator operations call the matching policy while holding the
surface-local principal lock, so creator-side quota checks cannot bypass the same lifecycle rule by
counting ownership rows directly. Selector/switcher act-as candidates remain on their separate
membership and delegation contract.

The owner-specific quota consumer reads through `AuthorityOwnerResourceScopeQuery`. This query
accepts only the configured surface-local principal and resource family, and never falls back to an
identity binding, assignment, membership, administrator relation, or legacy `Organization` row.
The owner-specific `AccountPolicy` is also staged on the same boundary: before its concrete family
marker it preserves the existing legacy contract, while after the marker it requires the explicit
ownership relation, eligible principal, and active resource lifecycle. It does not consult the
legacy identity binding after cutover. `OrganizationPolicy` and the selector/switcher candidate
graph remain delegated/member access contracts and are not replaced by owner-only reads. The
family-wide authorization cutover remains open until every owner-specific consumer in the affected
family is named, switched, and proven with isolated acceptance evidence.

## Pending transfer contract

The table shape reserves the adopted consent protocol: one pending request per resource, 24 elapsed
hours from `requested_at`, an immutable nominated recipient, expected ownership revision, and
explicit terminal statuses. Acceptance, cancellation, rejection, and invalidation are not part of
the current Phase 2 enablement. They require recipient authentication, existing step-up policy,
resource/principal lifecycle gates, quota-at-acceptance, and a one-connection locked acceptance
transaction before routes are exposed.

## Lifecycle, encryption, and migration status

The adopted lifecycle state is stored in six concrete, surface-local lifecycle tables rather than
by reinterpreting principal retention columns. New resources created through the six authored
creator operations receive an explicit `active` row atomically; existing resources remain
unresolved until an explicitly reviewed backfill state is supplied. The scrub inventory, grant
operations, transfer routes, irreversible discard, asynchronous scrubbing, encrypted-name
backfill, and old-authority retirement remain blocked by the conflict ledger until their separate
data shape and isolated tests are complete.

Before cutover, the deployment runbook must provide:

- a read-only owner inventory and restartable mapping/backfill record from documented legacy
  evidence, with ambiguous/missing owners blocking the family cutover;
- separate schema migration and restartable data backfill steps;
- one-connection rollback and concurrency proofs on isolated PostgreSQL;
- surface-local action/field policy tests and explicit retirement of old authorization fallback;
- no production migration, physical deletion, or external identity/provider change from this
  repository-only phase.

## Current guarantees and non-guarantees

The Phase 2 code guarantees static model/table separation, a concrete unexposed creation contract,
an explicit reviewed-owner backfill slice, and a fail-closed family cutover gate for isolated
pre-deployment verification. It does not
claim that existing data has an owner, that all six families have been backfilled, that the new
tables are the current authorization source, or that production cutover is safe. Those claims
require the lifecycle, consumer, migration, and deployment gates recorded in `conflict.md` and the
integrated plan.
