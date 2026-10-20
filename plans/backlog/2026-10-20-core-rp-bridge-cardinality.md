# Core RP Bridge Cardinality Mismatch

Recorded 2026-10-20. Status: backlog, direction decided, deferred beyond the current cycle.

## Problem

`Visitor`, `Client` and `Operator` declare `has_one :core_{com,app,org}_*_bridge`, but the database
only enforces uniqueness on `(actor_id, rp_client_id)` (for example
`idx_core_com_visitor_bridges_unique_visitor_rp`). Nothing constrains `rp_client_id` to a single
value, so the database allows several bridges per actor while the model promises one.
`database_consistency` reports this as a `MissingIndexChecker` failure on each actor model.

This is not a cross-database problem: the actor and bridge models both inherit from the same
`*ZenithRecord` connection (`com_zenith`, `app_zenith`, `org_zenith`), so one transaction and a real
foreign key can cover them.

## Decision

On 2026-10-20 the user accepted this direction: a core bridge is one row per actor.

- Make the actor foreign key alone unique (`visitor_id`, `client_id`, `operator_id`).
- `rp_client_id`, `audience` and `host` hold the same default value on every row. Review whether
  they belong in the table at all, or are constants of `CoreRpBridge`, and remove them if they carry
  no per-row meaning.
- Do not change the association to `has_many`. Configuration-file exclusions are not acceptable.

## Work required

1. Confirm no environment holds more than one bridge per actor or a non-default `rp_client_id`,
   `audience` or `host`. Any such rows need a decision before the constraint changes.
2. Add the single-column unique index concurrently and remove the composite one.
3. If the constant columns are removed, follow `generic/no-compatibility-layer.mdc` and
   `deprecation-and-migration`: update `CoreRpBridge` and every reader in the same change.
