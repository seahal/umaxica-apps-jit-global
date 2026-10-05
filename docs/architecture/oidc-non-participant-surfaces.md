# OIDC/OAuth Non-Participant Surfaces

Canonical decision: `adr/oidc-oauth-participation-allowlist-and-non-participant-surfaces.md`.

This page describes how the Non-Participant boundary is implemented today. Participation in
UMAXICA OAuth/OIDC is allowlisted; every surface below is outside that allowlist. The participating
surfaces are described in `docs/architecture/base-auth-seven-rp-boundary.md`.

## Repository-owned Non-Participants

| Surface             | Route file              | Controller stack                                   |
| ------------------- | ----------------------- | -------------------------------------------------- |
| Info app/com/org    | `config/routes/info.rb` | Surface-local `BareController`                     |
| Docs app/com/org    | `config/routes/docs.rb` | Surface-local `BareController`                     |
| News app/com/org    | `config/routes/news.rb` | Surface-local `BareController`                     |
| Help app/com/org    | `config/routes/help.rb` | Surface-local `BareController`                     |
| Guid net            | `config/routes/guid.rb` | `Guid::Net::BareController`                        |
| Base developer face | `config/routes/base.rb` | `Base::Dev::ApplicationController`, bare stack     |
| Core developer face | `config/routes/core.rb` | `Core::Dev::BareController`                        |
| Base network face   | `config/routes/base.rb` | `Base::Net::ApplicationController`, bare stack     |
| Core network face   | `config/routes/core.rb` | `Core::Net::BareController`                        |
| Xper app/com/org    | `config/routes/xper.rb` | Surface-local application and bare stacks          |
| Diagnostic hosts    | one route file each     | Mounted engine or Rack app                         |

The diagnostic hosts are Mission, Flipper, Blazer, PgHero, Performance, Coverband, and Swagger.

Auth app/com/org (`config/routes/auth.rb`) is also a Non-Participant, as a ceremony service with its
own contract; see `docs/architecture/auth-ceremony-session-boundary.md`.

### Content surfaces and Guid

Info, Docs, News, Help, and Guid have thirteen surface-local base controllers between them. Each is
a `BareController` that inherits `ActionController::Base` directly, declares
`AUTHENTICATION_MODE = :bare`, and includes only `FqdnAvailabilityGate`, `RateLimit`, and
`DefaultNoStore`. None of these trees has an `ApplicationController`. Their other includes are
rendering and negotiation concerns for health, revision, CSP reports, and the read API.

Their route sets expose a root, health and revision endpoints, the CSP report sink, and the
read-only `api/v0` resources. They expose no `/sign` entry, no `/oidc/callback`, and no `/oauth/*`
endpoint.

### Developer and network faces

The Base and Core developer faces and the private Base and Core network faces expose a root, health
and revision endpoints, and the CSP report sink.

`Core::Dev::BareController` and `Core::Net::BareController` are bare stacks like the content
surfaces.

`Base::Dev::ApplicationController` and `Base::Net::ApplicationController` each serve only a root
page. They include the same three concerns as the bare stacks, add the default web rate limit and
the modern-browser gate, and declare `AUTHENTICATION_MODE = :deny_all`. They carry no actor,
session, or preference lifecycle.

### Diagnostic mounts

Each diagnostic host is constrained to its own hostname and carries its own HTTP Basic credential
check, which fails closed when credentials are not configured. None uses UMAXICA OAuth/OIDC.

- Flipper and Coverband are plain Rack apps wrapped in `Rack::Auth::Basic` at the mount point.
- Mission Control Jobs, Blazer, PgHero, Performance, and Swagger are engines whose Basic
  authentication is configured in their own initializer under `config/initializers/`.
- Blazer, PgHero, Performance, Coverband, and Swagger are development-group gems and are mounted
  only when their constants are defined.

Mission Control's controllers inherit the root `::ApplicationController`. That class currently
declares only the CSRF baseline and `AUTHENTICATION_MODE = :deny_all`. An authentication concern
added to it would reach the Mission host by inheritance.

### Xper

All Xper base controllers inherit `ActionController::Base` directly and declare
`AUTHENTICATION_MODE = :bare`. Phase 0 exposes a homepage, health, revision, the CSP report sink,
and temporary robots and sitemap endpoints, with no credential lifecycle.

### Auth

Auth exposes a `/sign` ceremony namespace, a `sign/oidc/handoff` resource, and a JWKS document. Its
route file states that it has no OIDC RP callback, authorization, or back-channel routes. Auth owns
the `__Host-auth_sid` ceremony cookie, which is not login proof on any surface.

## Externally owned Non-Participants

`jump.umaxica.net`, `asset.umaxica.net`, and `status.umaxica.dev` have no route set in this
repository. The decision governs them; the repository or deployment that owns each one verifies it.

## Client registry

`OidcClientStoresStaticClientStore` registers three groups: the first-party browser RP clients, the
deprecated shared browser client `core-next-rp`, and the native clients `app-ios-rp` and
`app-android-rp`. No Non-Participant surface is registered.

## Known gaps

- `AuthBoundaryAuthorityMap` lists browser RP client IDs only. The native clients are in the
  registry but not in the map, so the map does not yet express the whole allowlist.
- `core-next-rp` is listed as deprecated in the map and is still registered.
- No contract test asserts the Non-Participant boundary yet. The existing tests cover the
  participating side: the seven RP clients, Base authority endpoints, and Auth's Jump JWKS.

The work to close these is recorded in `plans/backlog/oidc-non-participant-contract-tests.md`.

## Related

- `docs/architecture/base-auth-seven-rp-boundary.md`
- `docs/architecture/content-surface-matrix.md`
- `docs/architecture/docs-help-news-content-boundary.md`
- `docs/architecture/guid-surface.md`
- `docs/architecture/auth-ceremony-session-boundary.md`
