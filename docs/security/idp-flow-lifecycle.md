# IdP Flow Lifecycle

This document is the reference for lifecycle vocabulary across sign-in, sign-up, and sign-out. The
vocabulary decision is `adr/idp-flow-lifecycle-vocabulary.md`, the state storage decision is
`adr/idp-flow-state-machine-lifecycle.md`, and the sign-in/sign-up migration is planned in
`plans/backlog/idp-flow-state-machine-unification.md`. Sign-out authority is documented by the
current OP authority-stop contract, not by the retired flow vocabulary below.

> **Reading rule:** The historical inventory below records the pre-unification vocabulary and is
> retained for traceability. The delivered amendments at the end of this document describe the
> current runtime for the implemented slices. A target term is not evidence of implementation unless
> the current amendment, code, schema, and tests all show it.

## Term Categories

Every term used about these flows belongs to exactly one category.

| Category           | What it is                                                                       | Examples (target)                                                                     |
| ------------------ | -------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| Lifecycle state    | Coarse, flow-independent position of a flow instance.                            | `ACTIVE`, `COMPLETED`, `CANCELLED`, `EXPIRED`, `HALTED`                               |
| Phase              | Flow-specific position while `ACTIVE`.                                           | `MFA_PENDING`, `CHECKPOINT_PENDING`, `ACCESS_DISCARDED`                               |
| Transition event   | Something that may change lifecycle or phase.                                    | `start`, `advance`, `back`, `cancel`, `external_result`, `complete`, `expire`, `halt` |
| Request semantics  | How the server classifies an arriving request before or instead of a transition. | `reentry`, `replay`, `conflict`                                                       |
| Condition          | A predicate evaluated on the request or flow.                                    | TTL lapsed, checkpoint version matches, actor already signed in                       |
| Transition outcome | What one request achieved.                                                       | `advanced`, `rejected`, `conflict`, `replay`                                          |
| Reason code        | Implementation detail explaining an outcome or a halt.                           | `credential_locked`, `stale_version`, `credential_mismatch`                           |

`conflict` and `replay` are both request semantics and outcomes: classifying the request is the
semantics, and reporting it back is the outcome. They are never events or states.

## Current Runtime Inventory

### Sign-in

Records: `ClientSignInFlow`, `VisitorSignInFlow`, `OperatorSignInFlow` with `FlowSignIn`.

- Statuses: `PRIMARY_PENDING`, `MFA_PENDING`, `SESSION_LIMIT_PENDING`, `GUARDRAIL_PENDING`,
  `CHECKPOINT_PENDING`, `SELECTOR_PENDING`, `SESSION_ISSUANCE_PENDING`, `COMPLETED`, `FAILED`.
  `DASHBOARD_PENDING` and `RETURN_PENDING` remain as legacy compatibility statuses from the former
  post-issuance flow.
- There is no `EXPIRED` or `CANCELLED` status. Expiry is a request-time `expires_at` check that
  raises (`SignInSessionLimitManager`, `SignInSelectorParticipant`). The sign-in Mermaid diagrams
  draw `EXPIRED` and `CANCELLED`; that is diagram vocabulary, not runtime.
- `fail_sign_in!` moves to `FAILED` from every non-terminal status. Current callers: user
  cancellation of pending MFA (`cancel_pending_mfa!`), user cancellation on the session-limit page,
  the former `session_limit_hard_reject` (removed in `c737e51ae`), and
  `SignInSessionLimitManager#cancel!`.
- Result statuses (`SignInResult`): `success`, `mfa_required`, `session_limit_pending`, and the
  terminal-HTTP set `session_limit_hard_reject`, `guardrail_blocked`, `login_forbidden`,
  `credential_rejected`, `credential_failed`, `identity_unavailable`, `transaction_expired`,
  `failure`, `invalid_request`. "Terminal" here means "ends this HTTP request with an error status",
  not a lifecycle state.

### Sign-up

Records: `ClientSignUpFlow`, `VisitorSignUpFlow` (and `OperatorSignUpFlow`, which has only
`STARTED`, `CONTACT_PENDING`, `CREDENTIAL_PENDING`, `CHECKPOINT_PENDING`, `COMPLETED`).

