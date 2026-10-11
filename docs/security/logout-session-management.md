# Logout And Session Management

## Authority

Logout is session mutation. `acme/www` owns logout, session revoke, revoke-all, session listing,
restricted session handling, device/session display, token-family revocation, and compromise state.

`sign/id`, `core`, and `base` must not mutate authoritative acme logout or session state. They may
host the surface-local browser ceremony (`/sign/out/new`, `/sign/out/edit`, `/sign/out`, and on
Auth/Core/Side/Palm `/sign/out/complete`; Base completes on `/lobby`) and, when they are RPs, launch
logout toward Acme.

## Redirect-Only Sign Route

A retained sign-side sign-out route may:

- inspect request context needed to choose the acme logout entry;
- preserve a safe navigation target through signed redirect primitives;
- redirect the browser to acme when acting as an RP;
- render a local completion page after logout state is consumed.

It must not revoke tokens, clear acme sessions, list sessions, write logout audit as the authority,
or store logout state.

## Related

- `docs/security/session-token-authority.md`
- `docs/security/redirect-vs-ceremony-result.md`
