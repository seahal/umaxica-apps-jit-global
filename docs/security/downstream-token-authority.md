# Downstream Token Authority

> **Supersession (2026-06-12):** Use `adr/acme-sign-core-base-port-boundary.md` and
> `docs/architecture/acme-sign-core-base-port.md` for the target component model. Acme is the only
> IdP / Authorization Server. Palm is the native bearer-token API Resource Server. Older references
> to `acme/www`, `core`, and `line` as downstream-token consumers are historical where they conflict
> with the Acme / Sign / Core / Base / Palm boundary.

> **Current Rails-contract supersession (2026-09-23):** The later Base/Auth decision supersedes the
> physical Acme authority wording above. Base is the sole physical OIDC IdP/Authorization Server;
> Auth is ceremony-only. The Acme vocabulary below is historical and must not be used to introduce
> an additional issuer, shared browser session, or retired RP registration.

> **Participation update (2026-10-13):** Palm is now a first-party browser RP using the `palm-app`
> audience; its former native bearer API is retired. Tech is an operator browser RP using
> `tech-org`. The accepted contract and local implementation status are recorded in
> `adr/tech-and-palm-browser-rp-participation.md`.

## Authority

`acme/www` is the downstream-token Authority.

`core`, `line`, and future downstream services must trust acme-issued downstream tokens only. They
must not trust sign-issued session, access, refresh, or downstream tokens.

## Requirements

Downstream tokens must be:

- issued by acme;
- audience-bound to the downstream service;
- purpose-bound to the downstream action or API family where applicable;
- short-lived;
- verifiable by the downstream service through acme JWKS or the current acme verification channel.

## Non-Goals

- Do not use credential ceremony results as downstream tokens.
- Do not let `sign/id` mint tokens for `core`, `line`, or future downstream services.
- Do not infer downstream authority from physical token table placement.

## Related

- `docs/security/session-token-authority.md`

## Delivered reconciliation (2026-10-06)

Base-issued credentials are the only downstream browser/RP token authority in this cycle. Issuer,
audience, subject and RP-session binding are checked before a token is accepted; Auth ceremony
results are not downstream access tokens. A parent security context can authorize an explicitly
bound RP operation but never authenticates a missing RP credential. Legacy Sign/Acme wording above
is migration history and is superseded by the Base/Warp registry.

## Browser RP participation update (2026-10-13)

Core, Warp, Edit, Palm and Tech use Base-issued browser RP credentials bound to their own client,
issuer, audience and host-local cookie. Tech also checks the current `tech.access` capability.
Palm's former `palm-api` bearer resource-server path is retired; this update does not create a
general-purpose downstream API token contract.