- Statuses: `STARTED`, `CONTACT_PENDING`, `CREDENTIAL_PENDING`, `CONTACT_VERIFIED`,
  `SOCIAL_CALLBACK_PENDING`, `GUARDRAIL_PENDING`, `CHECKPOINT_PENDING`, `FINALIZING`, `FINALIZED`,
  `SIGN_IN_HANDOFF_PENDING`, `COMPLETED`, `FAILED`, `EXPIRED`, `CANCELLED`.
- `SignUpStateMachine` events: `start`, `submit_contact`, `verify_contact`, `start_social_callback`,
  `complete_social_callback`, `enter_guardrail`, `enter_checkpoint`, `clear_requirement`,
  `finalize`, `handoff_to_sign_in`, `complete`, `fail`, `expire`, `cancel`.
- Result statuses (`SignUpResult`): `ok`, `advanced`, `blocked`, `invalid_transition`,
  `unauthorized`, `expired`, `failed`, `completed`, `sign_in_handoff_accepted`,
  `sign_in_handoff_stopped`, `sign_in_handoff_failed`. A successful `cancel` reports `failed` from
  the state machine and `ok` from `SignUpTermination`.
- Cancel is allowed before `FINALIZING` only (`adr/sign-up-cycle-cancellation-retention.md`).
  `FINALIZING`, `FINALIZED`, and `SIGN_IN_HANDOFF_PENDING` have only `FAILED` (and the next phase)
  as outbound edges; they have no `EXPIRED` edge.
- `clear_requirement` rejects a mismatched `checkpoint_version` as `invalid_transition` with message
  "checkpoint is stale".
- `SignUpTermination` drives `cancel`, `expire`, and `fail`, then schedules retention and artifact
  cleanup. `SignUpExpiryJob` sweeps in-progress rows past `expires_at`.

### Sign-out

Sign-out is not a persisted flow state machine. The `op_app_authority_stops`,
`op_com_authority_stops`, and `op_org_authority_stops` records own durable authority-stop decisions;
root, grant, cutoff, participant, and browser references remain their children. APP, COM, and ORG
request handling performs its local cleanup around that authority boundary. The retired
`ClientSignOutFlow`, `VisitorSignOutFlow`, `OperatorSignOutFlow`, kind/status references, and
`FlowSignOut` concern are removed under D-179 (2); the OP databases drop those tables through the
D-179 migrations.

## Target Model

### Lifecycle and phase

```text
lifecycle ∈ { ACTIVE, COMPLETED, CANCELLED, EXPIRED, HALTED }
phase     = flow-specific, meaningful only while lifecycle = ACTIVE
```

`ACTIVE` is the only non-terminal lifecycle state. Each flow keeps its own phases; phases are not
renamed or merged across flows. Whether lifecycle and phase become separate columns or stay
derivable from one status column is an implementation decision.

### Terminal states

| State       | Entered by | Meaning                                                                          |
| ----------- | ---------- | -------------------------------------------------------------------------------- |
| `COMPLETED` | `complete` | The flow finished normally.                                                      |
| `CANCELLED` | `cancel`   | The user explicitly ended the flow.                                              |
| `EXPIRED`   | `expire`   | The authoritative clock or TTL ended the flow.                                   |
| `HALTED`    | `halt`     | The system irreversibly ended the flow for safety, integrity, or policy reasons. |

Terminal states are absorbing. A request against a terminal flow can only observe it; it cannot
return it to `ACTIVE` or move it to a different terminal state. A new attempt is a new `start`.

### Events

| Event             | Initiator                      | Effect                                                           |
| ----------------- | ------------------------------ | ---------------------------------------------------------------- |
| `start`           | User request                   | Creates a new `ACTIVE` flow at its first phase.                  |
| `advance`         | User request or orchestrator   | Moves to a later phase after the current phase is satisfied.     |
| `back`            | User request                   | Moves to an earlier phase only along an explicitly allowed edge. |
| `cancel`          | User only                      | `ACTIVE` to `CANCELLED`.                                         |
| `external_result` | External boundary via callback | Feeds a correlated external result into the flow.                |
| `complete`        | Orchestrator only              | `ACTIVE` to `COMPLETED` when completion conditions hold.         |
| `expire`          | Authoritative clock            | `ACTIVE` to `EXPIRED`.                                           |
| `halt`            | System only, with reason code  | `ACTIVE` to `HALTED`.                                            |

