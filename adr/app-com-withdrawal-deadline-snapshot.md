# App and Com Withdrawal Deadline Snapshot

## Status

**Accepted (2026-10-19).** This decision defines the app/com timing configuration and persistence
contract. It does not define the unresolved authentication assurance or Avatar final-deletion
policies.

## Decision

The Client and Visitor withdrawal lifecycle uses these standard intervals, measured from confirmed
deactivation:

| Deadline                                         | Standard interval |
| ------------------------------------------------ | ----------------: |
| Recovery becomes available                       |            1 hour |
| Early irreversible termination becomes available |            7 days |
| Normal retention purge eligibility               |           31 days |

The intervals are represented by the immutable `Umaxica::Withdrawal::TimingPolicyValue`. It accepts
only positive integer seconds and enforces `recovery < early termination < retention`. Development
and test may provide any subset of the override environment variables; an omitted duration uses its
accepted standard before the complete policy is validated. Production rejects the presence of any
override, including a blank or standard-valued variable; unknown environments also reject overrides.
The initializer runs in every Rails process, including Web, Solid Queue Worker, and Scheduler boots.

At confirmation, Client and Visitor persist the recovery and early-termination timestamps and keep
the existing `purge_eligible_at` as the retention deadline. A later configuration change never
shortens a previously confirmed deadline. Legacy suspended rows without the new columns use the
immutable legacy intervals and are not recalculated from a development/test override. Operator
withdrawal does not use this value object.

Ruby lifecycle checks use the persisted deadlines while database-clock comparisons remain the
authority for production transitions and retention jobs. `ActiveSupport::Testing::TimeHelpers` does
not advance PostgreSQL's clock and must not be treated as doing so.

## Consequences

Configuration errors fail during process boot rather than becoming request-time success or failure
ambiguity. Short development/test intervals support local browser and worker verification, while
production retains fixed standards. Existing rows remain temporally stable across deploys.

The deadline snapshot does not authorize recovery after irreversible anonymization, bypass retention
holds or Enforcement blocks, or restore an old session. The app/com withdrawal operation must still
fail closed when its purpose-specific assurance, Avatar preparation, legal hold, or external-storage
contract is unresolved.

## Relationship to existing decisions

This supplements the identity authority, withdrawal lifecycle, and retention ADRs. It is limited to
timing and persistence for Client and Visitor and does not change the Org/operator departure
workflow or the general Base/Auth authority boundary.
