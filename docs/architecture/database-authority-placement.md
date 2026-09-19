# Database Authority Placement

> **Global / Regional ownership settled (2026-09-08):** `adr/global-regional-database-ownership.md`
> is the normative decision. `app_zenith` / `org_zenith` / `com_zenith` are **Global-only**
> databases and their Persona / Identity / Organization / principal graph is Global canonical
> authority (this resolves the Phase 1.5 `M1` question). The "regional-ready `principal`" role
> described below is **retired**: regional-ready application data belongs in the Regional
> repository's own new application database, not in a `*_principal` connection key here. The
> sections below are retained as the current-state placement model; read them with the ownership
> decision as the authority.

## Purpose

This document separates current storage naming from target authority placement.

## Scope

It describes the intended authority placement for the current global surfaces and their database
boundaries. `auth`, `base`, and `info` are global surfaces in this phase.

## Current adopted authority contract

The current authority contract is surface-local and concrete. `app_zenith`, `com_zenith`, and
`org_zenith` remain independent global authority databases for the `app`, `com`, and `org` trust
boundaries. `Client`, `Visitor`, and `Operator` are the runtime principals. `Persona` and
`Organization` are Ruby interface concerns only; they are not shared Active Record models or tables.

The adopted concrete resource mapping is:

| Surface | Persona resource             | Organization resource        | Principal  |
| ------- | ---------------------------- | ---------------------------- | ---------- |
| `app`   | `ClientPersona` (`personas`) | `Enterprise` (`enterprises`) | `Client`   |
| `com`   | `Individual` (`individuals`) | `Company` (`companies`)      | `Visitor`  |
| `org`   | `Agent` (`agents`)           | `Bureau` (`bureaus`)         | `Operator` |

`OperatorOrganization` is the legacy concrete org-principal model mapped to the existing
`organizations` table. It is not the common `Organization` interface and is not one of the new
organization authority resources. `ClientIdentity`, `VisitorIdentity`, and `OperatorIdentity` are
RP/IdP binding records, not RBAC principals or owners.

The surface-local ownership, grant, and transfer tables are authored in the matching `*_zenith`
migration paths, but the migrations are phase-gated: they do not by themselves backfill owners,
switch authorization, or retire the existing assignment/membership graph. The current implementation
reference and enablement gates are in
[`persona-organization-authority.md`](persona-organization-authority.md).

## Current Storage Names

The repository currently uses these storage and connection boundaries:

- `principal`
- `zenith`
- `avatar`

The `principal` connection keys are retained in this phase and are not renamed. After the 2026-06-30
physical consolidation, the semantic principal abstract bases connect to the matching `*_zenith`
databases, and the physical `*_principal` migration paths are empty reserved paths.

## Authority Placement

The matching `*_zenith` database is the canonical store for global authority data for its surface's
principal, identity, RP binding, and adopted authority relations.

The retained `principal` connection keys are not canonical authority stores. They remain available
only for explicitly approved non-authority or future regional placement decisions.

This is a database placement migration, not a database rename.

## Retained Principal Storage Role

The `principal` database name is retained for compatibility and is not renamed in this phase.

`principal` is currently empty by design after the physical consolidation. New placement decisions
must not infer Principal authority ownership from the name `principal`.

Regional-ready application data belongs in the future Regional repository's own application
database. This repository must not add it to the retained `principal` connection keys without a new
placement decision.

This is a semantic redefinition of the retained storage role, not a database rename. It does not
restore `principal` as the canonical store for Principal / Identity / Persona / Organization
authority data.

## Avatar Boundary

Avatar remains a separate actor-authority boundary in the current code and in this phase.

`Avatar`, `AvatarAssignment`, `AvatarMembership`, `AvatarOwnershipPeriod`, and
`AvatarPersonaBinding` remain in the avatar database unless a later ADR explicitly moves them.
`app_zenith` is not the current target for `AvatarPersonaBinding`.

## Current Implementation Facts

- `Client`, `Visitor`, and `Operator` inherit from semantic principal base classes, but those base
  classes now connect to `app_zenith`, `com_zenith`, and `org_zenith`.
- `Client`, `Visitor`, and `Operator` still own credentials, sessions, lifecycle columns, and
  recovery/contact state.
