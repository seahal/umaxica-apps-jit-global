# Database Trigger Usage Boundary

## Status

Accepted (2026-07-26)

## Context

`adr/unified-enforcement.md` (successor to `adr/authentication-method-lock.md`) requires that a
permanently frozen credential cannot be deleted by any route. The routes that must be blocked
include ones that never reach Ruby:

- `RetentionPurgeJob` issues `delete_all` across roughly sixty model classes;
- the ceremony transaction purgers and the cross-database child purge issue `delete_all` directly;
- ad hoc operational SQL bypasses the application entirely.

**Correction (2026-07-27):** an earlier version of this ADR additionally cited "several credential
foreign keys cascade with `ON DELETE CASCADE`" as a route that never reaches Ruby. A subsequent
audit found this false: `db/app_zenith_structure.sql` contains six `ON DELETE CASCADE` constraints,
targeting `client_preferences`, `client_members` (twice), `client_withdrawal_flow_events`,
`user_clients`, and `legacy_replaced_clients` — none is a credential table. No credential table
anywhere in the repository has a cascading foreign key. This does not weaken the Decision below:
`delete_all` and direct SQL alone are sufficient to defeat a model callback and remain the
justification for the trigger.

An ActiveRecord `before_destroy` callback stops none of these. A CHECK constraint cannot help
either: the freeze state lives in a different table from the credential, and a CHECK constraint may
only reference columns of its own row.

That leaves a database trigger as the only mechanism that enforces the invariant regardless of how
the delete arrives.

This repository has no working triggers. It does, however, contain five orphaned trigger functions
(an earlier version of this ADR miscounted eight; corrected 2026-07-27), and their history is the
reason this ADR exists rather than a one-line note in the feature ADR.

`db/app_principals_migrate/20251218120010_enforce_user_identity_email_limit.rb` and its four
siblings each `CREATE OR REPLACE FUNCTION ... RETURNS trigger` and then stop. No `CREATE TRIGGER`
statement is ever issued, so the function is never invoked. The matching `down` method drops a
trigger that was never created. The functions were written to enforce per-principal credential count
limits — at most four emails, four passkeys, four telephones, ten secrets, two TOTP credentials —
and none of those limits has ever been enforced by the database.

The functions have since decayed further. They query `user_identity_emails`,
`user_identity_passkeys`, and `user_identity_one_time_passwords`, tables that were renamed to the
`client_*` family and no longer exist. Were a trigger attached to any of them today, it would raise
`undefined_table` on every insert.

Two failures compounded here: a migration that created half of a mechanism, and a rename that did
not know the other half existed. Both are invisible in `structure.sql`, which faithfully records the
dead functions without indicating that nothing calls them.

## Decision

Database triggers are permitted, narrowly, and only under the conditions below. Every condition
exists because of a specific way the orphaned functions failed.

### Permitted purpose

A trigger may only enforce a **data integrity invariant that the application cannot enforce**,
meaning both of the following hold:

- the invariant must survive `delete_all`, `update_all`, `ON DELETE CASCADE`, or direct SQL, so a
  model callback is insufficient; and
- the invariant spans more than one table or row, so a CHECK constraint is insufficient.

Triggers must not be used for business logic, derived columns, denormalization, auditing,
notification, or anything a validation can express. A trigger that merely duplicates a model
validation adds a second source of truth and is forbidden.

### The function and its trigger are created together

A migration that creates a trigger function must attach it in the same migration. A migration that
creates a function without a `CREATE TRIGGER` is incomplete and must not be merged. The `down`
method must drop exactly what `up` created, in the reverse order.

### Every trigger has a test that observes it firing

A trigger is only real if a test proves it. The test must exercise the trigger through a path that
bypasses ActiveRecord — raw SQL, `delete_all`, or a cascade — and assert the database raises. A test
that only exercises the model callback proves nothing about the trigger and does not satisfy this
requirement.

This is the condition that would have caught the orphaned functions immediately.

### Triggers are named, enumerated, and asserted

Every trigger is registered in a single test that asserts the set of triggers present in each
database matches the expected set exactly. Adding a trigger without registering it fails. So does
removing one. This makes the mechanism visible in a place a renaming migration will encounter.

### Table renames must account for triggers

Any migration renaming a table must check for triggers and functions referencing the old name and
update them in the same migration. The trigger inventory test above is the enforcement mechanism.

### Triggers raise, they do not silently correct

A trigger enforcing an invariant raises an exception with an explicit `ERRCODE`. It must never
rewrite `NEW`, swallow the operation, or return `NULL` to silently skip a row. Silent correction is
a fallback, forbidden by `.agents/harnesses/rules/generic/no-silent-fallback.mdc`, and doubly
dangerous at the database layer where it is invisible to the application.

