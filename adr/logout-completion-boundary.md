# Logout Completion Boundary

## Status

Superseded (2026-06-21). See `adr/logout-ceremony-boundary.md`.

## Context

`adr/identity-authority-boundary.md` and `adr/acme-session-and-token-authority.md` make `acme/www`
the Session and Token Authority. Logout is therefore an acme-owned mutation: acme revokes the
current session, clears auth cookies and Rails session state, records logout audit through the
existing logout primitive, and decides the post-mutation navigation target.

The user-visible post-logout screen still needs a stable place. The completion result may be shown
only once, and the result display must be consumed from a session-bound marker so a stale or
replayed completion URL cannot keep displaying logout success.

## Decision

User-facing logout ceremony is surface-local:

```text
GET  /sign/out/new
GET  /sign/out/edit
POST /sign/out
GET  /sign/out/complete
```

`acme/www` owns direct logout mutation and the OIDC end-session endpoint. `sign/id`, `core`, and
`base` own browser RP launchers and their own `/sign/out/complete` completion pages. Completion is
session-bound and one-time consumed.

`/sign/out/edit?sot=` is retired from the normal browser flow. The browser completion marker lives
in the session, not the URL.

`/oidc/logout` remains Acme-only. It may stage a validated OIDC request, reuse the shared
`/sign/out/edit` confirmation, and redirect back to the exact registered `post_logout_redirect_uri`
or a surface-local `/sign/out/complete`.

Palm is an approved native RP. Its implemented browser authorization and Jump logout handoff
contract is recorded in `adr/jump-directed-rails-handoff-contract.md`; native custom-scheme
completion delivery remains outside the Jump graph.

## Consequences

- Local logout on Acme is direct authority logout.
- RP logout on Sign/Core/Base launches to Acme `/oidc/logout` after local cleanup.
- Completion URLs are surface-local and reusable only as friendly HTML, not as proof that logout
  just happened.
- `DELETE /sign/out` is not part of the public contract.

## Related

- `adr/identity-authority-boundary.md`
- `adr/acme-session-and-token-authority.md`
- `adr/sign-credential-gateway-surface.md`
- `adr/logout-primitive-and-composition.md`
