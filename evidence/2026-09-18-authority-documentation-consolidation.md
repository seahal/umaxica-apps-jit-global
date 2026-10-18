# Authority Documentation Consolidation

Date: 2026-09-18 Branch: `feature` Baseline HEAD before this documentation slice: `37a0a130a`

## Checks performed

- Read `adr/surface-account-collective-model-naming.md`,
  `docs/architecture/persona-organization-authority.md`, and
  `docs/architecture/database-authority-placement.md` together with the current model mappings.
- Searched the scoped authority documents for obsolete normative claims about a concrete shared
  `Persona`/`Organization`, Identity-owned authority, or RP binding records being RBAC principals.
- Updated `docs/architecture/database-authority-placement.md` to identify the adopted concrete
  mapping, legacy `OperatorOrganization`, surface-local `*_zenith` boundaries, and phase gates.
- Replaced the obsolete proposed design in `adr/acme-account-organization-resource-boundary.md` with
  a concise superseded record that points to the current ADR and implementation reference.

## Result

The current documentation set now separates the adopted interface/schema boundary from the
unexecuted migration and authorization cutover. No route, model behavior, migration, or runtime
authorization path was changed by this documentation slice.