- `app_zenith`, `com_zenith`, and `org_zenith` each apply both their historical principal migration
  path and their historical zenith migration path.
- `app_principal`, `com_principal`, and `org_principal` retain connection keys with reserved empty
  migration paths only.
- The zenith-side Persona and identity-binding graph already exists in `app_zenith`, `org_zenith`,
  and `com_zenith`.
- `ClientPersona`, `ClientIdentity`, `Agent`, `OperatorIdentity`, `Individual`, `VisitorIdentity`,
  and their assignment/membership-style graph belong to the zenith-side account/identity-binding
  story. The assignment/membership graph is transitional and is not the adopted RBAC authority
  source.
- `ClientAccount`, `OperatorAccount`, and `VisitorAccount` are already zenith-side RP account
  projection records.
- `Member` and `ClientMembership` still inherit from `AppPrincipalRecord`, which now connects to
  `app_zenith`.
- `OperatorOrganization` inherits from `OrgPrincipalRecord` and remains a legacy org-principal model
  mapped to `org_zenith`; it is not the common `Organization` interface.
- The new authority schema is explicit and surface-local, but runtime authorization cutover and
  owner backfill remain phase-gated by `docs/architecture/persona-organization-authority.md` and
  `conflict.md`.
- `Avatar`, `AvatarAssignment`, `AvatarMembership`, `AvatarOwnershipPeriod`, and
  `AvatarPersonaBinding` remain in the standalone avatar database.
- `Avatar` still points to member through `client_id`.
- Avatar remains a separate actor-authority boundary in this phase.

Relevant file paths:

- `app/models/client.rb`
- `app/models/visitor.rb`
- `app/models/operator.rb`
- `app/models/member.rb`
- `app/models/client_membership.rb`
- `app/models/operator_organization.rb`
- `app/models/concerns/organization.rb`
- `app/models/concerns/persona.rb`
- `app/models/client_identity.rb`
- `app/models/operator_identity.rb`
- `app/models/visitor_identity.rb`
- `app/models/client_account.rb`
- `app/models/operator_account.rb`
- `app/models/visitor_account.rb`
- `app/models/avatar.rb`
- `app/models/avatar_assignment.rb`
- `app/models/avatar_membership.rb`
- `app/models/avatar_ownership_period.rb`
- `app/models/avatar_persona_binding.rb`
- `docs/architecture/avatar-social-graph.md`

## Explicit Exclusions

- No database renames.
- No table renames.
- No connection-key removals.
- No preference migration work.
- No token/session/ceremony/logout/OAuth transaction migration work.
- No Avatar database migration work in this phase.

## Deferred placement questions

- `Member` vs `ClientMembership` vs `OperatorOrganization` remains the weakest legacy boundary and
  must not be used to infer new ownership.
- `Client`, `Visitor`, and `Operator` runtime actor rows still carry credentials, contact, recovery,
  and lifecycle state. Those rows are not resolved by the retained principal role.
- `ClientOidcConnection`, `OperatorOidcConnection`, and `VisitorOidcConnection` remain unrelated RP
  binding candidates; they are not settled as authority principals here.
- `representing_organization_id` on `Avatar` remains semantically unclear.
- `AvatarAssignment`, `AvatarMembership`, `AvatarOwnershipPeriod`, and `AvatarPersonaBinding` remain
  unresolved beyond the current "stay in avatar" phase.

## Design Rules

- New regional-ready models are out of scope for this repository. They belong in the future Regional
  repository after an explicit placement decision and must not depend on `principal` as a canonical
  authority boundary.
- Do not place new global authority models in `principal` merely because the retained database name
  is `principal`. Authority ownership must be decided from the semantic role of the data, not from
  the database name.
- Do not use the retained `principal` role to reclassify Avatar authority, ticket/session/ceremony
  data, preference/settings data, or OIDC transaction rows.

## Future Implementation Sequence

1. Keep this placement document as the contract.
2. Keep the reserved `*_principal` migration paths empty; the future Regional repository owns any
   later regional-ready placement decision.
3. Audit identity/Persona/organization projections in `zenith`.
4. Audit `Member` / `ClientMembership` / `OperatorOrganization` placement.
5. Only after that, separately revisit Avatar through a new ADR if needed.
6. Do not mix Avatar relocation into this placement migration.
