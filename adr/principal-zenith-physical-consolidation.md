# Principal and Zenith Physical Consolidation

## Status

Accepted on 2026-06-30.

> **Partially superseded (2026-09-08) by `adr/global-regional-database-ownership.md`:** the
> consolidation of `*_principal` migration history into `*_zenith` and the semantic
> `*PrincipalRecord` base classes stand. The claim that the reserved empty `*_principal` databases
> "are available for a future regional-ready application-data role" is retired: `*_zenith` is Global
> canonical authority, and regional-ready application data belongs in the future Regional
> repository's own application database, not in a `*_principal` connection key in this repository.
> The Phase 1.5 investigation also found the `db/{app,com,org}_principal_reserved_migrate`
> directories and `*_principal` connection keys named below were never actually created.

## Context

The repository historically separated each surface into `*_principal` and `*_zenith` physical
databases. That reflected an older identity/account split where principal-side identity data and
RP/account projections were treated as separate physical authorities.

The current authority direction treats Identity, Account, and Organization as the same global
authority family for placement purposes. The old Acme/Sign-style boundary no longer justifies a
separate physical database between principal and zenith for these records.

The `*_zenith` databases also contain read-only docs/help/news content. That content placement is
settled separately by `adr/read-only-content-surfaces-in-rails.md` and must not be treated as
authority data merely because it shares the zenith physical database.

## Decision

For each surface, merge the existing principal migration history into the matching zenith database:

- `app_principals_migrate` is applied by `app_zenith`.
- `org_principals_migrate` is applied by `org_zenith`.
- `com_principals_migrate` is applied by `com_zenith`.

The semantic principal abstract bases remain as compatibility and domain-language seams:

- `AppPrincipalRecord` connects to `app_zenith`.
- `OrgPrincipalRecord` connects to `org_zenith`.
- `ComPrincipalRecord` connects to `com_zenith`.

The physical `*_principal` connection keys remain configured, but their migration paths are empty
reserved directories:

- `db/app_principal_reserved_migrate`
- `db/org_principal_reserved_migrate`
- `db/com_principal_reserved_migrate`

These reserved databases are intentionally empty after this consolidation. They are available for a
future regional-ready application-data role, but not for new global authority data.

## Consequences

- Principal and zenith models for the same surface can now use database-level relationships inside
  one physical database when the model semantics allow it.
- Existing semantic base classes can keep code readable while the physical storage is consolidated.
- Migration version collisions between the merged histories must be resolved before the combined
  paths are applied.
- Future regional data must be placed deliberately into the reserved principal databases only after
  a separate placement decision.
- Read-only content in `*_zenith` remains content storage and is not reclassified as authority data.

## Non-Goals

- This is not a table rename.
- This is not a connection-key removal.
- This does not relocate Avatar data.
- This does not move ticket, token, ceremony, session, signal, setting, occurrence, chronicle,
  queue, cache, storage, or search data.
