# Persona and Organization Interface Naming

**Status:** Accepted, amended 2026-09-17

## Context

The three user-facing surfaces have independent authority databases and independent concrete
resource models. A shared Ruby protocol is useful, but a shared Active Record model, table, STI
hierarchy, or polymorphic authority relation would blur the `app`, `com`, and `org` trust
boundaries.

The runtime principals remain `Client`, `Visitor`, and `Operator`. The RP/IdP binding records
(`ClientIdentity`, `VisitorIdentity`, and `OperatorIdentity`) are not RBAC principals or resource
owners.

## Decision

`Persona` and `Organization` are Ruby interface concerns only. The concrete implementations and
physical tables are surface-local:

| Surface | Runtime principal | Persona implementation | Persona table | Organization implementation | Organization table |
| ------- | ----------------- | ---------------------- | ------------- | --------------------------- | ------------------ |
| `app`   | `Client`          | `ClientPersona`        | `personas`    | `Enterprise`                | `enterprises`      |
| `com`   | `Visitor`         | `Individual`           | `individuals` | `Company`                   | `companies`        |
| `org`   | `Operator`        | `Agent`                | `agents`      | `Bureau`                    | `bureaus`          |

The legacy org-principal `Organization` concrete model is represented by `OperatorOrganization`,
mapped explicitly to the existing `organizations` table. It is not the new Organization interface
and is not an authority resource.

No compatibility constants such as `Persona = ClientPersona` or
`Organization = OperatorOrganization` are provided. Existing persisted column names, protocol field
names, URLs, and unrelated RP-account names remain unchanged unless a later migration explicitly
adopts a compatible wire transition.

## Authority boundary

Ownership, administration, delegation, usage, view, and ownership-transfer state are stored in
surface-local concrete tables. Their principal foreign keys are `client_id`, `visitor_id`, or
`operator_id`; an RP binding ID is never substituted for a runtime principal ID. There is no shared
authority table, `resource_type`/`resource_id` pair, STI authority hierarchy, or cross-surface
foreign key.

Each resource has at most one ownership row. Explicit grants are independent rows and are not
materialized automatically for owners. The current implementation uses one surface-local principal
lock row per principal to serialize quota-affecting authority writes because the legacy principal
and RP abstract bases have separate connection specifications even when they point at the same
physical database. The lock row is a synchronization primitive, not an authorization grant.

## Consequences

- Model and association references must use explicit concrete class names after the rename.
- GlobalID, policy dispatch, fixtures, serializers, and persisted class-name references must be
  reviewed as part of any future rename.
- A naming migration does not switch authorization from the existing assignment/membership graph.
  The old path remains transitional until a validated owner inventory, connection proof, policy
  cutover, and rollback plan are complete.
- Avatar behavior and Avatar authority remain outside this decision.

## Related

- `docs/architecture/persona-organization-authority.md`
- `docs/architecture/database-authority-placement.md`
- `adr/umaxica-v1-core-resource-architecture.md`
- `adr/authority-lifecycle-table-policy.md`
