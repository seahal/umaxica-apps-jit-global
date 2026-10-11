# Acme Account / Organization Resource Boundary

Status: Superseded on 2026-09-17 by
[`adr/surface-account-collective-model-naming.md`](surface-account-collective-model-naming.md) and
[`docs/architecture/persona-organization-authority.md`](../docs/architecture/persona-organization-authority.md).

## Scope of this record

This file was an earlier proposed resource-boundary design. Its proposed shared Account / Collective
vocabulary, Identity-owned resource interpretation, title migration, and bootstrap expansion are not
the current authority contract. The current repository must not use this record to choose an owner,
grant a role, infer a cross-surface relation, or introduce a shared table.

## Current references

- `Persona` and `Organization` are Ruby interfaces only; concrete resources, principals, tables,
  policies, and connections remain surface-local.
- `ClientPersona`, `Individual`, and `Agent` are the Persona implementations; `Enterprise`,
  `Company`, and `Bureau` are the Organization implementations.
- `OperatorOrganization` is a legacy org-principal model, not the common Organization interface.
- Existing bootstrap and public route behavior is compatibility evidence. It does not prove the
  adopted ownership or RBAC model and must not be used as an authorization fallback after cutover.
- The current authority schema, phase gates, and unresolved migration conditions are maintained in
  `docs/architecture/persona-organization-authority.md` and `conflict.md`.

Git history preserves the earlier proposal; this current record intentionally does not retain its
obsolete alternatives as competing implementation guidance.
