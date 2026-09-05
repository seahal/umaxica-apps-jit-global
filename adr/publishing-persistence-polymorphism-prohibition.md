# ADR: Prohibit Persistence Polymorphism In Publishing

## Status

Accepted (2026-09-03)

## Date

2026-09-03

## Context

`adr/publishing-db-content-authority.md` made the publishing database the sole
content authority for the twelve audience × surface interfaces. Media placements
were stored in `publishing_media_usages` with mutually exclusive nullable
`entry_revision_id` and `entry_version_id` columns. That exclusive-arc design is
persistence-level polymorphism: a row's owner, foreign-key graph, and lifecycle
depended on which column was populated.

The twelve public interfaces remain distinct at routing and Edge naming. They
do not require twelve physical CMS databases or regional publishing databases.

## Decision

1. Publishing data is global. All twelve interfaces use the single `publishing`
   database via `PublishingRecord`.
2. Persistence-layer polymorphism is prohibited for CMS tables. Rails
   polymorphic associations, STI, `*_type`+`*_id` ownership, exclusive-arc
   owner unions, EAV-as-entity-type, and dynamic table/model selection are
   forbidden. Ordinary classification such as taxonomy `kind` remains allowed
   when ownership and lifecycle stay homogeneous.
3. Media placements are two relations: `publishing_revision_media_usages` and
   `publishing_version_media_usages`. A fresh migrate creates those tables
   directly. There is no compatibility copy from `publishing_media_usages`
   because this correction is pre-deployment.
4. Prefer Rails migration DSL. PostgreSQL triggers for immutability and
   deferred snapshot completeness are allowed only when the DSL cannot express
   the invariant, and must be documented and tested.
5. Shared public-content HTTP behaviour lives in Rails controller concerns.
   The twelve concrete controllers stay explicit and thin. `included do` is an
   exception that must be justified.

This ADR does not change region semantics, Edge CMS consumption, or taxonomy
BCNF.

## Consequences

- `Publishing::MediaUsage` is removed.
- Promotion and restore copy media between the two owner-explicit tables.
- Architecture tests reject a return of exclusive-arc media ownership.

## Related

- `docs/architecture/publishing-persistence.md`
- `adr/publishing-db-content-authority.md`
