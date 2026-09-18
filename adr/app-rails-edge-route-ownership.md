# App Rails and Edge Route Ownership

Status: Accepted

Date: 2026-09-12

## Context

The app realm spans four host-constrained Rails surfaces: Core/App, Auth/App, Base/App, and
Side/App. Earlier records describe a planned Core presentation split using Next.js and describe
`/api/v0` as a future vocabulary. The presentation implementation has since moved toward TanStack
Start, and the implemented Core browser contract already uses `/api/v0`.

Route ownership must follow the effective Rails route set and deployed architecture. A target Edge
design does not make an existing Rails page removable until the Edge replacement is deployed and
the host boundary routes traffic to it.

## Decision

Rails owns the app realm's authentication, authorization, session mutation, OIDC protocol, logout,
and server-side data endpoints. This includes:

- Core `/oidc/*`, `/sign/out*`, `/api/v0/*`, operational endpoints, and the CSP report endpoint.
- Auth credential ceremonies, provider callbacks, OIDC RP endpoints, settings, verification, and
  logout.
- Base Acme authorization-server endpoints, authenticated application pages, `/lobby`, and
  logout.
- Side authenticated control-plane pages, OIDC RP endpoints, and logout.

The versioned Core Edge-to-Rails browser contract is `/api/v0/*`. Historical controller module
names such as `web/v0` and `edge/v0` do not change the public route vocabulary. New endpoints
require a demonstrated browser operation or data requirement; Rails does not add parallel aliases
or speculative CRUD endpoints.

Core `GET /` remains Rails-owned during the current deployment stage. It initializes the existing
anonymous preference state and is linked by the Rails Core layout. It may be removed only with
evidence that the Edge origin is deployed, owns that navigation path, and preserves the required
preference initialization through an explicit Rails endpoint.

Base `GET /lobby` is the unauthenticated entry. It redirects an authenticated actor to
`/dashboard`. Base logout mutates only on `POST /sign/out` and completes at `/lobby`; Base does
not expose `GET /sign/out/complete`. Core, Auth, and Side retain their local non-mutating logout
completion resources.

Return targets for OIDC flows remain local application paths. Exact registered redirect URIs,
PKCE S256, state, nonce, CSRF protection, and host constraints remain mandatory. GET protocol
callbacks may establish protocol-derived session state, but GET navigation does not execute
logout, token refresh, or ordinary application mutations.

Edge owns presentation paths only after the deployment boundary assigns those paths to Edge.
Edge calls the explicit Rails endpoints for authentication state and domain operations; it does
not infer identity from browser-submitted identity fields or receive tokens in URLs.

## Consequences

The Rails route set does not change as part of this audit because no confirmed runtime route defect,
safe additional closure, or missing Edge operation was found. A declarative route test pins the
current ownership boundary and the routes that must remain absent.

The older Next.js record remains historical evidence for the browser-cookie boundary. Where its
framework name or rollout description conflicts with this decision, this decision describes the
current Rails ownership state.

Evidence for this decision is recorded in
`evidence/2026-09-12-app-rails-route-auth-audit.md`.