Flow-internal event names such as `verify_contact`, `clear_requirement`, `finalize`, or
`mark_logically_revoked!` stay valid internally and are classified as `advance`.

`back` rules:

- It exists only where the flow declares the edge. The browser Back button is not `back`; it
  produces `reentry`.
- Leaving a phase through `back` invalidates any one-time challenge, token, or nonce issued by that
  phase or a later one.
- It never crosses an irreversible commit or authority handoff.

`expire` is not retention. Expiry ends the flow; logical discard, `purge_eligible_at`, artifact
cleanup, and physical deletion are separate retention steps that may follow.

### Request semantics

- **reentry** — a request reaches an existing `ACTIVE` flow by reload, bookmark, or navigation. The
  server evaluates expiry first, then renders the authoritative phase. Reentry never advances or
  goes back by itself.
- **replay** — an already-processed mutation arrives again. The server returns the result of the
  original processing or a neutral observation, and never repeats side effects.
- **conflict** — the request assumes a different state than the authoritative one. The server
  rejects the mutation, keeps authoritative state, and lets the user reenter the current phase.

### Outcomes

| Outcome    | Meaning                                           | Lifecycle effect |
| ---------- | ------------------------------------------------- | ---------------- |
| `advanced` | The event was accepted.                           | As per the event |
| `rejected` | The operation was not accepted.                   | Unchanged        |
| `conflict` | The request was based on non-authoritative state. | Unchanged        |
| `replay`   | The request repeated already-processed work.      | Unchanged        |

An outcome is never a lifecycle state. A rejected credential leaves the flow `ACTIVE`; a halted flow
is `HALTED` regardless of how the triggering request is reported.

## Examples

### Reentry, replay, and conflict

- **Reload during MFA.** The flow is `ACTIVE / MFA_PENDING`. Reload is reentry: expiry is checked,
  then the MFA page renders again. No challenge is re-issued unless the phase defines that.
- **Reload after TTL.** Reentry evaluates expiry first, fires `expire`, and the flow becomes
  `EXPIRED`. The user is told to start again.
- **Double-submitted cancel.** The first request cancels; the second is replay and returns the same
  observation without re-running cleanup.
- **Two tabs at checkpoint.** Tab A clears the passkey requirement and the checkpoint version
  increments. Tab B submits the old version. Tab B gets `conflict` with
  `reason_code = stale_version`; tab A's work stands, and tab B reenters the current checkpoint.
- **Finalize raced by a second request.** The row lock admits one finalization. The second request
  is `conflict` (or `replay` when it is the same request) and creates no second identity graph.

### Cancellation versus halt

| Situation                                                                        | Target classification                             |
| -------------------------------------------------------------------------------- | ------------------------------------------------- |
| User presses cancel on pending MFA                                               | `cancel`, `CANCELLED`                             |
| User cancels on the session-limit page                                           | `cancel`, `CANCELLED`                             |
| Sign-in while the actor's waiting slot is occupied (decided 2026-10-16, pending) | `halt(policy_terminal_block)`, `HALTED`           |
| OTP attempts exhausted and the flow is locked                                    | `halt(credential_locked)`, `HALTED`               |
| Guardrail forbids continuation                                                   | `halt(policy_terminal_block)`, `HALTED`           |
| Wrong OTP, attempts remain                                                       | `rejected`, still `ACTIVE`                        |
| Provider returned a transient error                                              | `rejected` or unchanged, still `ACTIVE` until TTL |
| Database timeout during a transition                                             | Unchanged; the transaction rolls back             |
| Integrity check fails during sign-up finalization                                | `halt(integrity_violation)`, `HALTED`             |

## external_result Contract

`external_result` is the one event for results crossing an external boundary: social and OIDC
provider callbacks, Auth-to-Base ceremony results, and IdP end-session returns to an RP.

```text
external_result(
  source:      boundary identifier (provider, ceremony, or endpoint class),
  outcome:     result reported by the boundary,
  reason_code: normalized detail,
  correlation: state, nonce, transaction id, or equivalent
)
```

