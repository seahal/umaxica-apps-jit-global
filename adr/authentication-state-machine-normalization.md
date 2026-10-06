# Authentication State-Machine Normalization

## Status

Accepted (2026-10-06) for the implementation cycle defined by `two.md`.

## Context

Sign-in, sign-up, sign-out, and session-limit handling currently distribute authority across
parallel status, state, and step columns, direct writers, request-time reference creation, and
request-clock expiry. That permits stale requests and concurrent submissions to disagree about the
durable result. The accepted lifecycle vocabulary and state-storage ADRs describe the desired
shape, but the implementation needs one bounded decision record for the migration.

## Decision

Each sign-in, sign-up, and sign-out carrier has one migration-owned state reference and one named
transition surface. A transition locks and reloads its owner, uses the owner's database clock,
checks expiry before mutation, rejects stale or illegal sources, and writes the transition and its
auxiliary facts in the owning transaction. Terminal states are absorbing. `FAILED = 900` remains a
legacy tombstone; `COMPLETED = 100`, `EXPIRED = 910`, `CANCELLED = 920`, and `HALTED = 930` are
the terminal facts used by new runtime transitions.

Sign-in completes at session issuance. Dashboard and return routing are derived after completion.
Session-limit resolution is a durable child transaction that keeps the parent in
`SESSION_ISSUANCE_PENDING`; it is bound to the actor, parent, browser, realm, and OIDC transaction
where present. Sign-up completion enters ordinary sign-in admission, and sign-out completion
records logout mutation progress without claiming access-token retirement.

The cycle may change Auth-side callers, controllers, shared concerns, and the D-82 admission
exchange only where required to enforce this normalization. It does not authorize a general Auth
login session, Xper redesign, or unrelated lifecycle redesign.

## Consequences

Old direct state writers, `now:` arguments, caller-selected `allowed_from`, request-time reference
creation, and runtime `ensure_defaults!` for these reference tables are removed as callers migrate.
Historical ids and terminal/audit facts remain readable. Migrations must classify ambiguous rows and
abort with record identifiers for forward repair rather than inventing state or deleting data.

This ADR **amends** `adr/idp-flow-lifecycle-vocabulary.md` and
`adr/idp-flow-state-machine-lifecycle.md`, and **partially supersedes** the session-limit authority
paragraph in `adr/root-login-establishment-boundary.md`. Existing surface, actor, database, and
security boundaries are **retained**.

## Verification contract

The implementation is complete only when the three realm models share the legal-edge, illegal-edge,
terminal, expiry-boundary, stale-source, and two-connection race tests, the direct-write invariant
passes, state diagrams and inventory describe the graph, and the final disposable-database
reconstruction succeeds.
