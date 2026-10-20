# Authorization

Applies to protected operations on each independently scoped surface.

- AUTHZ-1: Server-side authorization protects mutations regardless of hidden or disabled UI
  controls.
- AUTHZ-2: Resource lookup and authorization preserve the surface, actor and owning organization; an
  identifier from another organization does not gain access through a nested route.
- AUTHZ-3: Published private mutation stubs retain authorization before their response. Existing
  justified association-scoping exceptions remain explicit and bounded.
- AUTHZ-4: A step-up result authorizes only an operation whose explicit purpose, actor, resource,
  tenant, session, transaction, freshness and method requirements it satisfies; an AAL label alone
  does not authorize an operation.
- AUTHZ-5: A Tech `tech.access` grant is issued only by an Operator holding `iam.capability.read`,
  `iam.capability.grant` and their own currently valid `tech.access`, with Step-Up, a reason code
  and an audit record. Self-grant is refused, and validity is finite and at most 366 days.
- AUTHZ-6: Base owner-page relays forward GET and HEAD through the owner's read operation; HEAD
  never selects a POST operation. Owner authorization and refusal responses remain enforced.

Sources: [Action Policy conventions](../security/action-policy-conventions.md),
[Tech and Palm participation](../../adr/tech-and-palm-browser-rp-participation.md),
[authentication contract](../../.agents/harnesses/rules/generic/authentication-boundaries.mdc).
Owner query mechanics are described in [owner record lookups](../security/owner-record-lookups.md).
These are required behaviors; their presence is not evidence of execution.