Before it can affect lifecycle or phase, the server verifies:

1. Correlation matches the flow and the transaction that issued the request.
2. The flow and the external transaction have not expired.
3. The result has not been consumed; consumption is one-shot.
4. A repeated delivery is treated as replay and changes nothing.

The resulting effect is ordinary: `advance` on an accepted result, `rejected` on a refused one,
`halt` only when the result proves the flow cannot continue. Provider names and success or failure
variants live only in the payload.

## Invariants

### Reachability (no dead ends)

- Every reachable non-terminal phase has a path to a terminal state.
- Cancel is not required everywhere. After an irreversible commit, the remaining paths are
  `complete`, `expire`, and `halt`.
- No user-waiting phase remains `ACTIVE` indefinitely: it has a TTL, a system resolution, or a
  deterministic recovery path.

### Terminal behavior

- Terminal states are absorbing; terminal-to-terminal transitions are forbidden.
- Requests against a terminal flow are observations or replays.

### Concurrency and multi-tab

- Transitions are decided under the flow row lock against re-read state, so the decision and the
  write are serialized, not only the write.
- An authoritative transition is never overwritten by a request based on earlier state; that request
  is `conflict`.
- Version-guarded phases (such as checkpoint) reject a mismatched version as `conflict` with
  `stale_version`.

### Expiry

- Expiry is evaluated before any other mutable transition on the same request.
- Request-time expiry is authoritative; background sweeps only close flows no request reached.
- Expiry does not imply deletion. Retention and purge follow their own schedule.

### Events versus environment

- Browser close and network disconnect are not lifecycle events. An abandoned flow ends by `expire`.
- Infrastructure errors do not automatically produce `HALTED`. A failed transaction leaves the
  previous authoritative state; `halt` follows only when an explicit invariant requires it.

### Audit

- `halt` records its reason code and is auditable.
- `cancel` is recorded as user intent, distinguishable from `halt` and `expire`.

### Side-effect ordering

- Each transition with an irreversible side effect defines whether the side effect happens before,
  inside, or after the state write, and how a replay or crash between them is made idempotent.

## Irreversible Boundaries and Handoff

Shared vocabulary does not merge authority. Auth performs credential ceremonies; Visa owns OIDC
transactions, Root Sessions, and authority tokens, while Base owns its browser RP session
(`adr/visa-op-host.md`).

- **Sign-up finalization to sign-in handoff.** These are two flows. After durable finalization,
  sign-up `back` and `cancel` are unavailable, and nothing in sign-up withdraws the committed
  account. A sign-in failure after handoff belongs to the sign-in flow and never deletes committed
  sign-up data. Ending the sign-up flow after the commit, by any terminal state, must not run
  pending-artifact cleanup against committed data.
- **RP-Initiated Logout.** The RP clears its local grant and session before redirecting. The
  one-time return notice is not an `external_result` to a persisted sign-out flow; OP authority is
  recorded by the stop primitive described in `docs/security/logout-session-management.md`.
- **Provider and OIDC callbacks.** Always `external_result`, never a direct phase write.

## State Storage

Decision: `adr/idp-flow-state-machine-lifecycle.md`. The sign-in and sign-up storage observations
below are historical plan context; the current sign-out amendment reflects D-179 (2) and the
`op_*_authority_stops` implementation.

### Current storage

| Flow table (database)                   | State column           | Reference table                       | FK                                                                        | Duplicate representation                            |
| --------------------------------------- | ---------------------- | ------------------------------------- | ------------------------------------------------------------------------- | --------------------------------------------------- |
| `*_sign_in_flows` (app/com/op_base_org) | `status_id` default 10 | `*_sign_in_flow_statuses` (`id` only) | `NOT VALID`, no action                                                    | `state`, `step` strings tied by `NOT VALID` `CHECK` |
| `*_sign_up_flows` (app/com/op_base_org) | `status_id` default 10 | `*_sign_up_flow_statuses` (`id` only) | `NOT VALID`, `ON DELETE RESTRICT` (client, visitor); no action (operator) | `state`, `step` strings, no `CHECK`                 |

