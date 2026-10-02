# IdP Flow Lifecycle Vocabulary

## Status

Accepted (2026-10-01) as documentation and target vocabulary.

Implementation status: the vocabulary and invariants in this ADR are accepted. Runtime migration has
**not** been performed. Current sign-in, sign-up, and sign-out code still uses its own status names,
events, and result statuses (including `FAILED`). Nothing in this ADR claims that runtime already
uses `ACTIVE`, `HALTED`, or the canonical event names. The future migration is planned in
`plans/backlog/idp-flow-state-machine-unification.md`; the reference and current-to-target mapping
live in `docs/security/idp-flow-lifecycle.md`.

## Context

Sign-in, sign-up, and sign-out each have a DB-backed flow record with a status column and a
transition table (`*SignInFlow`, `*SignUpFlow`, `*SignOutFlow`), plus service-level result types
(`SignInResult`, `SignUpResult`, `LogoutResult`). They grew independently, so the same idea is
spelled differently and the same word means different things:

- `FAILED` is the only terminal non-success status in sign-in and sign-out, so it absorbs user
  cancellation (sign-in session-limit cancel calls `fail_sign_in!`), policy blocks, and operational
  failures alike.
- Sign-up has `FAILED`, `EXPIRED`, and `CANCELLED`, but a successful `cancel` returns
  `SignUpResult` status `:failed`.
- Sign-in has no `EXPIRED` or `CANCELLED` status; expiry is a request-time `expires_at` check. The
  sign-in Mermaid diagrams nevertheless draw both states.
- Request outcomes (`credential_rejected`, `session_limit_hard_reject`, `blocked`,
  `invalid_transition`, `sign_in_handoff_stopped`) sit next to lifecycle statuses and are easy to
  read as states.
- "retry / replay" and "stale / conflict" are used as interchangeable pairs.

Shared lifecycle management for these flows needs one vocabulary first. Without it, a shared
contract would either merge flow-specific phases into one large machine or encode today's
ambiguities permanently.

## Decision

### Scope

This ADR governs the lifecycle vocabulary and invariants of end-user authentication flows:
sign-in, sign-up, and sign-out on the `app`, `com`, and `org` surfaces, including the sign-up to
sign-in handoff. It applies to future shared lifecycle code, new documentation, and new tests.

### Non-goals

- No runtime, schema, migration, route, controller, service, or test change is made or authorized
  by this ADR.
- No single unified sign state machine. Only the lifecycle contract, terminology, and invariants
  are shared.
- No renaming of flow-specific phases. Sign-in keeps primary, MFA, session limit, guardrail,
  checkpoint, selector, and session issuance; sign-up keeps identity, contact, credential,
  guardrail, checkpoint, finalization, and handoff; sign-out keeps requested, access discard,
  revoke, and expiry wait.
- No suspension semantics. `resume` is not a lifecycle term. The existing `SignUpSuspension`
  registration kill switch is a surface availability control, not a flow lifecycle state.
- Withdrawal, OIDC authorization transactions, step-up, and per-credential ceremony transactions
  keep their own lifecycles. They may adopt this vocabulary later through separate decisions.
- The physical representation (one status column, split lifecycle and phase columns, or a mapping)
  is not decided here. It was later decided in `adr/idp-flow-state-machine-lifecycle.md`: one
  authoritative state id per flow row with an FK to an id-only per-flow reference table, and no
  lifecycle column.

### Lifecycle versus phase

Every flow instance has a logical **lifecycle** and, while active, a flow-specific **phase**:

```text
lifecycle = ACTIVE
phase     = CHECKPOINT_PENDING
```

The canonical lifecycle values are `ACTIVE`, `COMPLETED`, `CANCELLED`, `EXPIRED`, and `HALTED`.
Phase is meaningful only while the lifecycle is `ACTIVE`. Phase names stay flow-specific and are
not unified across flows.

### Canonical terminal states

Exactly four terminal lifecycle states exist:

| State       | Meaning                                                                                                      |
| ----------- | ------------------------------------------------------------------------------------------------------------ |
| `COMPLETED` | The flow finished normally.                                                                                  |
| `CANCELLED` | The user ended the flow by explicit intent.                                                                  |
| `EXPIRED`   | The flow's validity period ended according to the authoritative clock or TTL.                                |
| `HALTED`    | The system irreversibly ended the flow because continuing is unsafe, inconsistent, or forbidden by policy. |

