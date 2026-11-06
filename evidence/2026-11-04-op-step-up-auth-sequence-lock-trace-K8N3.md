# O-10 authentication sequence lock trace

Date: 2026-11-04

## Scope

Read-only trace of the APP OIDC Secret admission path in `AuthenticationSequenceGate` for the
principal / OP lock-order inventory.

## Observed result

`with_claimed_oidc_secret_flow` obtains the resource lock before the OIDC authorization parent,
sign-in Flow and Auth ceremony locks. The OIDC Secret branch invokes it from
`start_sign_in_flow_for!` before claim work. The separately defined
`advance_pending_sign_in_flow_after_primary!` helper had no production callsite in the current
`app/` search; its guardrail participant reads actor eligibility without taking a principal row
lock. No OP-to-principal reverse edge was found in this bounded trace.

The reproducible lexical intersection remains 88 candidate files. The inventory names 16 by full
path and leaves 72 unnamed. The remaining count is triage only; the full call graph is still open.

## Evidence and limits

- Inspected `app/controllers/concerns/authentication_sequence_gate.rb:385–415,417–452`,
  `app/services/sign_in_guardrail_participant.rb:26–35,48–52`, and its `app/` callsites.
- Recomputed candidate and named-path totals using the inventory's recorded search expressions.
- No tests, application code, or databases were changed or accessed.

HEAD: `b30345216886c98af1f04cbd434f067f12decf01`. The worktree was extensively uncommitted; this
read-only source trace was against the worktree content.
