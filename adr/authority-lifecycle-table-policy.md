# Authority and Lifecycle Table Policy

## Status

Accepted

## Date

2026-07-03

## Context

The core resource model must not become a direct ownership tree. Relationship rows need lifecycle
semantics and clear write ownership.

## Decision

Relationships among Identity, Account, Organization, Unit, Avatar, and Group must be modeled as
authority or lifecycle tables instead of direct ownership foreign keys on base resource rows.

Authority and lifecycle tables must be able to represent:

- role
- state
- primary or representative selection
- valid_from
- valid_to
- granted_by
- revoked_by
- reason
- audit reference

Controllers must not directly create, update, or destroy authority or lifecycle rows. Controllers
call use-case services. The services own lifecycle transitions, authorization, validation, audit
references, and transaction boundaries.

DB constraints are the primary enforcement layer for table invariants. Rails validations may mirror
the same rule for earlier user-facing feedback, but validations must not be the only protection for
authority/lifecycle correctness.

The first Avatar DB constraint slice added or verified these protections:

- `avatar_assignments.role` is constrained to known v1 and legacy roles: `owner`, `affiliation`,
  `administrator`, `editor`, `reviewer`, and `viewer`.
- `avatar_assignments` already has primary-role partial unique indexes for one `owner` and one
  `affiliation` per Avatar, plus a unique `(avatar_id, user_id, role)` assignment key.
- `avatar_memberships.valid_from <= valid_to` is enforced by `chk_avatar_memberships_valid_period`.
- `avatar_memberships` already has active relation uniqueness on `(avatar_id, actor_id)` where
  `valid_to = 'infinity'`.
- `avatar_persona_bindings.revoked_at IS NULL OR revoked_at >= assigned_at` is enforced by
  `chk_avatar_persona_bindings_revoked_after_assigned`.
- `avatar_persona_bindings` already has active partial unique indexes for active pair, active
  Avatar, and active Persona relations, plus unique `public_id`.
- `avatar_lifecycle_events.from_state_key` and `to_state_key` reference
  `avatar_lifecycle_states.key`, and `chk_avatar_lifecycle_events_state_changes` rejects no-op
  events where both keys are equal.

The Avatar binding symmetry slice extended the same active-history contract to
`avatar_agent_bindings` and `avatar_individual_bindings`:

- both tables now carry unique `public_id`, non-null `assigned_at`, and nullable `revoked_at`
- both tables enforce `revoked_at IS NULL OR revoked_at >= assigned_at`
- both tables use active partial unique indexes for active pair, active Avatar, and active subject
  uniqueness

The lifecycle service remains responsible for transition authorization, including the rule that
`deleted` is terminal and does not emit an event for rejected transitions.

## Approved surface-local owner-authority amendment (2026-09-23)

The pre-deployment owner-authority decision is surface-local and concrete. After a resource-family
cutover, the following relation is the only owner authority for that family:

| Surface | Principal | Resource families |
| --- | --- | --- |
| `app` | `Client` | `Client -> ClientPersona`, `Client -> Enterprise` |
| `com` | `Visitor` | `Visitor -> Individual`, `Visitor -> Company` |
| `org` | `Operator` | `Operator -> Agent`, `Operator -> Bureau` |

Identity bindings, assignments, memberships, administrator relations, legacy owner fields, and
legacy `Organization` hierarchy data are migration evidence only. Legacy `Organization` is not
`Bureau`; it must not be used to infer a `Bureau` owner. No shared owner table, STI, polymorphic
owner reference, cross-surface relation, or lifecycle-based automatic transfer is permitted.

Ownership facts and current authority eligibility are separate. A suspended principal retains the
ownership fact but cannot exercise authority. Inactive or discarded principals and resources are
not automatic candidates, and unresolved or ineligible rows fail closed. Candidate mapping has no
tie-breaker: zero, ambiguous, inactive-only, membership-only, administrator-only, legacy-only,
cross-surface, and contradictory candidates require rejection or manual review.

Cutover is family-scoped. The new relation is created and backfilled before authorization reads it;
the family gate requires no unresolved authority-required active rows. Explicitly inactive,
discarded, deleted, or retained resources do not require an active owner authority for that gate;
their historical relation may remain while normal authorization remains unavailable. A missing or
unknown lifecycle state remains unresolved and fails closed. Before the first consumer read,
rollback is permitted. After a consumer has read the new relation, rollback to legacy authority is
forbidden and recovery is forward-only. Legacy records may remain historical/read-only until their
separately approved retirement conditions are met.

