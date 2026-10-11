# Collective Hierarchy Model

Status: Superseded on 2026-09-17 by
[`adr/surface-account-collective-model-naming.md`](surface-account-collective-model-naming.md) and
[`docs/architecture/persona-organization-authority.md`](../docs/architecture/persona-organization-authority.md).

## Scope of this record

This ADR described an earlier shared hierarchy proposal using `Collective` as the common domain
model. That proposal is no longer the authority contract. It must not be used to create a shared
Persona/Organization table, a shared ownership tree, cross-surface membership, or an implicit
Identity-to-resource ownership relation.

## Current contract

`Persona` and `Organization` are Ruby interfaces only. Their concrete resources, principals,
ownership rows, grants, transfer requests, lifecycle state, policies, and database connections are
surface-local. Existing membership and hierarchy code remains compatibility evidence until an
explicit, validated migration; it is not a fallback authority source for the new relation tables.

The adopted mappings and phase gates are maintained in the current authority implementation
reference. Avatar hierarchy, Position, Unit, and Persona–Organization membership behavior are
outside the present foundation slice.

Git history preserves the earlier hierarchy proposal. This current record intentionally does not
retain its rejected alternatives as competing implementation guidance.