Terminal states are absorbing. No transition leads from a terminal state to `ACTIVE` or to another
terminal state.

### Canonical transition events

The lifecycle event vocabulary is exactly:

```text
start  advance  back  cancel  external_result  complete  expire  halt
```

- `start` creates a new flow instance. It is used even where runtime creates the record outside
  the state machine. `begin`, `initialize`, and `open` are not lifecycle synonyms.
- `advance` moves forward after the current phase's conditions are met. Flow-internal domain events
  (`verify_contact`, `clear_requirement`, `advance_sign_in_to_selector!`, and so on) remain valid
  internal names and are classified as `advance`. `proceed` is not a canonical term.
- `back` returns to an earlier phase only when the flow explicitly allows that edge. It is not the
  browser Back button. When `back` leaves a phase that issued a one-time challenge, token, or
  nonce, that artifact is invalidated as part of the transition. `back` never crosses an
  irreversible commit or authority handoff.
- `cancel` is the user's explicit decision to end the flow and produces `CANCELLED`. The system
  never emits `cancel`. It is idempotent where possible. It never reverts a commit that already
  happened.
- `external_result` is the single term for receiving the result of an external boundary. See below.
- `complete` produces `COMPLETED`. It is an internal transition fired by the flow orchestrator when
  completion conditions hold, never a client-selectable terminal state.
- `expire` produces `EXPIRED` from the authoritative clock. Expiry is distinct from retention,
  logical discard, purge, and physical deletion.
- `halt` produces `HALTED`. It is system-only, requires a `reason_code` (for example
  `credential_locked`, `integrity_violation`, `policy_terminal_block`; the full set is left to
  implementation), and is auditable. No UI action or request parameter can request `halt`.
  Database timeouts, transient provider errors, and other operational failures do not halt a flow
  automatically.

### external_result single-term rule

`external_result` is the only lifecycle event for results that cross an external boundary
(social or OIDC provider callback, cross-surface ceremony result, RP to IdP logout return).
Provider, protocol, and ceremony differences live in the payload:

```text
external_result(source:, outcome:, reason_code:, correlation:)
```

`external_success`, `external_failure`, `provider_result`, `provider_callback_result`,
`callback_success`, `callback_failure`, and provider names (Google, Apple, Entra, OIDC) are not
lifecycle events. Every `external_result` is correlation-validated, expiry-checked, consumed once,
and replay-resistant before it can affect lifecycle or phase.

### reentry, replay, and conflict

These are request semantics, not transition events.

- **reentry** (replaces `reenter`): a request reaches an existing `ACTIVE` flow through reload,
  bookmark, or returning from another page. The server re-resolves the authoritative state. It does
  not move phase by itself, but expiry is evaluated first, so `reentry` can result in `expire`.
- **replay** (replaces "retry / replay"): an already-processed mutation or event arrives again in the
  same or substantially the same form. Replay never repeats side effects. `retry` is not
  state-machine vocabulary. A user submitting a new credential value after a mismatch is a new
  `advance` attempt, not a replay.
- **conflict** (replaces "stale / conflict"): the request's assumed flow state differs from the
  authoritative state (multi-tab, concurrent request, outdated checkpoint version, another request
  already advanced or completed the flow). Conflict never rolls back authoritative state, and the
  user can always be brought to the current state through reentry. `stale` survives only as a
  reason code, for example `conflict` with `reason_code = stale_version`.

### Outcomes and reason codes

A request produces a **transition outcome** that is separate from lifecycle state:

- `rejected`: the requested operation was not accepted; the lifecycle normally stays unchanged.
  Credential mismatch, validation failure, and refused preconditions are `rejected`.
- `conflict` and `replay` are also outcomes when a request is classified as such.

`lock` and `locked` are not lifecycle events. They describe a credential, account, or resource. When
a lock makes the current flow permanently non-continuable, the flow takes
`halt(reason_code: credential_locked)` and becomes `HALTED`.

Reason codes carry implementation-specific detail. They never become lifecycle states or events.

### Legacy vocabulary mapping policy

`FAILED` is not a canonical terminal state. The following runtime names remain until migrated and
are classified, not mechanically renamed:

| Situation                                          | Target classification                                            |
| -------------------------------------------------- | ---------------------------------------------------------------- |
| User intentionally ends the flow                   | `cancel` and `CANCELLED`                                         |
| System declares the flow permanently non-continuable | `halt` and `HALTED` with a reason code                         |
| Request refused, flow still active                 | `rejected` outcome, lifecycle unchanged                          |
| Authoritative state changed concurrently           | `conflict` outcome, lifecycle unchanged                          |
| Temporary operational failure                      | lifecycle unchanged unless an explicit invariant requires `halt` |