Sign-out has no persisted flow table or kind/status reference table after D-179 (2). Its durable
authority record is the OP authority stop; a browser return notice is a one-use transport capability,
not a sign-out lifecycle. Sign-up reference rows are inserted by request-path `ensure_defaults!`
calls; no migration inserts flow status rows. Direct `status_id` assignments remain outside the
sign-in/sign-up state machines (sign-up OTP controllers, `sign_up_sequence_controller_support`,
sign-up finalizer operations, `SignUpTermination`).

### Target storage

- Each flow row has one authoritative `state_id` (target name; current `status_id`), `NOT NULL`,
  with a validated FK to its own `*_flow_states` reference table in the same database.
- The reference table has only `id`. No name, code, label, lifecycle, terminal flag, ordering,
  enablement, or timestamps. Runtime never joins it.
- Meaning comes from per-flow application constants and the tables below. No lifecycle column and no
  lifecycle-plus-phase FK pair.
- Rows are inserted by migrations, idempotently, before the FK is validated. Seeds and request code
  do not provision them.
- Flow state tables do not use the `NOTHING = 0` sentinel; the default is the start state.

### Integrity layers

| Layer                     | Guarantees                                                | Does not guarantee                                                              |
| ------------------------- | --------------------------------------------------------- | ------------------------------------------------------------------------------- |
| FK to reference table     | State-domain integrity: no unknown state id stored.       | Transition legality (for example `STARTED -> COMPLETED`).                       |
| Application state machine | Transition legality: from-state, event, to-state, guards. | Nothing at the DB level; bypass is prevented by forbidding direct state writes. |
| DB triggers               | Not used for transitions.                                 |                                                                                 |

### State id contract

- Ids are immutable: never reused, never re-meant, never deleted once assigned. Retired ids stay as
  tombstone rows unreachable from code.
- Active phase ids are per-flow namespaces; equal ids across flows mean nothing.
- Shared terminal ids:

| Lifecycle       | Id    | Sign-in today | Sign-up client/visitor today | Sign-up operator today |
| --------------- | ----- | ------------- | ---------------------------- | ---------------------- |
| `COMPLETED`     | `100` | present       | present                      | present                |
| `EXPIRED`       | `910` | absent        | present                      | absent                 |
| `CANCELLED`     | `920` | absent        | present                      | absent                 |
| `HALTED`        | `930` | absent        | absent                       | absent                 |
| legacy `FAILED` | `900` | present       | present                      | absent                 |

`900` stays reserved for legacy `FAILED` and is never reassigned. Active phases use ids below `900`,
never `100`. A renumbering such as `900 COMPLETED / 910 CANCELLED / 920 EXPIRED` is forbidden
because it would change the meaning of existing ids.

### Current active phase ids

| Id  | Sign-in                      | Sign-up client/visitor    | Sign-up operator     |
| --- | ---------------------------- | ------------------------- | -------------------- |
| 10  | `PRIMARY_PENDING`            | `STARTED`                 | `STARTED`            |
| 20  | `MFA_PENDING`                | `CONTACT_PENDING`         | `CONTACT_PENDING`    |
| 30  | `SESSION_LIMIT_PENDING`      | `CREDENTIAL_PENDING`      | `CREDENTIAL_PENDING` |
| 35  |                              | `CONTACT_VERIFIED`        |                      |
| 36  |                              | `SOCIAL_CALLBACK_PENDING` |                      |
| 38  |                              | `GUARDRAIL_PENDING`       |                      |
| 40  | `GUARDRAIL_PENDING`          | `CHECKPOINT_PENDING`      | `CHECKPOINT_PENDING` |
| 50  | `SESSION_ISSUANCE_PENDING`   |                           |                      |
| 60  | `CHECKPOINT_PENDING`         | `FINALIZING`              |                      |
| 65  | `SELECTOR_PENDING`           |                           |                      |
| 70  | `DASHBOARD_PENDING` (retire) | `FINALIZED`               |                      |
| 80  | `RETURN_PENDING` (retire)    | `SIGN_IN_HANDOFF_PENDING` |                      |

These ids keep their meaning in the target. New phases take unused ids below `900`.

### Forbidden transitions (target)

- Any terminal to any active phase, and any terminal to a different terminal.
- `back` across sign-up durable finalization (`FINALIZING` onward) or sign-in session issuance.
- `cancel` after an irreversible commit or authority handoff.
- Any state write that bypasses the flow's transition boundary.
- `halt` from a request parameter or UI action.

