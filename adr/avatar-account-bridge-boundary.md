# Avatar / Persona Binding Boundary

Status: Deferred and excluded from the current Persona/Organization authority program (2026-09-17).

## Current boundary

`Avatar` is an existing SNS-facing domain boundary with its own database and lifecycle. The current
`AvatarPersonaBinding` table remains there, and its `persona_id` association resolves to the
concrete app model `ClientPersona`. This is a mechanical consequence of the concrete model rename;
it does not change Avatar behavior or grant authority.

`AvatarAssignment`, `AvatarMembership`, and `Member` remain separate existing boundaries. Their
authority, history, bootstrap, and cross-database behavior are not redesigned here. No duplicate
bridge table is added to `app_zenith`, and no cross-database foreign key is introduced.

## Explicit exclusion

This program does not implement Avatar functionality, Avatar RBAC, Avatar lifecycle changes,
organizational hierarchy changes, Position, Persona–Organization Membership/Appointment behavior, or
a new break-glass path. The current Avatar routes, policies, tables, and bootstrap behavior must
remain unchanged except for the mechanical `ClientPersona` class mapping required by the rename.

Do not infer Persona ownership, Organization authority, or a shared Account abstraction from the
legacy Avatar binding. The adopted surface-local authority contract is documented in
[`docs/architecture/persona-organization-authority.md`](../docs/architecture/persona-organization-authority.md).

## Future work gate

Any Avatar bridge or authority change requires a separate decision with a model/data inventory,
cross-database consistency analysis, migration plan, and security tests. This record intentionally
does not preserve the earlier bridge alternatives as current implementation guidance.

## Related

- [`adr/surface-account-collective-model-naming.md`](surface-account-collective-model-naming.md)
- [`docs/architecture/avatar-account-bridge.md`](../docs/architecture/avatar-account-bridge.md)
- [`docs/architecture/persona-organization-authority.md`](../docs/architecture/persona-organization-authority.md)
