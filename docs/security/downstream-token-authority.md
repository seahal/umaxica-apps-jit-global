# Downstream Token Authority

> **Supersession (2026-06-12):** Use `adr/acme-sign-core-base-port-boundary.md` and
> `docs/architecture/acme-sign-core-base-port.md` for the target component model. Acme is the only
> IdP / Authorization Server. Palm is the native bearer-token API Resource Server. Older references
> to `acme/www`, `core`, and `line` as downstream-token consumers are historical where they conflict
> with the Acme / Sign / Core / Base / Palm boundary.

> **Current Rails-contract supersession (2026-09-23):** The later Base/Auth decision supersedes the
> physical Acme authority wording above. The current sole physical OIDC IdP/Authorization Server is
> Visa; Auth is ceremony-only and Base is a browser RP. The Acme vocabulary below is historical and
> must not be used to introduce an additional issuer, shared browser session, or retired RP
> registration.

> **Participation update (2026-10-13):** Palm is now a first-party browser RP using the `palm-app`
> audience; its former native bearer API is retired. Tech is an operator browser RP using
> `tech-org`. The accepted contract and local implementation status are recorded in
> `adr/tech-and-palm-browser-rp-participation.md`.

> **Current OIDC boundary (2026-10-24):** Visa is the Rails OIDC authority on `visa.umaxica.*`; Base
> is the browser RP on `www.umaxica.*`. Visa-issued authority and downstream tokens use the Visa
> issuer/key namespace. Base-issued browser RP credentials remain local to the RP and must not be
> treated as Visa authority tokens. See `adr/visa-op-host.md`.

## Authority

The historical `acme/www` downstream-token Authority is now represented by Visa's OIDC authority
boundary.

`core`, `line`, and future downstream services must trust authority-issued downstream tokens only.
They must not trust sign-issued session, access, refresh, or downstream tokens.

## Requirements

Downstream tokens must be:

- issued by Visa's configured authority;
- audience-bound to the downstream service;
- purpose-bound to the downstream action or API family where applicable;
- short-lived;
- verifiable by the downstream service through the Visa JWKS or the current authority verification
  channel.

## Non-Goals

- Do not use credential ceremony results as downstream tokens.
- Do not let `sign/id` mint tokens for `core`, `line`, or future downstream services.
- Do not infer downstream authority from physical token table placement.

## Related

- `docs/security/session-token-authority.md`

## Delivered reconciliation (2026-10-06)

Visa-issued authority credentials and each RP's local credentials are the only active browser/RP
token contracts in this cycle. Issuer, audience, subject and RP-session binding are checked before a
token is accepted; Auth ceremony results are not downstream access tokens. A parent security context
can authorize an explicitly bound RP operation but never authenticates a missing RP credential.
Legacy Sign/Acme wording above is migration history and is superseded by the Base/Warp registry.

## Browser RP participation update (2026-10-13)

Core, Warp, Edit, Palm and Tech use Base-issued browser RP credentials bound to their own client,
issuer, audience and host-local cookie. Tech also checks the current `tech.access` capability.
Palm's former `palm-api` bearer resource-server path is retired; this update does not create a
general-purpose downstream API token contract.
