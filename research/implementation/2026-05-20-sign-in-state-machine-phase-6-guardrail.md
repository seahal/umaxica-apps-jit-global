# Sign-In State Machine Phase 6 Guardrail Participant

Phase 6 adds the guardrail participant contract for sign-in cycles.

Current behavior:

- `SignIn::GuardrailParticipant` evaluates an ordered stack of `SignIn::ParticipantItem` objects;
- empty stacks advance the cycle from `GUARDRAIL_PENDING` to `SESSION_ISSUANCE_PENDING`;
- cleared blocking items also allow advance;
- uncleared blocking items stop without mutating the cycle;
- default guardrail evaluators currently cover:
  - actor login no longer allowed;
  - existing restricted session for the actor;
- results expose `empty?`, `blocking?`, and `cleared?` so controllers can map them to the generic
  low-information plain-text response in the later surface wiring phase.

This phase intentionally does not add routes or controller branching. Future guardrail checks should
register item evaluators rather than insert new sign-in routes.
