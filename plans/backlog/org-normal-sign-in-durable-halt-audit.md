# ORG normal sign-in durable halt audit

Status: known defect; deferred by the user for the current delivery on 2026-10-13.

The user requested that this defect remain recorded while the current acceptance suite passes. This
is a delivery exception, not a repair or a change to the durable FLOW-6 contract. No target cycle
was assigned to this defect; the separate verification backlog has a two-cycle target.

## Reproduction and evidence

At HEAD `4828aeedd141b54163236672890799b9b01128c2` with the acceptance worktree changes, complete
the local ORG Entra first stage, retain its transaction, and use
`OrgNormalSignInBindingCodec.encode` with the same public ID and a stale issued_at generation. POST
the binding to the normal passkey options endpoint. The response is 409 and the transaction is
halted with phase_violation, but the count of
`OperatorChronicle.where(event_id: OperatorChronicleEvent::SIGN_FLOW_HALTED)` increases by zero
instead of one. Replay issues no token or challenge.

The failure reproduced after a complete isolated database rebuild; see
[C6R2](../../evidence/2026-10-13-nine-clean-database-retest-C6R2.md). The responsible path is
`OrgNormalSignInTransaction#halt_org_normal_sign_in_transaction!`: session state and a generic
refusal log do not supply the required durable audit.

## Follow-up acceptance

- Add the owned durable audit with safe surface, flow correlation, reason and request/time facts.
- Define failure/retry behavior across the session and Chronicle boundary; do not assume a
  cross-database transaction or silently lose the event.
- Restore an assertion that exactly one SIGN_FLOW_HALTED record is created by the attributable halt,
  with no duplicate on replay and no secret-bearing context.
- Preserve safe GET/HEAD refusal, original-flow binding, HALT and no new token/challenge behavior.

The active controller regression continues to test those safety behaviors. Its durable-audit
assertion alone was removed under the explicit delivery exception, rather than skipped or changed to
require the defective zero-record result. Fixing this backlog must restore that positive audit
expectation. Application behavior was not changed to pass the current test.
