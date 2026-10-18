# Prefer Declarative Database Constraints for Integrity and Cardinality

## Status

Accepted (2026-10-18)

This ADR records a design principle only. It does not change any schema, limit value, callback,
trigger, or runtime behavior.

## Context

Rails model validations run only on specific ActiveRecord paths. `insert_all`, `update_all`,
`delete_all`, direct SQL, and concurrent writers that each pass validation before either commits all
bypass or race them. `adr/database-trigger-usage-boundary.md` records how this repository's earlier
attempt to enforce per-principal credential count limits (emails, passkeys, telephones, secrets,
TOTP) produced trigger functions that were never attached and later decayed against renamed tables.
None of those limits was ever enforced by the database.

`adr/database-consistency-repair-plan.md` tracks confirmed mismatches between model validations and
schema contracts. Those findings show that integrity conditions held only in Ruby drift from the
schema over time.

Per-owner registration limits remain a real requirement. For example, signed-in Passkey registration
and app Secret issuance each carry an owner-scoped upper bound
(`adr/app-secret-issuance-count-policy.md` records `A <= 20` for app Secrets). The repository has
not had a general rule for how such bounds, or other integrity conditions that validations cannot
guarantee, should be enforced.

## Decision

### Principle: prefer declarative database constraints

When a data integrity condition cannot be guaranteed by Rails model validation alone, the guarantee
is placed in PostgreSQL declarative constraints. Select whichever declarative mechanism fits the
requirement, considering them in this order:

1. Standard declarative constraints that apply directly: `NOT NULL`, `CHECK`, `UNIQUE`, and
   `FOREIGN KEY`.
2. Composite `UNIQUE` constraints across several columns.
3. Partial unique indexes (`CREATE UNIQUE INDEX ... WHERE <predicate>`).
4. Unique expression indexes (`CREATE UNIQUE INDEX ... ((<expression>))`), when needed.

This is a selection principle, not a strict ranking: choose the simplest mechanism that expresses
the requirement exactly.

The distinction between a `UNIQUE` constraint and a unique index matters:

- A `UNIQUE` constraint is a table constraint recorded in `pg_constraint`. PostgreSQL implements it
  with an automatically created unique B-tree index. It can be declared `DEFERRABLE`, can be named
  in `ON CONFLICT ON CONSTRAINT`, can be the target of a `FOREIGN KEY`, and covers plain columns
  only.
- A unique index created with `CREATE UNIQUE INDEX` is an index, not a constraint. It enforces the
  same uniqueness for the rows it covers, and it alone can carry a `WHERE` predicate (partial) or
  index expressions. It cannot be deferred or named in `ON CONFLICT ON CONSTRAINT`. A plain-column,
  non-partial unique index can still be a `FOREIGN KEY` target; a partial or expression index
  cannot. A partial unique index serves as an `ON CONFLICT` arbiter only when the statement's
  conflict target repeats a matching predicate.
- Both treat `NULL` values as distinct by default. `NULLS NOT DISTINCT` (PostgreSQL 15+) changes
  that for either form.

### Cardinality constraints: finite slots

For data with a per-owner registration upper bound, the finite-slot design is the preferred
candidate. A maximum of N rows per owner can be expressed as:

- `registration_slot NOT NULL`
- `CHECK (registration_slot BETWEEN 1 AND N)`
- `UNIQUE (owner_id, registration_slot)`

At most N distinct slot values exist and each may appear once per owner, so the database structure
alone bounds each owner at N rows, without a trigger that counts rows.

When revoked or deleted rows must be retained, consider a partial unique index such as
`UNIQUE (owner_id, registration_slot) WHERE revoked_at IS NULL`, so only live rows occupy slots.

The exact schema depends on each feature's requirements: whether history rows are kept, its state
transitions, slot reuse, and ownership changes. Each feature settles its concrete definition in its
own design. Passkeys (for example, at most 10) and Secrets (for example, at most 20) are expected
use cases; this ADR does not change any current limit value or fix any table's schema.

### Trigger and callback policy

For registration-count control, and for integrity guarantees that declarative constraints can
express, the following are not adopted in new work:

- PostgreSQL triggers that count rows and reject writes;
- integrity guarantees that depend on Rails callbacks such as `before_create` or `around_create`;
- designs where Rails model validation is the final integrity guarantee.

This is not a general prohibition of triggers or callbacks. A requirement that declarative
constraints cannot express is evaluated individually for alternatives, concurrency safety, and
necessity, under `adr/database-trigger-usage-boundary.md` where a trigger is proposed. Auditing,
notification, lifecycle processing, and other functions outside this decision are not prohibited by
it.

### Application responsibilities

Rails model validations remain in use. Their role is primarily a pre-check that gives users
understandable errors; the final integrity guarantee belongs to PostgreSQL.

Finite-slot assignment is performed, where needed, by an explicit Service or Operation. Concurrent
registrations that conflict must be safely rejected by the database constraint. The locking, retry,
and error translation needed for that are defined in each implementation design.

## Rationale

- Data integrity does not depend on any particular Rails execution path.
- PostgreSQL's uniqueness enforcement and its concurrency control for conflicting inserts are used
  instead of reimplementing them.
- Dependence on custom trigger and callback logic is reduced.
- Invariants can be read from the schema (`structure.sql`) rather than reconstructed from code.
- A unique-index check has more predictable cost and concurrent behavior than counting rows on each
  write. A counting check needs explicit locking to be correct under concurrency, because PostgreSQL
  triggers run synchronously inside the writing transaction but cannot see rows that a concurrent
  transaction has not yet committed.
- Maintainability, verifiability, and diagnosability during incidents improve: a violation names the
  constraint that rejected it.

## Consequences

- New integrity and cardinality requirements are designed first as declarative constraints; a design
  that falls back to a trigger or callback states why declarative constraints cannot express the
  requirement.
- Features with per-owner limits need a slot-assignment step and a defined response to slot
  exhaustion and concurrent conflicts.
- Validations duplicating a database constraint stay as user-facing pre-checks; their presence is
  not evidence that the invariant holds.

## Tradeoffs and Limitations

- `UNIQUE` alone cannot bound the number of rows in an arbitrary group; the bound comes from
  combining it with a finite `CHECK` domain.
- The finite-slot approach requires slot-number assignment logic.
- Each additional unique index carries maintenance cost on writes, in storage, and in WAL volume.
- A partial unique index requires careful design of the states in its predicate and the transitions
  between them; a row that leaves the predicate frees its slot.
- Not every business rule can be expressed as a declarative constraint.
- Migrating existing data and removing existing callbacks are done separately, after their safety is
  confirmed.

## Scope and Non-Goals

Accepted here: the design principle for data integrity guarantees above.

Not decided here, and left to later design and implementation:

- concrete column additions on individual tables;
- any change to actual Passkey or Secret registration limits;
- the concrete slot-assignment algorithm;
- immediate removal of existing callbacks or triggers;
- data migration procedures;
- Chronicle audit recording;
- deletion, revocation, and retention-period details of individual features.

## Relationship to Existing ADRs

- `adr/database-trigger-usage-boundary.md` — remains in force. This ADR narrows it in one respect:
  row-counting triggers for registration limits are not adopted, and the per-principal count limits
  the five orphaned functions targeted are to be reconsidered as declarative constraints when they
  are taken up. Its approved triggers (Unified Enforcement freeze, Avatar ownership and transfer
  integrity including the transfer-detail cardinality triggers, the Avatar cutover barrier, and the
  ORG Telephone and setting Preference `public_id` immutability exceptions) enforce cross-table or
  OLD/NEW conditions that declarative constraints cannot express and are unaffected.
- `adr/app-secret-issuance-count-policy.md` — remains in force, including its `A <= 20` and
  `A + R <= 20` contract and the Client writer lock. Reservations (`R`) are not rows that a slot
  constraint covers, so this ADR does not replace that mechanism; whether the active-Secret bound
  additionally adopts finite slots is a later design decision.
- `adr/database-consistency-repair-plan.md` — complementary. Its validation and schema alignment
  repairs proceed unchanged; this ADR states where the final guarantee lives when they disagree.
- `adr/unified-enforcement.md` — unaffected.