`FAILED` maps to `HALTED` only where it means unrecoverable, non-resumable, terminal. `stopped`,
`failure`, `fail`, `hard_reject`, `credential_rejected`, `blocked`, and `rejected` are classified
case by case by the same rules. `stopped` is removed from the future lifecycle vocabulary.

The following are never introduced as lifecycle states or events: `SUSPENDED`, `RESUMED`,
`STOPPED`, `FAILED`, `REJECTED`, `LOCKED`, `RETRY`, `STALE`, `ABORTED`, `external_success`,
`external_failure`, `provider_result`, `callback_result`. Existing runtime occurrences are recorded
as legacy vocabulary.

### Authority and handoff boundaries

Shared vocabulary does not merge authority. These boundaries stay explicit:

- Auth (historically `sign/id`) performs credential ceremonies; Base (historically `acme/www`)
  owns the OIDC transaction, browser session, RP session, and tokens, per
  `adr/base-auth-ceremony-and-seven-rp-boundary.md`.
- Sign-up durable finalization followed by sign-in handoff are two flows. Once sign-up has durably
  committed an account, no `back` or `cancel` in sign-up withdraws it, and a sign-in failure after
  handoff is a sign-in matter that does not delete committed sign-up data.
- RP-initiated logout to the IdP end-session endpoint, and provider or OIDC callbacks, are external
  boundaries reached only through `external_result`.

### Invariants

The following are normative for any future shared lifecycle implementation:

1. Every reachable non-terminal phase has a path to some terminal state. Cancel need not be
   available from every phase; phases after an irreversible commit may only complete, expire, or
   halt.
2. No user-waiting phase stays `ACTIVE` indefinitely. It has a TTL, a system resolution, or a
   deterministic recovery path.
3. Terminal states are absorbing, and terminal-to-terminal transitions are forbidden.
4. Browser close and network disconnect are not lifecycle events.
5. Browser history navigation is not `back`.
6. Reentry re-resolves authoritative server state.
7. Replay does not re-execute side effects.
8. Conflict does not roll back authoritative state.
9. Under multi-tab use, a transition that is already authoritative is not destroyed by a later
   request based on older state.
10. Expiry can be evaluated before any other mutable transition on the same request.
11. `external_result` is correlated, expiry-bound, one-shot, and replay-resistant.
12. Infrastructure errors do not automatically produce `HALTED`.
13. `halt` is system-only, carries a reason code, and is auditable.
14. `cancel` is distinguishable as user intent in audit records.
15. `back` never leaves a later phase's one-time artifact reusable.
16. Ordering and idempotency between a state transition and its irreversible side effects are
    acceptance criteria for implementation.

## Consequences

- New docs, tests, and code reviews have one vocabulary for lifecycle, events, outcomes, and
  reason codes, and can flag drift.
- Current documentation must label runtime names as current vocabulary instead of presenting them
  as target semantics. Mermaid diagrams keep drawing runtime states until runtime changes.
- Several current behaviors are explicitly non-conforming and become migration items rather than
  silent debt: user cancellation recorded as `FAILED` in sign-in session-limit handling, the
  sign-up cancel result status `:failed`, sign-in lacking a recorded expiry terminal, and sign-up
  post-commit phases whose terminal path on handoff failure or TTL lapse is not defined.
- Introducing `HALTED` and splitting `FAILED` need DB reference-row and audit decisions. The
  reference-row decisions (`HALTED = 930`, `FAILED = 900` kept as a tombstone, immutable ids) are in
  `adr/idp-flow-state-machine-lifecycle.md`; audit decisions remain in the implementation plan.

## Related

- `adr/idp-flow-state-machine-lifecycle.md`
- `docs/security/idp-flow-lifecycle.md`
- `plans/backlog/idp-flow-state-machine-unification.md`
- `adr/base-auth-ceremony-and-seven-rp-boundary.md`
- `adr/sign-up-authentication-handoff-and-social-rt.md`
- `adr/sign-up-cycle-cancellation-retention.md`
- `adr/logout-ceremony-boundary.md`
- `docs/security/sign-in-sequence.md`
- `docs/security/sign-up-sequence.md`
- `docs/security/logout-sequence.md`
