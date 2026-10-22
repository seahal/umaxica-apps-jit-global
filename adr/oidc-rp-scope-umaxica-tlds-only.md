# OIDC RP Scope: The Three UMAXICA TLDs Only

## Status

**Accepted (2026-10-21).** Owner decision in conversation on the same day. Decision only: no
code, registration, route or deployment is changed by this ADR, and no conformity is claimed.

## Context

Base is the sole OP/Authorization Server for the APP, COM and ORG realms
([Base/Auth boundary](base-auth-ceremony-and-seven-rp-boundary.md)). The current cycle decided that
every first-party RP behaves as a standard OIDC RP and that the OP's contracts (Discovery, JWKS,
Back-Channel Logout, RP-Initiated Logout) are shaped so that a standard library could use them. That
design keeps the door open for RPs outside this Rails application, but it did not say whether such
RPs are admitted now.

Cross-surface browser navigation between UMAXICA surfaces always goes through Jump
([Rails Directed Jump Handoffs](jump-directed-rails-handoff-contract.md)). Jump and the future Away
gateway live in a separate repository on a separate registrable domain (`umaxica.net`) so that a
Rails-side defect is still stopped outside Rails and cookies cannot mix. A rule was needed for what
counts as a UMAXICA surface versus an external RP.

## Decision

1. **The RP ↔ OP system serves only the three UMAXICA TLDs: `umaxica.app`, `umaxica.com` and
   `umaxica.org`.** First-party RPs on hosts of these registrable domains are the only RPs the OP
   admits today.
2. **Every other domain is an external RP**, including UMAXICA-owned domains such as `umaxica.dev`
   and `umaxica.net`.
3. **No external RP is connected to the OP at present.** The OP's standards-shaped contracts exist
   for extensibility; their existence does not admit any external RP. Admitting one requires a new
   decision.
4. **Integration with other systems goes through `tech.umaxica.org`.** Tech is the entry point for
   connecting UMAXICA to other systems
   ([Tech and Palm browser RP participation](tech-and-palm-browser-rp-participation.md)). If, for
   example, `umaxica.dev` needs single sign-on, it reaches UMAXICA through `tech.umaxica.org`; that
   is acceptable for now and does not make `umaxica.dev` an RP of the OP.
5. **Navigation rule.** Movement between UMAXICA surfaces on the three TLDs uses Jump, unchanged.
   External RPs, if ever admitted, are not surfaces: their arrival at the authorization endpoint and
   the OP's return to their exactly registered `redirect_uri` / `post_logout_redirect_uri` would be
   direct protocol redirects, not through Jump or Away. Away remains a separately designed gateway
   for user-initiated external navigation.

## Consequences

- Client registration stays limited to first-party clients on the three TLDs; registering an
  external client is out of contract until a later ADR.
- Requirements written for external RPs (direct redirects, public-network Back-Channel Logout
  delivery, library compatibility) remain design constraints for extensibility, not commitments to
  operate an external RP.
- `umaxica.dev` and `umaxica.net` services that need UMAXICA identity integrate through Tech, so the
  OP's trust surface does not grow with each such service.

## Alternatives rejected

- Treating every UMAXICA-owned domain as first-party: it would put services outside the three
  realms, and outside Jump's directed graph, inside the OP's trust boundary.
- Admitting external RPs now because the contracts already support them: capability is not
  authorization to operate.
