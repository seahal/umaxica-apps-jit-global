# IdP Flow State-Machine Lifecycle and State Storage

## Status

Accepted (2026-10-02) as a future implementation contract.

**Accepted design does not mean current runtime has been migrated.** No model, controller,
service, operation, migration, schema, route, seed, constant, status id, or test was changed by
this decision. Every "current" statement below was observed read-only at commit
`7430ddea6da1e18da0b42418e5374379a52c8a4b`. Every "target" statement is a contract for future
work tracked in `plans/backlog/idp-flow-state-machine-unification.md`.

This ADR extends `adr/idp-flow-lifecycle-vocabulary.md`. That ADR fixes the vocabulary and
invariants and explicitly left the physical representation undecided; this ADR decides the
physical representation (DB-backed state reference tables, id-only rows, FK ownership, id
contract) and restates the vocabulary so both decisions can be read together. Where the two
differ, this ADR governs storage and the vocabulary ADR governs terminology. The reference
document is `docs/security/idp-flow-lifecycle.md`.

## Context

### Current state-machine architecture

| Flow     | Records (database)                                                                  | Transition owner today                                              |
| -------- | ----------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| Sign-in  | `client_sign_in_flows` (app_ticket), `visitor_sign_in_flows` (com_ticket), `operator_sign_in_flows` (org_ticket) | `FlowSignIn` concern, `TRANSITIONS` hash per model, called from controllers and services |
| Sign-up  | `client_sign_up_flows`, `visitor_sign_up_flows`, `operator_sign_up_flows`          | `SignUpStateMachine`, `SignUpTermination`, `SignUpExpiryJob`, plus some direct writes |
| Sign-out | `client_sign_out_flows`, `visitor_sign_out_flows`, `operator_sign_out_flows`       | `FlowSignOut` concern inside the logout primitive                   |

Each flow table carries `status_id bigint NOT NULL DEFAULT 10` with a foreign key to a per-flow
reference table `*_sign_{in,up,out}_flow_statuses`. Those reference tables already contain only
`id bigint` (backed by a sequence). All nine FKs are declared `NOT VALID`; the sign-up FKs add
`ON DELETE RESTRICT`, the others use the default `NO ACTION`.

Sign-in and sign-up flow tables additionally carry `state` and `step` string columns. On the
three sign-in tables, `CHECK` constraints (`chk_*_sign_in_cycles_status_state` and
`..._status_step`, both `NOT VALID`) tie `state` and `step` to `status_id`. That is a second
representation of the same fact, kept consistent by the database, and it embeds the id-to-name
mapping in the schema.

### Current status ids

| Id  | Sign-in (all actors)        | Sign-up client / visitor  | Sign-up operator     | Sign-out (all actors) |
| --- | --------------------------- | ------------------------- | -------------------- | --------------------- |
| 0   |                             |                           |                      | `NOTHING`             |
| 10  | `PRIMARY_PENDING`           | `STARTED`                 | `STARTED`            | `REQUESTED`           |
| 20  | `MFA_PENDING`               | `CONTACT_PENDING`         | `CONTACT_PENDING`    | `ACCESS_DISCARDED`    |
| 30  | `SESSION_LIMIT_PENDING`     | `CREDENTIAL_PENDING`      | `CREDENTIAL_PENDING` | `LOGICALLY_REVOKED`   |
| 35  |                             | `CONTACT_VERIFIED`        |                      |                       |
| 36  |                             | `SOCIAL_CALLBACK_PENDING` |                      |                       |
| 38  |                             | `GUARDRAIL_PENDING`       |                      |                       |
| 40  | `GUARDRAIL_PENDING`         | `CHECKPOINT_PENDING`      | `CHECKPOINT_PENDING` | `AWAITING_EXPIRY`     |
| 50  | `SESSION_ISSUANCE_PENDING`  |                           |                      |                       |
| 60  | `CHECKPOINT_PENDING`        | `FINALIZING`              |                      |                       |
| 65  | `SELECTOR_PENDING`          |                           |                      |                       |
| 70  | `DASHBOARD_PENDING`         | `FINALIZED`               |                      |                       |
| 80  | `RETURN_PENDING`            | `SIGN_IN_HANDOFF_PENDING` |                      |                       |
| 100 | `COMPLETED`                 | `COMPLETED`               | `COMPLETED`          | `COMPLETED`           |
| 900 | `FAILED`                    | `FAILED`                  |                      | `FAILED`              |
| 910 |                             | `EXPIRED`                 |                      |                       |
| 920 |                             | `CANCELLED`               |                      |                       |

