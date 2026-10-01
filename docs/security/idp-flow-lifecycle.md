# IdP Flow Lifecycle

This document is the reference for lifecycle vocabulary across sign-in, sign-up, and sign-out. The
decision is `adr/idp-flow-lifecycle-vocabulary.md`; the migration is planned in
`plans/backlog/idp-flow-state-machine-unification.md`.

> **Reading rule:** The "Current runtime" sections describe code as of commit `91974b8b0`. The
> "Target" sections describe accepted vocabulary that runtime does **not** yet implement. Never
> read a target term (`ACTIVE`, `HALTED`, `external_result`, and so on) as an existing status,
> event, or column.

## Term Categories

Every term used about these flows belongs to exactly one category.

| Category           | What it is                                                                                    | Examples (target)                                     |
| ------------------ | --------------------------------------------------------------------------------------------- | ----------------------------------------------------- |
| Lifecycle state    | Coarse, flow-independent position of a flow instance.                                        | `ACTIVE`, `COMPLETED`, `CANCELLED`, `EXPIRED`, `HALTED` |
| Phase              | Flow-specific position while `ACTIVE`.                                                       | `MFA_PENDING`, `CHECKPOINT_PENDING`, `ACCESS_DISCARDED` |
| Transition event   | Something that may change lifecycle or phase.                                                | `start`, `advance`, `back`, `cancel`, `external_result`, `complete`, `expire`, `halt` |
| Request semantics  | How the server classifies an arriving request before or instead of a transition.             | `reentry`, `replay`, `conflict`                       |
| Condition          | A predicate evaluated on the request or flow.                                                 | TTL lapsed, checkpoint version matches, actor already signed in |
| Transition outcome | What one request achieved.                                                                    | `advanced`, `rejected`, `conflict`, `replay`          |
| Reason code        | Implementation detail explaining an outcome or a halt.                                        | `credential_locked`, `stale_version`, `credential_mismatch` |

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
  `session_limit_hard_reject` after primary verification, and `SignInSessionLimitManager#cancel!`.
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
- `SignUpStateMachine` events: `start`, `submit_contact`, `verify_contact`,
  `start_social_callback`, `complete_social_callback`, `enter_guardrail`, `enter_checkpoint`,
  `clear_requirement`, `finalize`, `handoff_to_sign_in`, `complete`, `fail`, `expire`, `cancel`.
- Result statuses (`SignUpResult`): `ok`, `advanced`, `blocked`, `invalid_transition`,
  `unauthorized`, `expired`, `failed`, `completed`, `sign_in_handoff_accepted`,
  `sign_in_handoff_stopped`, `sign_in_handoff_failed`. A successful `cancel` reports `failed` from
  the state machine and `ok` from `SignUpTermination`.
- Cancel is allowed before `FINALIZING` only (`adr/sign-up-cycle-cancellation-retention.md`).
  `FINALIZING`, `FINALIZED`, and `SIGN_IN_HANDOFF_PENDING` have only `FAILED` (and the next phase)
  as outbound edges; they have no `EXPIRED` edge.
- `clear_requirement` rejects a mismatched `checkpoint_version` as `invalid_transition` with
  message "checkpoint is stale".
- `SignUpTermination` drives `cancel`, `expire`, and `fail`, then schedules retention and artifact
  cleanup. `SignUpExpiryJob` sweeps in-progress rows past `expires_at`.

### Sign-out

Records: `ClientSignOutFlow`, `VisitorSignOutFlow`, `OperatorSignOutFlow` with `FlowSignOut`.

- Statuses: `NOTHING`, `REQUESTED`, `ACCESS_DISCARDED`, `LOGICALLY_REVOKED`, `AWAITING_EXPIRY`,
  `COMPLETED`, `FAILED`. Kinds: `IDP_SIGN_OUT`, `RP_INITIATED`, `SESSION_REVOKE`.
- The current-session logout runs every phase in one request. Any exception marks the flow
  `FAILED` and re-raises. A completed flow for the same token within five minutes short-circuits a
  repeated logout.
- There is no cancellation phase. Not submitting the confirmation page simply never starts a flow.
- The sign-out Mermaid diagrams are marked deprecated and name `TOKEN_REVOKED` where runtime uses
  `LOGICALLY_REVOKED`.

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

