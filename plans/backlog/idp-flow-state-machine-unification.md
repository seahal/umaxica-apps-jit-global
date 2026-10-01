# IdP Flow State-Machine Unification

Status: backlog. Not accepted for implementation; no runtime change has been made.

## Purpose

Migrate sign-in, sign-up, and sign-out to the lifecycle vocabulary and invariants accepted in
`adr/idp-flow-lifecycle-vocabulary.md`, one flow at a time. The reference and the current-to-target
mapping are in `docs/security/idp-flow-lifecycle.md`; this plan does not repeat them.

The goal is a shared lifecycle contract with flow-specific phases preserved. A single merged sign
state machine and a big-bang rewrite are explicitly out of scope.

## Current Inventory Summary

| Flow     | Records                                    | Terminal statuses today                       | Transition owner                                              |
| -------- | ------------------------------------------ | --------------------------------------------- | ------------------------------------------------------------- |
| Sign-in  | `Client`/`Visitor`/`OperatorSignInFlow`    | `COMPLETED`, `FAILED`                         | `FlowSignIn` methods called from controllers and services     |
| Sign-up  | `Client`/`VisitorSignUpFlow` (`Operator` partial) | `COMPLETED`, `FAILED`, `EXPIRED`, `CANCELLED` | `SignUpStateMachine`, `SignUpTermination`, `SignUpExpiryJob` |
| Sign-out | `Client`/`Visitor`/`OperatorSignOutFlow`   | `COMPLETED`, `FAILED`                         | `FlowSignOut` methods in the logout primitive                 |

Gaps found during the vocabulary audit (each must be confirmed by a failing test before any fix):

1. Sign-in records user cancellation (pending MFA, session-limit page, `SignInSessionLimitManager#cancel!`)
   as `FAILED`, indistinguishable from `session_limit_hard_reject`.
2. Sign-in has no recorded expiry terminal; expired cycles stay in their pending status and are
   refused at request time.
3. Sign-up `cancel` returns `SignUpResult` status `failed` from the state machine.
4. Sign-up `FINALIZING`, `FINALIZED`, and `SIGN_IN_HANDOFF_PENDING` have no `EXPIRED` edge, while
   `SignUpExpiryJob` selects every in-progress status including these. Expected effect: the sweep
   logs a skip or failure for such rows on every run. Not yet reproduced.
5. `handoff_to_sign_in` with `:stopped` or `:failed` returns a result but leaves the ticket in
   `FINALIZED`, so the post-commit terminal path is undefined.
6. Sign-out marks `FAILED` on any exception, including transient infrastructure errors, after
   access may already have been discarded.
7. Sign-in and sign-out Mermaid diagrams draw states or edges that runtime lacks
   (`EXPIRED`/`CANCELLED` in sign-in, `TOKEN_REVOKED` in sign-out, checkpoint directly to session
   issuance in sign-in).

## Migration Ordering

Each step is independently shippable and reversible. Later steps do not start until the earlier
step's tests are green in CI.

1. **Contract and graph tests, no behavior change.** Introduce a read-only lifecycle classifier
   that maps every current status to lifecycle plus phase, and graph tests over each flow's
   `TRANSITIONS` table (see Testing). Tests that encode current gaps are added as the gap is
   scheduled, not as skipped tests.
2. **Sign-up first.** It already has three non-success terminals and a central state machine.
   Fix the cancel result status, define post-commit terminal behavior (gaps 4 and 5), and split
   `fail` call sites into `halt` with reason codes versus `rejected`.
3. **Sign-in second.** Add a cancellation terminal and an expiry terminal, reclassify existing
   `fail_sign_in!` callers by cause, and retire `DASHBOARD_PENDING` and `RETURN_PENDING` once no
   live row uses them.
4. **Sign-out last.** Classify `FAILED` for logout, where fail-closed revocation semantics make the
   choice security-relevant (see Open Questions).
5. **Diagrams and docs.** Update Mermaid diagrams for each flow in the same change that ships its
   runtime migration, and remove the "current runtime vocabulary" notes once they no longer apply.

## Shared Lifecycle Contract

- A small shared value or module exposes lifecycle classification (`active?`, `terminal?`,
  `lifecycle`), the canonical event set, and the outcome set. It holds no flow-specific phases.
- Each flow keeps its own phase list, transition table, and internal event names, and declares
  which internal events classify as `advance` or `back`.
- `complete`, `expire`, `halt`, and `cancel` go through one terminal entry point per flow (as
  `SignUpTermination` does today) so retention, cleanup, and audit are not skipped.
- Class placement follows `project/value-object-boundaries.mdc`.

## FAILED Classification Strategy

For each call site that reaches `FAILED`, classify by cause:

| Cause                                                  | Target                                    |
| ------------------------------------------------------ | ----------------------------------------- |
| Explicit user action to stop                           | `cancel` to `CANCELLED`                   |
| Policy or security forbids continuing                  | `halt` to `HALTED` with reason code       |
| Integrity check failed after partial work              | `halt(integrity_violation)`               |
| Validation, credential mismatch, transient error       | `rejected`; flow stays `ACTIVE`           |
| Concurrent state change                                | `conflict`; flow stays `ACTIVE`           |

The same table applies to `stopped`, `hard_reject`, `blocked`, `failure`, and `fail`. Existing
`FAILED` rows remain as historical records; they are not rewritten to `HALTED`.

## external_result Normalization

- Route social callbacks, Auth-to-Base ceremony results, and IdP end-session returns through one
  `external_result` entry per flow that verifies correlation, expiry, one-shot consumption, and
  replay before any phase change.
- Keep existing ceremony consumers and committers as the verification mechanism; the change is
  classification and a single entry point, not new crypto or transport.

## Concurrency, Replay, and Reentry

- **Conflict.** Generalize the checkpoint-version guard: each mutating request names the phase (and
  version, where one exists) it assumes. Mismatch returns `conflict` with `stale_version` and never
  rolls back state.
- **Replay.** Each terminal and side-effecting transition records enough to recognize a repeat
  (status already reached, consumed result id, completed sign-out within its window) and returns
  the original observation.
- **Reentry.** GET handlers resolve the flow from the authoritative record, evaluate expiry first,
  then render the current phase. No GET advances a phase.
- **Side-effect ordering.** For each transition with an irreversible side effect, document and test
  whether the side effect runs before, inside, or after the state write, and how a crash between
  them is recovered without duplication.

## Terminal and Reachability Invariants

- Terminal statuses have empty outbound sets.
- Every non-terminal status reaches a terminal status in the transition graph.
- Every non-terminal status that waits on the user has a TTL-driven or system-driven exit.
- Post-commit phases have no `cancel` or `back` edge and their terminal transitions do not run
  pending-artifact cleanup against committed data.

## Testing

All tests exercise public interfaces per `generic/testing.mdc` and `AGENTS.md` section H.

- **Graph validation.** For each flow class: terminal statuses absorb; every non-terminal status
  reaches a terminal; no terminal-to-terminal or terminal-to-active edge; post-commit statuses
  have no cancel edge.
- **Model-based tests.** Generate event sequences from the transition table and assert that each
  accepted event keeps the invariants and each refused event leaves state unchanged.
- **Multi-tab.** Two requests on the same flow with the same assumed phase: exactly one advances,
  the other gets `conflict`, and authoritative state matches the winner.
- **Replay.** Double-submitted cancel, finalize, external result, and logout produce one side
  effect and a stable observation.
- **Expiry boundary.** At `expires_at` minus the smallest representable step, exactly at
  `expires_at`, and just after, for request-time checks and the sweep job.
- **external_result.** Wrong correlation, expired transaction, second delivery, and a delivery for a
  different flow are each refused without phase change.
- **back, cancel, halt boundaries.** `back` invalidates later one-time artifacts; cancel is refused
  after commit; `halt` is unreachable from request parameters; infrastructure exceptions do not
  produce `HALTED`.

## Rollback and Compatibility

- Each flow migrates behind its own change; reverting that change restores previous behavior
  because existing status ids are not renumbered or reused.
- New reference rows (for example a `HALTED` or a sign-in `CANCELLED` status) are additive. During
  the compatibility period, readers treat both legacy `FAILED` and new terminal statuses as
  terminal.
- The compatibility period ends for a flow when no non-terminal rows predating the migration
  remain, bounded by that flow's TTL and retention window. Its end is recorded in the flow's docs.

## Open Questions for the Implementation Phase

- Physical representation: keep one status column with a lifecycle mapping, or split lifecycle and
  phase columns.
- Whether to add `HALTED` as a new status id or reinterpret `FAILED` for new rows only; how audit
  and reporting distinguish legacy `FAILED`.
- Reason-code storage: column, audit record only, or both; initial reason-code set.
- Sign-up post-commit terminal: whether durable finalization plus accepted handoff is sign-up
  `COMPLETED`, and what the sign-up flow records when the sign-in side stops or fails.
- Sign-out failure: which logout failures, if any, are `HALTED` versus left for retry, given that
  access discard is irreversible and revocation must fail closed.
- Whether sign-in should record `EXPIRED` on reentry, in a sweep, or both.
- Whether org operator sign-up adopts the contract or stays on its invitation lifecycle.
- Migration ordering of `DASHBOARD_PENDING` and `RETURN_PENDING` retirement relative to live rows.

## Related

- `adr/idp-flow-lifecycle-vocabulary.md`
- `docs/security/idp-flow-lifecycle.md`
- `plans/backlog/sign-up-failure-recovery-plan.md`
- `plans/backlog/sign-in-failure-handling-plan.md`
- `adr/sign-up-cycle-cancellation-retention.md`