The sign-up cleanup status tables (`*_sign_up_flow_cleanup_statuses`: 10 `IDLE`, 20 `PENDING`,
30 `COMPLETED`, 40 `FAILED`) and sign-out kind tables are separate domains and are not flow
lifecycle state.

### Current reference row provisioning

Sign-up status rows are inserted lazily by `ensure_defaults!` calls on request paths in Auth and
Base controllers and concerns. `db/seeds.rb` does not list the flow status classes, and the
migrations that created the tables insert no rows. A provisioning path for sign-in and sign-out
status rows was not located during this inventory. Reference rows are therefore not
migration-controlled today.

### Problem

1. Vocabulary drift: see `adr/idp-flow-lifecycle-vocabulary.md` (`FAILED` absorbing cancellation,
   policy, and operational failure; `stopped`, `hard_reject`, `blocked`, `failure`, retry/replay,
   stale/conflict).
2. The state domain is enforced by FKs that are `NOT VALID` and by reference rows that may be
   inserted by request code, so the domain depends on runtime side effects.
3. Sign-in duplicates state in `state`/`step` columns with `CHECK` constraints.
4. State changes are written in several places, including controllers and operations that
   assign `status_id` directly, so transition legality has no single owner.
5. Terminal ids are not uniform, and the example convention proposed during design
   (`900 COMPLETED`, `910 CANCELLED`, `920 EXPIRED`, `930 HALTED`) collides with ids already in
   use: `900` is `FAILED` and `910` is `EXPIRED` and `920` is `CANCELLED` in sign-up, and `100` is
   `COMPLETED` everywhere.

## Decision

### 1. No single merged state machine

Sign-in, sign-up, and sign-out remain separate state machines, one per flow and per actor
database. What is shared is: lifecycle semantics, terminal semantics, event vocabulary, request
semantics, transition invariants, and the state-reference-table contract. Flow-specific active
phases keep their names and are not unified.

### 2. Lifecycle (logical)

```text
ACTIVE  COMPLETED  CANCELLED  EXPIRED  HALTED
```

This is a logical model computed by application code from the stored state id. It is not a
column, not a reference-table attribute, and not a second FK.

| Lifecycle   | Meaning                                                                                                  |
| ----------- | -------------------------------------------------------------------------------------------------------- |
| `ACTIVE`    | Any non-terminal flow-specific phase.                                                                    |
| `COMPLETED` | The flow finished normally.                                                                              |
| `CANCELLED` | The user ended the flow by explicit intent.                                                              |
| `EXPIRED`   | The flow's validity ended according to the authoritative clock or TTL.                                   |
| `HALTED`    | The system irreversibly ended the flow because continuing is unsafe, inconsistent, or forbidden by policy. It is never a user action. |

### 3. Transition events

```text
start  advance  back  cancel  external_result  complete  expire  halt
```

- `start` creates a flow.
- `advance` moves forward. `proceed` is not canonical. Flow-internal event names remain and are
  classified as `advance`.
- `back` is a state-machine edge to an explicitly allowed earlier phase, not browser history. It
  requires the current state to match, no conflict, a phase that is rollback-capable, and it
  invalidates one-time challenges, tokens, or nonces issued by the phases it leaves. It never
  crosses an irreversible account, session, or token commit, or an authority handoff.
- `cancel` is user intent and produces `CANCELLED`. It is not available from every phase.
- `external_result` is the only event for results crossing an external boundary. Provider and
  protocol differences (Google, Apple, Entra, OIDC, WebAuthn, Auth-to-Base ceremony result,
  RP-to-IdP logout return) live in the payload
  `external_result(source:, outcome:, reason_code:, correlation:)`. `external_success`,
  `external_failure`, `provider_result`, `callback_result`, and `provider_callback_result` are not
  introduced.
