# Chronicle Tamper Resistance

## Status

Accepted (2026-09-26). The owner delegated the choice of method to the recommendation below. The
decision is made; the implementation is not, so OQ-AUD-001 stays a production blocker until it is
built and verified.

## Context

OQ-AUD-001 (`docs/vendor/identity/15_audit-log-integrity-requirement.md`) requires critical audit
records to be append-only or equivalently tamper-evident or tamper-resistant, with UPDATE and DELETE
prevented or detected at the database level; application sanitization is not enough, and ChainSeal
is a candidate only. Today the chronicle database has no such protection for `chronicles`,
`enforcement_events`, or `account_access_events`, and production connects to every database with
a single user (`NEON_PGUSER`) that owns the tables and runs the migrations.

Application writes to these tables are inserts, except two: `ChronicleResultWriter` updates
`chronicles.result` and `chronicles.changeset` on an intent row, and `ChronicleInvalidator` updates
`chronicles.result`.

## Decision

Protect the audit tables with database role privileges.

- The chronicle database's tables are owned by a migration role that only migrations use.
- The application connects with a separate runtime role that has `INSERT` on `chronicles`,
  `enforcement_events`, and `account_access_events`, `UPDATE` only on `chronicles (result,
  changeset, updated_at)`, `SELECT` as needed, and no `DELETE` and no other `UPDATE`.
- Retention deletion, once built, runs under its own purge role limited to deleting rows whose
  `erasable_at` has passed.
- A test proves the runtime role cannot UPDATE or DELETE a protected row through raw SQL.

## Rejected alternatives

- An append-only trigger. `adr/database-trigger-usage-boundary.md` (Accepted) forbids triggers for
  auditing and limits them to invariants spanning several rows or tables; and the table owner, which
  is also the runtime user today, can disable a trigger.
- A digest chain or ChainSeal alone. Either detects changes only if the anchor is outside the
  database administrator's reach (OQ-AUD-002, OQ-AUD-003, OQ-AUD-006); it remains a later hardening.

## Consequences

- Implementation needs infrastructure work outside this repository's code: separate migration and
  runtime database users for the chronicle database in every environment, and configuration that
  uses the runtime user for the application and the migration user for migrations. Then a migration
  applies the grants and revokes, and the test above verifies them.
- Column-level `UPDATE` cannot restrict which values `result` may take; the application still
  guards the intent-to-result transition.
- A database superuser can still alter rows. That residual risk is OQ-AUD-006 and is not removed by
  this decision.