## Current-to-Target Mapping

Mappings marked "case by case" depend on the call site. No runtime rename is implied.

| Current term                                                                                                                                   | Where                        | Category today        | Target                                                                                  |
| ---------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------- | --------------------- | --------------------------------------------------------------------------------------- |
| `*_PENDING`, `STARTED`, `CONTACT_VERIFIED`, `FINALIZING`, `FINALIZED`                                                                          | sign-in and sign-up statuses | Status                | Phase under `ACTIVE`                                                                    |
| `status_id`                                                                                                                                    | all flow tables              | Column                | `state_id` (target terminology; rename decided in the plan)                             |
| `*_flow_statuses`                                                                                                                              | reference tables             | Table                 | `*_flow_states` (target terminology; rename decided in the plan)                        |
| `DASHBOARD_PENDING`, `RETURN_PENDING`                                                                                                          | sign-in status               | Legacy status         | Retire; post-auth navigation is not lifecycle                                           |
| `COMPLETED`                                                                                                                                    | all flows                    | Status                | `COMPLETED`                                                                             |
| `CANCELLED`                                                                                                                                    | sign-up status               | Status                | `CANCELLED`                                                                             |
| `EXPIRED`                                                                                                                                      | sign-up status               | Status                | `EXPIRED`                                                                               |
| `EXPIRED`, `CANCELLED`                                                                                                                         | sign-in Mermaid only         | Diagram state         | Target states; not in sign-in runtime                                                   |
| `FAILED` via user cancel (MFA, session limit)                                                                                                  | sign-in                      | Status                | `CANCELLED`                                                                             |
| `FAILED` via `session_limit_hard_reject`                                                                                                       | sign-in                      | Status                | `HALTED`, `policy_terminal_block`                                                       |
| `FAILED` via `fail` event                                                                                                                      | sign-up                      | Status                | Case by case: `HALTED` when unrecoverable; otherwise `rejected` with flow kept `ACTIVE` |
| `fail`, `fail_sign_in!`                                                                                                                       | events and methods           | Event                 | `cancel` or `halt` by cause; never a canonical event                                    |
| `failure`, `credential_failed`                                                                                                                 | `SignInResult`               | Outcome               | `rejected` with a reason code                                                           |
| `credential_rejected`, `identity_unavailable`, `invalid_request`                                                                               | `SignInResult`               | Outcome               | `rejected` with a reason code                                                           |
| `session_limit_hard_reject`, `guardrail_blocked`, `login_forbidden`                                                                            | `SignInResult`               | Outcome               | Reason code; `halt` when the flow cannot continue                                       |
| `transaction_expired`                                                                                                                          | `SignInResult`               | Outcome               | Observation of `EXPIRED`; reason code                                                   |
| `blocked`                                                                                                                                      | `SignUpResult`               | Outcome               | `rejected` (precondition not met)                                                       |
| `invalid_transition`                                                                                                                           | `SignUpResult`               | Outcome               | `rejected`, or `conflict` when caused by state mismatch                                 |
| "checkpoint is stale"                                                                                                                          | `SignUpStateMachine` message | Reason detail         | `conflict` with `stale_version`                                                         |
| `failed` result of a successful `cancel`                                                                                                       | `SignUpStateMachine`         | Outcome (mislabelled) | Observation of `CANCELLED`                                                              |
| `stopped`, `sign_in_handoff_stopped`                                                                                                           | sign-up handoff              | Outcome               | Sign-in phase observation; not a sign-up state. `stopped` is retired                    |
| `sign_in_handoff_failed`                                                                                                                       | sign-up handoff              | Outcome               | Sign-in outcome; sign-up side is undefined today (see plan)                             |
| `locked` OTP or credential                                                                                                                     | ceremonies                   | Resource condition    | Condition; `halt(credential_locked)` when the flow cannot continue                      |
| retry                                                                                                                                          | docs                         | Prose                 | New `advance` attempt, or `replay`, depending on meaning                                |
| stale                                                                                                                                          | docs and messages            | Prose                 | `conflict`; `stale_version` reason code                                                 |
| reenter, re-entry                                                                                                                              | docs                         | Prose                 | `reentry`                                                                               |
| social or provider callback success or failure                                                                                                 | callbacks                    | Prose                 | `external_result` with `outcome` in the payload                                         |
| suspended (`SignUpSuspension`)                                                                                                                 | registration kill switch     | Surface availability  | Not lifecycle; a `start` precondition                                                   |
| canceled (American spelling)                                                                                                                   | step-up ceremony transaction | Ceremony status       | Out of scope; separate ceremony lifecycle                                               |

