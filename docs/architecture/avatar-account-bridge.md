# Avatar / Persona Binding

This document records the current compatibility boundary only. Avatar functionality, Avatar RBAC,
Avatar lifecycle, organization hierarchy, Position, and Persona–Organization Membership/Appointment
behavior are excluded from the current Persona/Organization authority program.

## Current implementation facts

- `AvatarPersonaBinding` remains in the Avatar database.
- Its `persona_id` association resolves to `ClientPersona` after the concrete model rename.
- `AvatarAssignment` remains the existing Avatar role/authority boundary.
- `AvatarMembership` remains the existing temporal participation/history boundary.
- `Member` remains a legacy bridge.
- Existing app bootstrap behavior and idempotency are preserved.
- No duplicate `avatar_persona_bindings` table is added to `app_zenith`.
- No cross-database foreign key is introduced.

The `ClientPersona` class mapping is mechanical. The binding does not imply ownership, an
Administration/Delegation/Usage/View grant, Organization membership, or a shared authority table.
The new surface-local authority contract is maintained in
[`persona-organization-authority.md`](persona-organization-authority.md).

## Future-work gate

Do not add Avatar routes, RBAC, lifecycle transitions, hierarchy, Position, or new bridge behavior
as part of the authority foundation. A future Avatar change requires its own data inventory,
cross-database consistency analysis, migration plan, and regression tests.

The URL allocation for the existing human-facing Avatar handle is documented in
[`docs/reference/url-identifier-policy.md`](../reference/url-identifier-policy.md): `@` is a fixed
prefix and is not part of the stored handle. This document does not create a route or authorize new
Avatar functionality.

## Related

- [`adr/avatar-account-bridge-boundary.md`](../../adr/avatar-account-bridge-boundary.md)
- [`adr/surface-account-collective-model-naming.md`](../../adr/surface-account-collective-model-naming.md)
- [`docs/architecture/persona-organization-authority.md`](persona-organization-authority.md)
