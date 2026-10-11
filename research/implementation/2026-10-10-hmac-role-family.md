# Identifier HMAC Role-Family Reuse

## Context

- Original change: the APP, COM, and ORG identifier-HMAC migrations added restricted role
  adoption so an existing role is reused only when its authority, membership, configuration, and
  dependencies are safe.
- Related decisions: `docs/security/identifier-hmac-emergency-rotation.md` and the database
  reconstruction workflow in `docs/operations/db-workflow.md`.
- Implementation date: 2026-10-10.

## Decisions Made During Implementation

- Decision: treat the current writer database, its matching replica database, and numeric worker
  clones of either as one bounded role family when evaluating `pg_shdepend`.
  - Why: PostgreSQL roles are cluster-wide, while Rails test workers clone the writer and replica
    databases. Those clones retain the expected HMAC function owners and ACL dependencies. A
    cluster-wide zero-dependency requirement therefore rejected a valid test reconstruction.
  - Alternatives considered: drop every worker clone before migration; inspect only the current
    database; or accept any existing dependency. Dropping clones expands the operational reset
    scope, current-database-only inspection can miss active use, and accepting arbitrary
    dependencies weakens the privilege boundary. The bounded family preserves the guard while
    admitting the observed clone contract.
  - Follow-up needed: if test database clone naming changes, update the family canonicalization and
    rerun the clean migration reconstruction before relying on role reuse.

## Deviations From Plan

- Change: the role guard no longer requires zero dependencies across the entire PostgreSQL cluster;
  it still rejects shared dependencies and every dependency outside the inferred writer/replica
  family.
  - Why: the existing test fleet uses cluster-wide roles across parallel database clones.
  - Risk: a database with an unintended name matching the clone convention could be admitted to the
    family; the family remains limited to the current writer/replica names and numeric suffixes.
  - Follow-up: promote the family naming convention to current database workflow documentation if
    additional test fleet implementations adopt it.

## Review Notes

- Tests run: the pending test migration workflow, a repeat `db:migrate`, pending-migration check,
  targeted RuboCop, Ruby syntax checks, and `git diff --check`.
- Tests not run: no Minitest was added because this is environment construction and the repository
  requires the migration workflow itself as its verification.
- Schema-drift verification was run and exited 1 on the pre-existing modified/empty structure
  dumps; those files were not changed by this work.
