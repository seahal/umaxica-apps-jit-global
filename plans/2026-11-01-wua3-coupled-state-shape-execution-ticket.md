# WU-A3 Auth Ceremony and OIDC state shape execution ticket

## Scope

`two.md` §3.6 requires the Auth Ceremony start/terminal/replacement axis and the OIDC
authenticated-to-Cancel axis to use explicit reference states with named transition writers. The
approved Admission Binding shape is tracked separately in
`adr/sign-up-flow-admission-binding-and-cardinality.md`.

This ticket requests approval for the two remaining state axes and local development/test migrations
only. Production, Neon, external repositories, and DNS are excluded.

## Proposed storage shapes

### App and Org Auth Ceremony

Add a realm-local id-only reference table and a NOT NULL `status_id` FK to each ceremony table. The
transition writer in `AuthCeremonySession` will be the only runtime writer of `status_id`. Existing
timestamps, SID digests, admission purpose, and authentication evidence remain facts and are not
deleted.

|  ID | State                       | Meaning                                                       |
| --: | --------------------------- | ------------------------------------------------------------- |
|  10 | `issued`                    | Ceremony exists but has not been admitted                     |
|  20 | `admitted`                  | Admission is attached; no authentication evidence is recorded |
|  30 | `evidence_recorded`         | Authentication evidence has been recorded                     |
|  40 | `replaced`                  | A later ceremony replaced this row in the SID lineage         |
|  90 | `revoked`                   | Revoked without a successor replacing this row                |
|  91 | `completed`                 | Ceremony completed                                            |
|  92 | `cancelled_before_progress` | Cancelled before authentication evidence                      |
|  93 | `cancelled_after_progress`  | Cancelled after authentication evidence                       |

`active?`, `terminal?`, `admitted?`, `completed?`, and `cancelled?` will read the explicit state.
`rotate_and_admit!` will transition the old row to `replaced` and create the new row as `admitted`
in one OP transaction. In-place `rotate!` retains the current lifecycle state while updating the SID
generation facts.

### App and Org OIDC authorization parent

Replace the persisted text `status` column with a NOT NULL `status_id` FK and realm-local id-only
status reference. `OidcAuthorizationTransactionable` remains the sole transition writer; all scopes,
predicates, and callers will use the explicit status IDs. The text column is removed in the same
cutover after all callers move; no dual-write or compatibility reader will remain.

|  ID | Existing value  |
| --: | --------------- |
|  10 | `pending`       |
|  20 | `authenticated` |
|  30 | `consumed`      |
|  90 | `canceled`      |

Cancel remains permitted from `pending` and from `authenticated` before finalization, and refused
from `consumed` or `canceled`.

## Local data inventory (read-only, 2026-11-01)

| Database        | Auth Ceremony rows | OIDC parent rows |
| --------------- | -----------------: | ---------------: |
| Development App |                  0 |                0 |
| Development Org |                  0 |                0 |
| Test App        |                  0 |                0 |
| Test Org        |                 16 |                0 |

The 16 Test Org ceremony rows comprise 10 revoked before admission, 1 revoked after admission, and 5
admitted without recorded authentication evidence. No Test Org row has authentication evidence,
completion, cancellation, or a successor row. No backfill has been performed for these two state
axes.

## Migration and recovery

The Auth Ceremony migration maps existing facts once: terminal timestamps first; `revoked_at` plus a
child whose `previous_sid_digest` matches the row's `sid_digest` maps to `replaced`; other
`revoked_at` maps to `revoked`; otherwise evidence maps to `evidence_recorded`, `admitted_at` maps
to `admitted`, and the remaining rows map to `issued`. Existing mutually exclusive terminal
constraints and evidence-pair constraints must be checked before the backfill.

The OIDC migration maps only the four existing closed string values to their listed IDs, verifies
there are no unknown values, adds and validates the FK, then removes the old string column. Its down
path restores the exact string from the fixed ID map before removing the reference column and table.

After approval, remeasure local rows immediately before migration and save development/test database
snapshots for the affected four tables. If counts or state-shape checks differ from this inventory,
stop before applying any migration. Recovery is the reverse migration plus snapshot restore if the
reverse migration itself cannot complete. No row deletion or terminal-fact rewrite is planned.

## Owner decision (2026-11-01)

The owner approved both proposed storage shapes and local development/test backfill/cutover.
Production, Neon, external repositories, and DNS remain excluded. The approval includes the
six-state Auth Ceremony reference, the four-state OIDC parent reference, and the described local row
backfills. It does not claim that any migration has been applied or verified.
