# Social Credential Management Migration

## Status

Backlog after the `two.md` implementation cycle. This is not an authorization to start a new
workflow or to weaken the delivered social-binding contract.

## Current boundary

Google and Apple linking and unlinking use the existing explicit step-up operation, actor and
surface boundaries. Resolution uses only the verified issuer and subject. Active uniqueness is
enforced per Client and across providers, release history is retained, and a released subject is
never reattached by an old callback. Org remains governed by its existing Operator, tenant,
organization and Emergency controls.

## Future work

If a unified credential-management UI is accepted later, it must preserve the provider callback
state, browser, candidate, Identity and operation bindings, use the current Auth admitted-ceremony
boundary, and re-evaluate removal safety immediately before commit. It must not infer an actor from
email, display name, provider browser state or an unverified `iss/sub` translation. It must not add
a global credential registry or make a social credential a substitute for step-up evidence.

## Required preparation

Before implementation, inventory the provider-specific callbacks, notifications, release and
retention consumers, then write a new specification and migration plan. Add independent-browser,
same-Client competing-provider, same-subject competing-Client, release, replay and removal-safety
tests first. Reconcile the plan with `adr/identity-resolution-and-credential-binding.md`,
`adr/social-identity-linking-requires-step-up.md`, and the current operation inventory.