| State       | Entered by | Meaning                                                                         |
| ----------- | ---------- | ------------------------------------------------------------------------------- |
| `COMPLETED` | `complete` | The flow finished normally.                                                     |
| `CANCELLED` | `cancel`   | The user explicitly ended the flow.                                             |
| `EXPIRED`   | `expire`   | The authoritative clock or TTL ended the flow.                                  |
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
| `external_result` | External boundary via callback | Feeds a correlated external result into the flow.               |
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

| Outcome    | Meaning                                                | Lifecycle effect |
| ---------- | ------------------------------------------------------ | ---------------- |
| `advanced` | The event was accepted.                                 | As per the event |
| `rejected` | The operation was not accepted.                         | Unchanged        |
| `conflict` | The request was based on non-authoritative state.       | Unchanged        |
| `replay`   | The request repeated already-processed work.            | Unchanged        |

An outcome is never a lifecycle state. A rejected credential leaves the flow `ACTIVE`; a halted
flow is `HALTED` regardless of how the triggering request is reported.

## Examples

### Reentry, replay, and conflict

- **Reload during MFA.** The flow is `ACTIVE / MFA_PENDING`. Reload is reentry: expiry is checked,
  then the MFA page renders again. No challenge is re-issued unless the phase defines that.
- **Reload after TTL.** Reentry evaluates expiry first, fires `expire`, and the flow becomes
  `EXPIRED`. The user is told to start again.
- **Double-submitted cancel.** The first request cancels; the second is replay and returns the
  same observation without re-running cleanup.
- **Two tabs at checkpoint.** Tab A clears the passkey requirement and the checkpoint version
  increments. Tab B submits the old version. Tab B gets `conflict` with `reason_code =
  stale_version`; tab A's work stands, and tab B reenters the current checkpoint.
- **Finalize raced by a second request.** The row lock admits one finalization. The second request
  is `conflict` (or `replay` when it is the same request) and creates no second identity graph.

### Cancellation versus halt

| Situation                                                      | Target classification                                 |
| -------------------------------------------------------------- | ----------------------------------------------------- |
| User presses cancel on pending MFA                             | `cancel`, `CANCELLED`                                 |
| User cancels on the session-limit page                         | `cancel`, `CANCELLED`                                 |
| Session limit cannot be resolved by policy (hard reject)       | `halt(policy_terminal_block)`, `HALTED`               |
| OTP attempts exhausted and the flow is locked                  | `halt(credential_locked)`, `HALTED`                   |
| Guardrail forbids continuation                                 | `halt(policy_terminal_block)`, `HALTED`               |
| Wrong OTP, attempts remain                                     | `rejected`, still `ACTIVE`                            |
| Provider returned a transient error                            | `rejected` or unchanged, still `ACTIVE` until TTL     |
| Database timeout during a transition                           | Unchanged; the transaction rolls back                 |
| Integrity check fails during sign-up finalization              | `halt(integrity_violation)`, `HALTED`                 |

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
- An authoritative transition is never overwritten by a request based on earlier state; that
  request is `conflict`.
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

Shared vocabulary does not merge authority. Auth performs credential ceremonies; Base owns OIDC
transactions, sessions, and tokens (`adr/base-auth-ceremony-and-seven-rp-boundary.md`).

- **Sign-up finalization to sign-in handoff.** These are two flows. After durable finalization,
  sign-up `back` and `cancel` are unavailable, and nothing in sign-up withdraws the committed
  account. A sign-in failure after handoff belongs to the sign-in flow and never deletes committed
  sign-up data. Ending the sign-up flow after the commit, by any terminal state, must not run
  pending-artifact cleanup against committed data.
- **Sign-out access discard.** After `ACCESS_DISCARDED`, the browser cannot perform authenticated
  writes again. No later step re-grants access, and the flow cannot go back.
- **RP to IdP logout.** The RP clears its local session before redirecting; the IdP return is an
  `external_result` to the RP flow.
- **Provider and OIDC callbacks.** Always `external_result`, never a direct phase write.

## Current-to-Target Mapping

Mappings marked "case by case" depend on the call site. No runtime rename is implied.

