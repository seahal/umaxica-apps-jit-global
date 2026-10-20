# Cross-Database Write Paths Without Atomicity

Recorded 2026-10-20. Status: backlog, not started. Database refactoring required.

## Decision

On 2026-10-20 the user rejected the premise of the current design: an operation that writes to more
than one PostgreSQL database cannot be atomic, so any workflow that relies on parent and child rows
in different databases staying consistent is a design defect. It must be removed by restructuring
the databases, not by relying on application-level ordering or by tolerating the
`database_consistency` findings.

Configuration-file exclusions (`.database_consistency.yml`) are not an acceptable resolution.

## Known instance

- `Visitor` (`com_zenith`) `has_many :visitor_tokens` with `VisitorToken` in `op_base_com`. The
  checker cannot verify the association, and no foreign key or transaction spans the boundary.
- The matching `Client`/`ClientToken` (`app_zenith`/`op_base_app`) and `Operator`/`OperatorToken`
  (`org_zenith`/`op_base_org`) pairs have the same shape.
- The implementation itself is at fault, not only the association declaration: token issuance,
  revocation and actor deletion must be redesigned so no single operation depends on writes to both
  databases succeeding together.
- `plans/backlog/cross-database-model-associations-audit.md` lists the other cross-database
  associations (signal, zenith, chronicle, avatar, member). Each must be classified with the rule
  below.

- `database_consistency` also reports `ForeignKeyCascadeChecker fail Visitor visitor_tokens`:
  `Visitor` declares `dependent: :delete_all`, but no `ON DELETE CASCADE` foreign key can exist
  across `com_zenith` and `op_base_com`. On 2026-10-20 the other seven cascade mismatches were
  resolved by making the database cascade from parent to child; this one waits for the refactoring.

## Rule for the refactoring

For every pair of tables in different databases:

1. If one workflow must create, change, or delete rows on both sides together, the tables belong in
   the same database. Move them so a single transaction and a real foreign key cover the invariant.
2. If the sides are genuinely independent, remove the Active Record association and every write path
   that assumes both sides change together. Any remaining reference is an opaque identifier with an
   explicit, documented consistency model (for example an outbox), never an implied transaction.

## Out of scope until this is done

- The 2026-10-19 database_consistency fixes deliberately left `Visitor.visitor_tokens` untouched.
- No exclusion entry, association workaround, or validator is added in the meantime.

## Open questions

- Which write paths currently span `*_zenith` and `op_base_*` in one logical operation (sign-up,
  sign-in session issuance, withdrawal, deletion)?
- Does moving tokens next to principals conflict with the surface database boundaries in
  `docs/architecture/database-boundaries.md` and `adr/surface-database-connection-naming.md`? If so,
  those documents change in the same cycle.