### Scope is per database

Triggers live in the same database as the tables they read. A trigger must not attempt a
cross-database reference. Because the surface databases are independent, a trigger written for one
surface is duplicated deliberately per surface rather than shared.

## Consequences

- The permanent-freeze deletion invariant is enforceable against `delete_all`, cascades, and direct
  SQL. No other mechanism available in this repository achieves that.
- Trigger logic is invisible to a reader of the Ruby code. Each protected table carries a comment
  naming its trigger, and the model-layer guard remains in place so that the ordinary application
  path produces a proper validation error rather than a raw `ActiveRecord::StatementInvalid`.
- Tests now require a real PostgreSQL connection to be meaningful, which they already do.
- The five orphaned functions and their false `down` methods should be removed, and the credential
  count limits they were meant to enforce reconsidered on their own merits. That cleanup is out of
  scope here and is not a prerequisite for the freeze triggers, which use distinct names.
- Adding a trigger is deliberately more expensive than adding a validation. That asymmetry is
  intended.

## Current approved Avatar integrity triggers

The Avatar ownership and transfer work uses only the narrow cross-table mechanisms approved by the
ownership decisions. The trigger inventory test in `test/models/enforcement_triggers_test.rb`
asserts this set exactly:

- `avatar_enterprise_ownership_periods_integrity` and `avatar_bureau_ownership_periods_integrity`
  are deferred row triggers for INSERT/UPDATE/DELETE. They lock and increment
  `avatars.ownership_integrity_version`, then reject a missing owner, multiple current periods, a
  gap, or a cross-family overlap at commit with SQLSTATE `23514` or `23P01`. They do not rewrite
  ownership rows or emit audit/notification side effects.
- `avatar_enterprise_ownership_periods_immutability` and
  `avatar_bureau_ownership_periods_immutability` reject deletion and owner/start-time mutation; only
  one finite close of the open period is permitted, with SQLSTATE `45000`.
- `avatar_enterprise_ownership_periods_no_truncate` and
  `avatar_bureau_ownership_periods_no_truncate` reject TRUNCATE with SQLSTATE `45000`.
- `avatar_transfer_reservations_cardinality` and the four
  `avatar_transfer_detail_{ee,eb,be,bb}_cardinality` deferred constraint triggers require one
  concrete detail of the registry's declared family at commit. They reject orphan or multiple detail
  rows with SQLSTATE `23514`; the registry remains type-neutral and the four detail tables remain
  concrete.
- `avatar_transfer_reservations_source_period_avatar_integrity` and the four
  `avatar_transfer_detail_{ee,eb,be,bb}_source_period_avatar_integrity` deferred constraint triggers
  require each concrete detail's source ownership period to belong to the same Avatar as its
  registry reservation. They raise SQLSTATE `23514` and do not rewrite rows or choose an owner.

These triggers are created and attached by the same reversible Avatar migrations that create their
tables. Their execution and direct-SQL rejection are tested against disposable PostgreSQL catalogs;
no production or shared-database trigger change is authorized by this note.

## Approved ORG Telephone permanent-identity exception

The user explicitly approved the scoped proposal in
`evidence/2026-10-11-org-telephone-db-enforcement-map-M5Q8.md` on 2026-10-11. This is a named
exception to the general cross-row/table requirement, not permission for arbitrary same-row triggers
or other identifier tables.

For `operator_telephones.public_id` only, a BEFORE UPDATE OF public_id trigger may reject any change
from an already non-NULL identity, including replacement with NULL, with SQLSTATE `23514`. A
NULL-only operational backfill remains permitted; assigning the same identity and updating unrelated
fields remain permitted. The function must never generate, rewrite, log or silently ignore values.
CHECK/UNIQUE/FK cannot compare OLD and NEW, and the currently observed application connection owns
the table, so column permissions do not establish this invariant.

Create the function and attach its named trigger in one reversible migration; reverse by dropping
the trigger before the function. This row-local check acquires no additional row/table locks beyond
the UPDATE itself, performs no cross-database access, and has no recursive writes or side effects.
Register the exact trigger in the inventory and prove rejection through real direct SQL and bulk
updates, recovering the transaction after expected errors. Also prove the admitted NULL backfill and
unrelated updates. Approval alone is not evidence of implementation or passing tests. No
production/shared-database application or deliberate administrator bypass protection is claimed.

## Related

- `adr/unified-enforcement.md`
- `adr/authentication-method-lock.md` (superseded by `adr/unified-enforcement.md`)
- `adr/retainable-concern-and-retention-purge.md`
- `docs/reference/forbidden-rails-methods.md`
- `.agents/harnesses/rules/generic/no-silent-fallback.mdc`
- `.agents/harnesses/rules/generic/migrations.mdc`
