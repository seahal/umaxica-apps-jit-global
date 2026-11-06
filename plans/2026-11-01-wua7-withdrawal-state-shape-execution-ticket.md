# WU-A7 actor withdrawal state shape and local execution ticket

Status: draft; owner mapping and migration execution approval are pending.

## Scope

Apply only to the APP and ORG principal databases in local development and test. Production, Neon,
and every other database are excluded. The contract is `two.md` §3.8 and §6.3 plus `one.md` R-AU-40.
This ticket does not authorize migration execution or irreversible data changes.

## Proposed shape

- Add fixed-ID withdrawal-state reference tables in each owning principal database. The shared
  values are `active`, `recoverable_suspended`, `recovery_expired`, and `anonymized`.
- Add `withdrawal_state_id NOT NULL` to `clients` and `operators`, with a local FK to that realm's
  reference table. The state ID, not nullable timestamps or retention deadlines, is authoritative.
- Keep withdrawal, deactivation, anonymization, discard, and purge timestamps as facts. Keep
  `discard_at` and `purge_eligible_at` under the separate Retainable contract; they do not define
  withdrawal state.
- Store each current recovery period in an actor-unique row with a NOT NULL deadline. APP also needs
  its recovery-available and early-termination-available instants in that period record. A completed
  recovery records the prior period's deadline in the existing immutable withdrawal flow event
  before retiring the current period row, so a later withdrawal can establish a new actor-unique
  current period.
- Remove runtime legacy-delay fallbacks, `respond_to?` lifecycle branches, and reads that infer
  actor state from NULL or `infinity`. The legacy APP recovery deadline columns are candidates for
  removal after their values are copied into the period record; their removal is destructive and
  needs separate approval.

The mapping of ORG's indefinite `suspend` operation is unresolved: current behavior allows restore
without a deadline, while §6.3 requires a deadline for `recoverable_suspended`. The owner has been
asked whether that operation should remain on the four-state withdrawal axis or use the distinct
administrative access-state axis. No implementation choice is inferred here.

## Current local counts and one-time classification

Read-only measurements with `.env.container.devcontainer` loaded:

| Environment/database owner |                              Actor rows | Lifecycle evidence                                                                                                                                                      | Proposed migration mapping                                                                                                                 |
| -------------------------- | --------------------------------------: | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| Development APP principal  |                               0 Clients | No actor rows                                                                                                                                                           | No rows to map                                                                                                                             |
| Development ORG principal  |                             0 Operators | No actor rows                                                                                                                                                           | No rows to map                                                                                                                             |
| Test APP principal         |                               0 Clients | No actor rows; 0 `ClientWithdrawalFlow` rows; rebuilt test schema exposes `status_id` on the flow table                                                                 | No actor rows to map.                                                                                                                      |
| Test ORG principal         | 6 Operators: status 2 × 5, status 3 × 1 | No `withdrawal_started_at`, `deactivated_at`, or `withdrawn_at`; lifecycle-request counts below are from the preceding inventory and were not refreshed in this recheck | All 6 to `active` if no intervening row changes. Operator/account status and unexecuted requests are separate from actor withdrawal state. |

The earlier 2026-11-01 APP counts of 7 and 9 are superseded by the local test database rebuild
recorded in `evidence/2026-11-01-wua7-test-db-rebuild-M8Q3.md`. The rebuilt test APP principal has
no actor or flow rows, and its flow schema exposes `status_id`. Test ORG lifecycle-request counts (2
pending withdrawals, 1 approved withdrawal, and 1 pending join, with no executed request) are from
the prior inventory and were not refreshed during that rebuild. All local counts must be refreshed
immediately before any WU-A7 migration. Retention timestamps are not used to infer withdrawal state.
The migration must fail closed with a count of unclassified rows if a future target contains
lifecycle facts that cannot be mapped unambiguously; it must not print identity data or default an
ambiguous row to `active`.

## Execution and recovery

Before applying migrations, refresh a local snapshot for each of the four in-scope databases and
repeat the counts above. Apply only the APP/ORG principal migrations to local development/test.
Verify reference rows, NOT NULL/FK constraints, per-state actor counts, one-to-one recovery-period
constraints, and unchanged actor/flow/request counts.

For recovery, revert application code before reverting additive shape. Restore each affected local
database from its pre-migration snapshot if any actor state or period transition has been written;
otherwise run the migration rollback and verify the original row counts and legacy column values. Do
not drop the APP recovery deadline columns in the initial cutover unless the owner separately
approves their measured values, risk, and recovery procedure.

## Approval record

- ORG indefinite-suspension mapping: pending owner decision.
- Local APP/ORG principal shape/backfill and migration execution: pending owner approval after the
  mapping is resolved and pre-execution counts/snapshots are refreshed.
- Destructive removal of legacy recovery deadline columns or any actor data: not approved.
