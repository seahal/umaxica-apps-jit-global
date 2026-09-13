# Restore Rails Primary Database Implementation Notes

## Context

- Original plan/spec: current-session request to retire the dedicated `platform` database.
- Related decisions/docs/plans: `adr/global-regional-database-ownership.md`,
  `docs/architecture/database-boundaries.md`, `docs/operations/db-workflow.md`,
  `docs/reference/feature-flags.md`
- Implementation date: 2026-09-09

## Decisions Made During Implementation

- Decision: replace the `platform` connection with Rails-standard `primary`, owning `db/migrate`
  and dumping to `db/structure.sql` (no custom `schema_dump`).
  - Why: nothing is deployed; Flipper is durable application-wide configuration, not a domain that
    needs a specially named database.
  - Alternatives considered: keep `schema_dump: platform_structure.sql` or `primary_structure.sql`.
    Rejected because Rails already dumps `:sql` primary schema to `db/structure.sql`.
  - Follow-up needed: none.

- Decision: keep `primary` writer-only, with Flipper `writing: :primary, reading: :primary`.
  - Why: flag changes must be visible immediately; DatabaseSelector still wraps GET in `:reading`.
  - Alternatives considered: add `primary_replica` for symmetry. Rejected.
  - Follow-up needed: none.

- Decision: do not add `connects_to` on `ApplicationRecord`.
  - Why: it remains `primary_abstract_class`; specialized bases already pin domain databases.
  - Follow-up needed: none.

- Decision: amend current architecture docs/ADR rather than add a new ADR.
  - Why: the ownership map already listed this database; only the name and role changed.
  - Follow-up needed: none.

## Deviations From Plan

- None.

## Review Notes

- Tests run: recorded in the session report after reconstruction.
- Tests not run: none intended at the time of writing this note.
- Documentation promotion needed: already applied to `adr/` and `docs/`.