- `complete` produces `COMPLETED` when the orchestrator's completion conditions hold.
- `expire` produces `EXPIRED` from the authoritative clock.
- `halt` produces `HALTED`. It is system-only, requires a `reason_code`, is auditable, and is
  never reachable from a UI action or a user-controlled parameter.

### 4. Request semantics (not events)

- **reentry** (not `reenter`): a request reaches an existing active flow (reload, bookmark,
  returning from elsewhere, outdated browser navigation) and the server re-resolves the
  authoritative state. It does not transition by itself; expiry is evaluated first, so reentry can
  result in `expire`.
- **replay** (not "retry / replay"): an already-processed request or event arrives again in the
  same or substantially the same form. It never repeats side effects. A user entering a new value
  after a rejection is a new `advance` attempt, not a replay.
- **conflict** (not "stale / conflict"): the request's assumed state differs from the
  authoritative state (multi-tab, concurrent request, outdated checkpoint or transition revision,
  already advanced, already completed). Conflict never rolls back authoritative state. `stale`
  survives only as a reason code, for example `reason_code = stale_version`.

### 5. Outcomes and reasons

- `rejected` is a transition outcome: the requested operation was not accepted and the lifecycle
  normally stays unchanged.
- `locked` describes a credential, account, or resource. If a lock makes the flow permanently
  non-continuable, the flow takes `halt(reason_code: credential_locked)`.
- Reason codes never become states or events.

### 6. Cancel versus halt

`cancel` requires user intent and is audited as such. `halt` requires a system determination and
a reason code. A user action never produces `HALTED`, and a system decision never produces
`CANCELLED`.

### 7. FAILED legacy handling

`FAILED` is not a canonical terminal. Runtime `FAILED` (id `900`) is not changed by this ADR.
Each code path that reaches `FAILED` is classified individually:

- unrecoverable, non-resumable, terminal cause → target `HALTED` with a reason code;
- explicit user decision to stop → target `CANCELLED`;
- retryable validation failure, wrong OTP, credential mismatch, ordinary refused request →
  `rejected`, flow stays active;
- temporary provider, DB, or network failure, or timeout → authoritative state preserved; not
  `HALTED` unless a separate explicit invariant makes the flow non-continuable;
- concurrent state change → `conflict`.

`stopped`, `hard_reject`, `blocked`, `failure`, `fail`, and `credential_rejected` follow the same
classification. Mechanical search-and-replace is forbidden.

### 8. Physical state: one `state_id`, DB-backed, per-flow reference table

Every sign-in, sign-up, and sign-out flow table has exactly one authoritative state column. It is
`NOT NULL` and has a validated FK to a reference table owned by that flow, in the same database:

```text
client_sign_in_flows.state_id    -> client_sign_in_flow_states.id     (app_ticket)
client_sign_up_flows.state_id    -> client_sign_up_flow_states.id     (app_ticket)
client_sign_out_flows.state_id   -> client_sign_out_flow_states.id    (app_ticket)
visitor_sign_in_flows.state_id   -> visitor_sign_in_flow_states.id    (com_ticket)
visitor_sign_up_flows.state_id   -> visitor_sign_up_flow_states.id    (com_ticket)
visitor_sign_out_flows.state_id  -> visitor_sign_out_flow_states.id   (com_ticket)
operator_sign_in_flows.state_id  -> operator_sign_in_flow_states.id   (org_ticket)
operator_sign_out_flows.state_id -> operator_sign_out_flow_states.id  (org_ticket)
```

`operator_sign_up_flows` exists today with its own status table; whether operator sign-up adopts
this lifecycle (it currently has no `FAILED`, `EXPIRED`, or `CANCELLED`) is an open item in the
plan. Reference tables are never shared across flows, actors, or databases.

**Current:** `status_id` with `*_flow_statuses`. **Target terminology:** `state_id` with
`*_flow_states`, because the column is a state-machine state, not an HTTP status, result status,
or cleanup status. Whether and how to rename (and whether the reference table is renamed) is a
future implementation decision with its own migration strategy. No rename happens now. Existing
tables that already satisfy the id-only contract are not destructively recreated.

