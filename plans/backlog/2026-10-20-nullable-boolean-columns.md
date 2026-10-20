# Nullable Boolean Columns Must Become NOT NULL

Recorded 2026-10-20. Status: backlog, decided, not started.

## Decision

On 2026-10-20 the user made this absolute: giving NULL a meaning, or branching on NULL in the
database, is forbidden. Recorded as a MUST in `AGENTS.md` (Governing Principles and Constraints).

On 2026-10-20 the user decided that boolean columns must not allow NULL. Every
`ThreeStateBooleanChecker` finding is resolved by making the column `NOT NULL`. A column that needs
a third state is redesigned as an explicit state (reference table or enum), not kept as a nullable
boolean. Configuration-file exclusions are not acceptable.

## Columns reported on 2026-10-20

- `{operator,visitor,client}_step_up_ceremony_transactions.user_verified`
- `{operator,visitor,client}_tokens.last_step_up_user_verified`
- `{operator,visitor,client}_tokens.last_step_up_full_reauthentication`
- `{visitor,client,operator}_passkeys.backup_eligible`
- `{visitor,client,operator}_passkeys.backup_state`

## Work required per column

1. Determine what NULL currently means in code (for example "no step-up yet", or a WebAuthn flag not
   reported by an older registration). If NULL carries meaning, model that meaning explicitly first.
2. Backfill existing NULL rows. This is a bulk update of identity and security state and needs
   explicit risk and recovery-plan approval before it runs.
3. Add `NOT NULL` with the strong_migrations pattern: a `CHECK (column IS NOT NULL) NOT VALID`
   constraint, validation in a separate migration, then `change_column_null` and removal of the
   check.
4. Update the writers so they always set the value, and cover the boundary in tests.
