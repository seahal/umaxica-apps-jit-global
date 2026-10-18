# ADR: Surface-local Authority Decomposition

## Status

Accepted, amended 2026-09-18.

This amendment replaces the former concrete `Persona`/`Organization` and retired `Account` concern
assumptions in this record. The current naming and authority decisions are defined by
[`adr/surface-account-collective-model-naming.md`](surface-account-collective-model-naming.md) and
[`docs/architecture/persona-organization-authority.md`](../docs/architecture/persona-organization-authority.md).

## Context

The `app`, `com`, and `org` surfaces are independent trust boundaries with independent zenith
databases. `Client`, `Visitor`, and `Operator` are their runtime principals. `Persona` and
`Organization` are common Ruby interfaces only; they are not shared Active Record models, tables,
STI roots, or polymorphic authority relations.

The `Member`, `ClientMembership`, and legacy organization rows remain mixed transitional or
operational data. Their current storage does not prove ownership or RBAC authority. Moving those
models wholesale would either promote compatibility state into authority or cross a surface boundary
without a verified data mapping.

## Decision

1. Keep the six adopted resource implementations and their authority relations surface-local:
   `ClientPersona`/`Enterprise` for `app`, `Individual`/`Company` for `com`, and `Agent`/`Bureau`
   for `org`. Their authority tables remain in the matching `*_zenith` database.
2. Keep `Persona` and `Organization` as behavior-only interface concerns. Do not introduce a shared
   concrete base, common table, STI hierarchy, polymorphic authority relation, or cross-surface
   foreign key.
3. Treat `Member` and `ClientMembership` as transitional app-surface models. `Member` remains an
   Avatar/legacy bridge and does not include the retired `Account` concern. `ClientMembership` is a
   membership/bridge relation whose `workspace_id` meaning is not authority ownership.
4. Treat `OperatorOrganization` as the renamed concrete legacy org-principal model mapped to the
   existing `organizations` table. It is not the common `Organization` interface and is not the
   adopted `Bureau` authority resource.
5. Keep runtime actors, credentials, lifecycle state, session state, OIDC connections, and Avatar
   bridge state in their existing surface-local boundaries. Decompose them by responsibility before
   any placement migration.
6. Derive any future owner backfill only from a documented, verified source path. Missing,
   ambiguous, cross-surface, or ineligible owner data blocks the migration; no first-row selection,
   membership promotion, or silent skip is permitted.

## Consequences

### Positive

- Authority state remains isolated by surface and principal type.
- Compatibility and operational rows can be retired or migrated independently from RBAC.
- The current concrete naming is explicit in models, fixtures, policies, and documentation.
- Future migrations can be validated table by table without creating a permanent dual authority
  path.

### Negative

- `Member`, `ClientMembership`, and `OperatorOrganization` remain transitional until their
  responsibility-level mappings are separately accepted.
- Runtime authorization cutover and owner backfill require additional connection, data, and
  concurrency evidence.
- Some legacy protocol vocabulary remains in unrelated assignment, membership, and RP-account
  projection classes where changing it would alter external or persisted contracts.

## Alternatives Considered

1. Move `Member`, `ClientMembership`, or `OperatorOrganization` wholesale into the adopted authority
   model. Rejected because their current rows mix bridge, operational, hierarchy, and lifecycle
   responsibilities that are not equivalent to ownership or RBAC.
2. Treat `Member` membership or an operator reference as resource ownership. Rejected because
   membership and legacy operator linkage do not establish the adopted single-owner contract.
3. Restore `Persona = ClientPersona` or `Organization = OperatorOrganization` aliases. Rejected
   because aliases hide the interface/concrete boundary and make reflection, policy dispatch, and
   persisted class-name handling unsafe.
4. Create a shared authority table or polymorphic principal reference. Rejected because it would
   collapse independent trust boundaries and weaken surface-local foreign-key guarantees.

## Non-goals

- No table movement, owner backfill, authorization cutover, or destructive migration is authorized
  by this ADR.
- No Avatar relocation or Avatar RBAC change.
- No organization hierarchy, Position, Unit, Appointment, or Persona–Organization membership
  redesign.
- No ticket, session, ceremony, OIDC, preference, or route migration.

## References

- [Persona and Organization Interface Naming](surface-account-collective-model-naming.md)
- [Persona and Organization Authority](../docs/architecture/persona-organization-authority.md)
- [Principal / Zenith Membership and Organization Placement](../docs/architecture/principal-zenith-membership-organization-placement.md)
- [Database Authority Placement](../docs/architecture/database-authority-placement.md)
