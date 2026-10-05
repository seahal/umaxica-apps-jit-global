# Defer Auth / Xper Transient Workflow Redesign From the Current RP Cycle

## Status

Accepted (2026-10-05). This is a scope decision for the current Base/RP consolidation cycle.

Extends, and does not supersede, `adr/base-auth-ceremony-and-seven-rp-boundary.md`: Base remains the
physical OIDC/OAuth authority and Auth remains ceremony-only. It complements
`adr/oidc-oauth-participation-allowlist-and-non-participant-surfaces.md` by making Auth and Xper
explicit identity-adjacent workflow services rather than ordinary RP, OP, or AS participants.

## Context

The Base/RP consolidation exposed a future opportunity to model Auth and Xper as transient workflow
services using short-lived, purpose-bound, one-time opaque capabilities. Auth already contains an
admission and result transport in this family, while Xper is still intentionally thin and the
Experience replacement for Preference is not yet mature.

Auth has unusually hard external-origin constraints. Its current `auth.*` public origins are relied
upon by Passkey and social-login contracts and are no longer candidates for renaming. Xper uses the
apex `umaxica.app`, `umaxica.com`, and `umaxica.org` origins despite DNS/CNAME operational
constraints; that placement was chosen as part of moving Experience responsibility away from
continued Base growth.

Freezing a shared Auth/Xper implementation now would expand the current RP cycle and would
prematurely constrain the still-fluid Experience architecture.

## Decision

- Auth remains a ceremony-only service and is not an OIDC RP, OIDC OP, or OAuth Authorization
  Server.
- Xper remains an Experience workflow surface and is not an OIDC RP, OIDC OP, or OAuth Authorization
  Server.
- Auth public `auth.*` origins remain stable external contracts.
- Xper apex origins remain the planned Experience origins.
- The current cycle does not refactor or add Auth or Xper workflow, token, or cookie
  implementation.
- The current cycle does not create a shared transient-capability implementation for Auth and Xper.
- The current RP/Base redesign must not import Auth or Xper legacy authentication concerns as a
  generic RP pattern.
- A future cycle must revisit a short-lived opaque admission and result capability model,
  Browser-Session-scoped active workflow constraints, and Xper's final Experience authority
  boundary.

The alternatives discussed are recorded in
`memos/2026-10-05-claude-auth-xper-transient-workflow-future-design.md`. They are informative, not
normative.

## Consequences

The Base/RP cycle can proceed without coupling its shared RP layer to an unfinished Experience
design or destabilizing Auth's public origin and callback contracts.

The cost is a known future redesign item for both Auth and Xper. That work is retained in
`plans/backlog/auth-xper-transient-workflow-redesign.md` rather than silently abandoned.