## Related

- `adr/idp-flow-lifecycle-vocabulary.md`
- `adr/idp-flow-state-machine-lifecycle.md`
- `plans/backlog/idp-flow-state-machine-unification.md`
- `docs/security/sign-in-sequence.md`
- `docs/security/sign-up-sequence.md`
- `docs/security/logout-sequence.md`
- `docs/security/sign-in-compensation.md`
- `docs/security/sign-up-compensation.md`
- `adr/sign-up-cycle-cancellation-retention.md`

## Strict sign-in phase admission (implemented slice, 2026-10-10)

The sign-in phase-regression protection is a narrow runtime amendment to the lifecycle vocabulary.
It does not replace the credential-family authority objects or make browser history a lifecycle
event.

For local sign-in flows that use the shared sign-in flow row, the server-generated phase binding
contains the flow public identifier, the expected phase, an immutable flow-generation value, and the
surface. It is purpose-bound and signed by the application. The binding does not expose the locator
nonce, a raw database id, or a client-chosen phase. The flow row, actor binding, expiry, and
session-issuance boundary remain authoritative; the binding is an additional admission check.
Since the entry-less Local Sign-in Flow was removed (D-60, 2026-10-23), every sign-in runs under an
OIDC authorization parent and the flow row exists only once primary authentication names its
principal. Primary-phase requests therefore carry no binding; the check passes only when neither a
current flow nor a binding is present, and a supplied binding without a current flow is refused.

Same-phase reload and re-entry are allowed. A GET or HEAD request whose binding is missing,
malformed, expired, for another surface or flow, or for a different phase is refused with HTTP
`409 Conflict`, `text/plain`, and the exact body `この画面は古くなっています。最初からやり直してください。`. The refusal does not redirect,
change lifecycle state, issue an OTP or challenge, create a session, or perform another workflow
side effect. The authentication no-store response policy remains in force. A GET refusal is an
observation and is not a lifecycle transition.

For a state-changing request that was bound to an attributable flow instance but assumes a phase
that is no longer authoritative, the server locks and reloads that original flow and applies the
system-only `halt` transition with reason `phase_regression` or `phase_violation`. The flow enters
`HALTED = 930`; the terminal state is absorbing, cannot be revived or moved to another terminal, and
cannot issue a session, OTP, challenge, or provider transaction. A request from old flow A must
never halt the current flow B. A missing or invalid binding is refused without using the current
session locator as a substitute authority.

The existing Auth ceremony/Base session-issuance boundary is unchanged. Email OTP, passkey, MFA, and
the local app/com sign-in routes use this binding where a local `SignInFlow` is the authoritative
phase object. Social callbacks, org Entra, and other credential families retain their existing
provider state or concrete ceremony transaction as the primary authority when no local sign-in flow
is present; they are not forced into a universal flow object. The existing `commit_login_session!`
and `lock_sign_in_flow_for_issuance!` checks remain the final session issuance boundary.

This amendment covers the runtime paths and tests changed in the current implementation slice.
Untouched ceremony axes remain governed by their existing concrete authority until their own
implementation slice is completed. The acceptance criteria in
`docs/checklists/authentication-flow-integrity.md` define the observable contract; a test result or
implementation report is evidence for a particular revision, not a permanent pass.

## Delivered reconciliation (2026-10-06)

The current runtime now uses the migration-owned state reference and named transition surface for
the changed sign-in, sign-up and sign-out axes. Terminal facts are absorbing; expiry uses the owning
database clock; session-limit resolution is a durable child transaction; sign-up completion enters
ordinary sign-in admission; and sign-out records mutation progress without claiming access-token
retirement. The old commit-specific “target not implemented” reading rule above is superseded.
