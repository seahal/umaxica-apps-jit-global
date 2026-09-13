# Logout Ceremony Boundary

## Status

Accepted (2026-06-21). Amended for Base completion destination by
`adr/base-lobby-unauthenticated-entry.md`.

## Context

The browser logout flow needed a stable contract across Acme, Sign, Core, and Base. The old boundary
treated completion as a separate `/signed-out` page and overloaded `/sign/out` with both mutation
and completion concerns. That made the contract hard to reason about, especially once RP launcher
flows and Acme OIDC end-session flows started sharing the same user-facing ceremony.

## Decision

The browser logout ceremony is surface-local and uses the same path shape on every browser surface:

```text
GET  /sign/out/new
GET  /sign/out/edit
POST /sign/out
GET  /sign/out/complete
```

- `GET /sign/out/new` is a redirect-only entry point.
- `GET /sign/out/edit` renders confirmation with no mutation.
- `POST /sign/out` performs the local action for Acme or launches the RP logout flow for
  Sign/Core/Base.
- `GET /sign/out/complete` renders friendly completion HTML and is safe to reload.

Acme is the only OP / Authorization Server. Its OIDC end-session endpoint remains:

```text
GET /oidc/logout
POST /oidc/logout
```

Acme local logout uses direct authority logout. Sign/Core/Base local logout launches to Acme
`/oidc/logout` after local cleanup and stores a session-bound completion state before redirecting to
their own `/sign/out/complete`.

The browser completion marker is session-bound and one-time consumed. It is not carried in the URL
and does not use `sot`.

`DELETE /sign/out` is not part of the public contract.

Palm is a future native client. Its documented completion target is:

```text
https://<palm-host>/sign/out/complete
```

## Consequences

- The user-facing ceremony is consistent across app/com/org browser surfaces.
- Completion is always local to the originating surface.
- `/oidc/logout` stays reserved for Acme protocol intake.
- Friendly completion HTML is available even after reload or stale navigation.

## Related

- `adr/logout-completion-boundary.md` superseded by this ADR
- `docs/security/logout-sequence.md`
- `docs/security/oidc-discovery-profile.md`
- `docs/security/logout-session-management.md`