This amendment approves the authority semantics and the pre-deployment lifecycle representation
used by the current implementation slice: six concrete, surface-local lifecycle tables, one per
resource family, each with a concrete resource foreign key, an explicit checked state, and a
database-clock `state_changed_at`. A missing lifecycle row remains unresolved and is never
interpreted as active. Existing resources require an explicitly reviewed, idempotent backfill;
the lifecycle tables do not by themselves authorize a consumer cutover.

This owner-authority amendment does not redefine selector/switcher act-as context. The
surface-local identity, assignment, membership, and avatar checks used by those paths can encode
legitimate delegated or member access and are not owner facts. An owner-only replacement requires a
separate access/delegation decision and consumer-specific cutover review; the presence of an
ownership row must not be used to infer that selector or switcher behavior should change.

The current owner-specific consumer boundary is intentionally narrower: `AccountPolicy` switches
from the legacy identity contract only after the concrete account-family marker, while the quota
policies and six concrete creator operations use the configured ownership/lifecycle relation for
owner-specific quota decisions. `OrganizationPolicy` remains a membership policy. Ownership-transfer
request tables reserve a future consent protocol, but acceptance, cancellation, and recovery routes
are not enabled by this amendment; they require recipient authentication, existing step-up policy,
lifecycle and quota checks, and one locked transaction to be specified separately. No recovery API
may be invented merely to make a post-cutover rollback test pass.

The pre-deployment migration boundary uses the read-only owner inventory as its conflict audit.
`AuthorityOwnerFamilyBackfillOperation` accepts a complete explicitly reviewed family mapping and
applies it atomically; it is not an inference, preview, or consumer-switch API. A duplicate,
missing, inactive, ambiguous, cross-surface, or conflicting input is rejected or remains
manual-review data, and replaying an accepted mapping is idempotent. The separate
`AuthorityOwnerFamilyCutoverOperation` rechecks the guard under a resource-table lock and creates
one immutable surface-local singleton marker. The marker is the persisted point of no return;
reviewed backfill is rejected after it and recovery is forward-only.

## Consequences

Bare join tables for ownership, membership, binding, or grants are transitional only. New work must
prefer explicit authority services and lifecycle-rich records.

Known unresolved gaps after the Avatar provisioning service slice:

- `group_avatar_memberships` does not exist yet, so no constraints were added.
- `avatar_agent_bindings.agent_id` and `avatar_individual_bindings.individual_id` remain existing
  cross-DB integer references. They are legacy compatibility paths, not approved patterns for new
  references.
- `avatars.client_id` remains a legacy Avatar-to-Member compatibility column. New ownership,
  authorization, and canonical subject binding must use `AvatarAssignment` plus the surface binding
  table, not `avatars.client_id`.
- `avatars.avatar_status_id` remains legacy lifecycle compatibility state.
- Historical avatar DB posts remain a legacy UGC violation.
- `persona_assignments` already has unique `public_id`, non-null assignment columns, and active pair
  uniqueness. It still lacks a DB check for `revoked_at >= assigned_at`; this is an app_zenith
  follow-up candidate, not part of the Avatar DB slice.
- `persona_memberships` already has reference-table role/state shape and active primary uniqueness,
  but its temporal and revoke-reason constraints need a dedicated app_zenith review before changes.

`AvatarProvisioning::Create` is the canonical Avatar creation entry point for new Avatar graphs. It
creates Avatar, Handle, the surface binding, and initial owner `AvatarAssignment` in one
transaction. `Base::App::AvatarsController#create` and `BaseSelectorBootstrapAuthority` must remain
service callers and must not write Avatar authority or lifecycle tables directly.

`Avatar.create_with_owner` is deprecated compatibility API only. It must delegate to
`AvatarProvisioning::Create`, is a removal candidate, and must not independently write ownership,
binding, Handle, or assignment rows. `avatars.client_id` is migration compatibility only; authority
comes from binding plus assignment. The next backfill-oriented slice must begin with a read-only
conflict inventory before any historical row mutation. A separate `dry_run` mode or preview API is
not required; the inventory is the non-mutating audit boundary.

## Related

- `adr/umaxica-v1-core-resource-architecture.md`
- `adr/cross-db-reference-policy.md`
- `docs/architecture/umaxica-v1-architecture-lock.md`