### 9. Reference tables hold only `id`

The target shape is:

```sql
CREATE TABLE client_sign_up_flow_states (
  id <integer type> PRIMARY KEY
);
```

The current tables already match this shape apart from naming, the `bigint` type, and an attached
sequence. Narrowing to `smallint` or dropping the sequence is optional and is decided in the plan;
the contract is "only `id`, no generated values relied on".

Reference tables do not hold `name`, `slug`, `code`, `label`, `description`, `lifecycle`,
`terminal`, `active`, `sort_order`, `enabled`, `created_at`, or `updated_at`. Their single
responsibility is that a flow row cannot store a state id outside the flow's allowed set. Runtime
code never joins them to interpret state.

Flow state tables are an explicit exception to the `NOTHING = 0` sentinel in
`adr/reference-table-discipline.md`: a flow always has a real state, so its default is its start
state rather than an "unspecified" row. The existing sign-out `NOTHING = 0` row is retained (ids
are never removed) but becomes unreachable from application code in the target.

### 10. Meaning lives in the application contract

The id-to-meaning map is fixed by application constants per flow and by
`docs/security/idp-flow-lifecycle.md`. Application code defines, per flow, the active state set,
the terminal state set, and which terminal id is `COMPLETED`, `CANCELLED`, `EXPIRED`, or
`HALTED`.

No `lifecycle` column, no `lifecycle_status_id` plus `phase_id` pair, and no reference-table
lifecycle attribute is added, because two stored facts can disagree (for example lifecycle
`COMPLETED` with phase `CHECKPOINT_PENDING`). Existing duplicate representations (sign-in and
sign-up `state`/`step` strings and the sign-in `CHECK` constraints) are migration items to retire
in the plan; they are not part of the target.

### 11. State id contract (immutable)

- A state id, once assigned a meaning in a flow, keeps that meaning forever.
- Ids are never reused, including ids of retired states. Retired ids stay as reference rows
  (tombstones) and become unreachable from application code.
- The meaning of an id is never mutated.
- A reference row that is referenced, or ever was assigned, is never deleted.
- Active phase ids are independent per flow. Equal active ids in different flows do not imply
  equal meaning, because each reference table is its own namespace.

### 12. Shared terminal id convention (adopted)

Terminal ids are shared across all flows. Because ids are immutable, the convention is anchored on
ids already in use rather than on a renumbering:

| Lifecycle   | Id    | Status today                                                   |
| ----------- | ----- | -------------------------------------------------------------- |
| `COMPLETED` | `100` | Already `COMPLETED` in every flow.                             |
| `EXPIRED`   | `910` | Already `EXPIRED` in client and visitor sign-up; free elsewhere. |
| `CANCELLED` | `920` | Already `CANCELLED` in client and visitor sign-up; free elsewhere. |
| `HALTED`    | `930` | Free in every flow.                                            |
| legacy `FAILED` | `900` | Reserved tombstone; never reassigned, never a target terminal. |

The `900–999` range is reserved for terminal and legacy-terminal ids; active phases use ids below
`900` and never `100`. The example numbering `900 COMPLETED / 910 CANCELLED / 920 EXPIRED /
930 HALTED` is rejected because it would reassign `900`, `910`, and `920`, which violates the
immutable id contract. Phase 0 of the plan must still re-run the inventory against every live
database before adding any row, and record the result in `evidence/`.

### 13. Responsibility split: FK versus application state machine

```text
DB:   per-flow reference table + NOT NULL validated FK   -> valid state domain
App:  per-flow state machine (from, event, to, guards)   -> valid transition
```

The FK guarantees **state-domain integrity**: a flow row cannot hold a state id that does not
exist for that flow. The FK does **not** guarantee **transition legality**: `STARTED -> COMPLETED`
cannot be prevented by an FK because `COMPLETED` is a valid id.

Transition legality is owned by the per-flow application state machine. In the target, every
state change passes through that flow's transition boundary. Direct writes such as
`update!(status_id: ...)` or `update!(state_id: ...)` from controllers, operations, or arbitrary
model code are forbidden. Current runtime has such direct writes; removing them is plan Phase 4.