| Current term                                     | Where                                      | Category today        | Target                                                                                       |
| ------------------------------------------------ | ------------------------------------------ | --------------------- | -------------------------------------------------------------------------------------------- |
| `*_PENDING`, `STARTED`, `CONTACT_VERIFIED`, `FINALIZING`, `FINALIZED`, `REQUESTED`, `ACCESS_DISCARDED`, `LOGICALLY_REVOKED`, `AWAITING_EXPIRY` | flow statuses | Status | Phase under `ACTIVE` |
| `NOTHING`                                        | sign-out status                            | Status sentinel       | Not a lifecycle state; pre-`start`                                                           |
| `DASHBOARD_PENDING`, `RETURN_PENDING`            | sign-in status                             | Legacy status         | Retire; post-auth navigation is not lifecycle                                                |
| `COMPLETED`                                      | all flows                                  | Status                | `COMPLETED`                                                                                  |
| `CANCELLED`                                      | sign-up status                             | Status                | `CANCELLED`                                                                                  |
| `EXPIRED`                                        | sign-up status                             | Status                | `EXPIRED`                                                                                    |
| `EXPIRED`, `CANCELLED`                           | sign-in Mermaid only                       | Diagram state         | Target states; not in sign-in runtime                                                        |
| `FAILED` via user cancel (MFA, session limit)    | sign-in                                    | Status                | `CANCELLED`                                                                                  |
| `FAILED` via `session_limit_hard_reject`         | sign-in                                    | Status                | `HALTED`, `policy_terminal_block`                                                            |
| `FAILED` via `fail` event                        | sign-up                                    | Status                | Case by case: `HALTED` when unrecoverable; otherwise `rejected` with flow kept `ACTIVE`      |
| `FAILED` via exception during logout             | sign-out                                   | Status                | Case by case: operational failure is not `HALTED`; open question in the plan                 |
| `fail`, `fail_sign_in!`, `fail_sign_out!`        | events and methods                         | Event                 | `cancel` or `halt` by cause; never a canonical event                                         |
| `failure`, `credential_failed`                   | `SignInResult`                             | Outcome               | `rejected` with a reason code                                                                |
| `credential_rejected`, `identity_unavailable`, `invalid_request` | `SignInResult`             | Outcome               | `rejected` with a reason code                                                                |
| `session_limit_hard_reject`, `guardrail_blocked`, `login_forbidden` | `SignInResult`          | Outcome               | Reason code; `halt` when the flow cannot continue                                            |
| `transaction_expired`                            | `SignInResult`                             | Outcome               | Observation of `EXPIRED`; reason code                                                        |
| `blocked`                                        | `SignUpResult`                             | Outcome               | `rejected` (precondition not met)                                                            |
| `invalid_transition`                             | `SignUpResult`                             | Outcome               | `rejected`, or `conflict` when caused by state mismatch                                      |
| "checkpoint is stale"                            | `SignUpStateMachine` message               | Reason detail         | `conflict` with `stale_version`                                                              |
| `failed` result of a successful `cancel`         | `SignUpStateMachine`                       | Outcome (mislabelled) | Observation of `CANCELLED`                                                                   |
| `stopped`, `sign_in_handoff_stopped`             | sign-up handoff                            | Outcome               | Sign-in phase observation; not a sign-up state. `stopped` is retired                         |
| `sign_in_handoff_failed`                         | sign-up handoff                            | Outcome               | Sign-in outcome; sign-up side is undefined today (see plan)                                  |
| `locked` OTP or credential                       | ceremonies                                 | Resource condition    | Condition; `halt(credential_locked)` when the flow cannot continue                           |
| retry                                            | docs                                       | Prose                 | New `advance` attempt, or `replay`, depending on meaning                                     |
| stale                                            | docs and messages                          | Prose                 | `conflict`; `stale_version` reason code                                                      |
| reenter, re-entry                                | docs                                       | Prose                 | `reentry`                                                                                    |
| social or provider callback success or failure   | callbacks                                  | Prose                 | `external_result` with `outcome` in the payload                                              |
| suspended (`SignUpSuspension`)                   | registration kill switch                   | Surface availability  | Not lifecycle; a `start` precondition                                                        |
| canceled (American spelling)                     | step-up ceremony transaction               | Ceremony status       | Out of scope; separate ceremony lifecycle                                                    |

## Related

- `adr/idp-flow-lifecycle-vocabulary.md`
- `plans/backlog/idp-flow-state-machine-unification.md`
- `docs/security/sign-in-sequence.md`
- `docs/security/sign-up-sequence.md`
- `docs/security/logout-sequence.md`
- `docs/security/sign-in-compensation.md`
- `docs/security/sign-up-compensation.md`
- `adr/sign-up-cycle-cancellation-retention.md`