### 14. No DB trigger enforcement of transitions

An allowed-transition table with a PostgreSQL trigger is not adopted. It would duplicate the
application state machine, cannot evaluate guards that depend on domain logic, raises migration
cost, and splits each transition change across DB and application code. This is consistent with
`adr/database-trigger-usage-boundary.md`. Adopting DB-level transition enforcement later needs its
own ADR.

### 15. Reference rows are migration-controlled

Reference rows are immutable reference data owned by migrations, not optional seeds and not
request-time side effects. A deployment-safe migration sequence creates or reuses the table,
inserts every required id idempotently, then validates the FK. An environment where seeds did not
run must still have every state id. Request-path `ensure_defaults!` calls for flow states are
removed once migrations own the rows. No migration is created by this ADR.

### 16. Terminal and reachability invariants

1. `COMPLETED`, `CANCELLED`, `EXPIRED`, and `HALTED` are terminal and absorbing.
2. No terminal-to-active transition; no terminal-to-different-terminal transition. Terminal
   meaning is never overwritten.
3. Every reachable non-terminal phase reaches some terminal through at least one of: advance,
   cancel, expire, halt, or deterministic external resolution. Cancel need not be available
   everywhere; phases after an irreversible commit or authority handoff may only complete,
   expire, or halt. No user is held in an indefinite `ACTIVE` phase.
4. Temporary infrastructure failure (DB, network, provider, timeout) preserves authoritative state
   and does not produce `HALTED` by itself.
5. A later request based on older state never rolls back an authoritative transition.
6. `external_result` is correlated, expiry-bound, one-shot, and replay-resistant.

### 17. Authority boundaries are preserved

Shared lifecycle vocabulary never merges authority:

- Auth (historically `sign/id`) performs ceremonies; Base (historically `acme/www`) owns OIDC
  transactions, browser sessions, RP sessions, and tokens
  (`adr/base-auth-ceremony-and-seven-rp-boundary.md`).
- Sign-up durable completion and sign-in are two flows joined by a handoff. A sign-in handoff
  failure after sign-up durable commit is never handled by moving sign-up back to an earlier state
  or deleting committed account artifacts.
- RP-to-IdP logout and provider or OIDC callbacks reach a flow only through `external_result`.

## Consequences

- Future storage work has one target: one `state_id` per flow row, validated FK, id-only per-flow
  reference table, migration-owned rows, immutable ids.
- Runtime interpretation never needs a JOIN; it needs per-flow constants that must stay aligned
  with the documented id table. Tests and graph validation are the alignment mechanism.
- Adding `HALTED` (`930`) and `EXPIRED`/`CANCELLED` (`910`/`920`) to sign-in and sign-out is
  additive. Legacy `900` rows stay readable as terminal during and after migration.
- Retiring sign-in `state`/`step` strings and their `CHECK` constraints, validating the `NOT VALID`
  FKs, and moving row provisioning into migrations each need their own migration with a recovery
  plan approved before execution.
- The `NOTHING = 0` exception for flow state tables must be noted where
  `adr/reference-table-discipline.md` lists exceptions when the implementation lands.

## Not Yet Implemented

Everything in the Decision section is target. As of the commit above: columns are still
`status_id`; tables are still `*_flow_statuses`; FKs are `NOT VALID`; sign-in has no `EXPIRED`,
`CANCELLED`, or `HALTED`; sign-out has no `EXPIRED`, `CANCELLED`, or `HALTED`; no flow has
`HALTED`; `FAILED` is still written; rows are provisioned outside migrations; direct `status_id`
writes exist outside the state machines.

## Related

- `adr/idp-flow-lifecycle-vocabulary.md`
- `docs/security/idp-flow-lifecycle.md`
- `plans/backlog/idp-flow-state-machine-unification.md`
- `adr/reference-table-discipline.md`
- `adr/database-trigger-usage-boundary.md`
- `adr/base-auth-ceremony-and-seven-rp-boundary.md`
- `adr/sign-up-cycle-cancellation-retention.md`
- `adr/logout-ceremony-boundary.md`
