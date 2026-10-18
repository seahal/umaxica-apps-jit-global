# Acme, Sign, Core, Base, And Palm Architecture

This document maps the historical Acme / Sign / Core / Base / Port vocabulary onto the current Rails
implementation. The historical component model came from `adr/acme-sign-core-base-port-boundary.md`.
Later ADRs superseded its authority claims, client names, and Palm role. When this document and an
accepted ADR disagree, the ADR is authoritative. Current owners:

- `adr/base-auth-ceremony-and-seven-rp-boundary.md`: Base authority, Auth ceremony, RP model
- `adr/tech-and-palm-browser-rp-participation.md`: Palm and Tech as browser RPs
- `adr/first-party-sign-out-shared-database-without-backchannel-logout.md` and
  `adr/first-party-sign-out-op-commit-and-backchannel-logout-for-separated-rp-stores.md`: sign-out
- `adr/core-browser-jwt-cookie-transport-and-nextjs-zero-cookie-boundary.md`: Core browser
  credentials
- `app/values/auth_boundary_authority_map.rb`: the canonical client ID and RP face map in code

## Vocabulary Mapping

| Historical name | Current implementation                                              | Rails namespace / routes         |
| --------------- | ------------------------------------------------------------------- | -------------------------------- |
| Acme            | Conceptual authority vocabulary; physically implemented by **Base** | `base` (`config/routes/base.rb`) |
| Sign            | **Auth**, a credential and authentication ceremony service only     | `auth` (`config/routes/auth.rb`) |
| Core            | Core Rails BFF and first-party browser RP per face                  | `core` (`config/routes/core.rb`) |
| Base            | Base IdP / AS, control plane, and its own self-RP per face          | `base` (`config/routes/base.rb`) |
| Port / Palm     | **Palm**, a first-party browser RP (no native or bearer API role)   | `palm` (`config/routes/palm.rb`) |

Warp, Edit, and Tech are also first-party browser RPs, but the historical model has no name for
them.

## Authority And Ceremony

- Base is the only physical OpenID Provider and Authorization Server. It serves
  `/.well-known/openid-configuration`, `/.well-known/jwks.json`, `/oauth/authorize`, `/oauth/token`,
  `/oauth/userinfo`, `/oauth/revoke`, `/oauth/refresh-deliveries/query`, and `/oidc/logout` on each
  of its app, com, and org hosts.
- Auth is not an issuer and not an RP. It runs the credential ceremonies (sign-in, sign-up, passkey,
  social federation) and hands the result back to Base through an opaque, short-lived handoff. Auth
  has no `/oidc/callback`, `/oidc/authorization`, or back-channel logout route.
- Auth keeps only ceremony-local browser sessions bound to `__Host-auth_sid`. Those sessions do not
  prove a Base login.

## First-Party Browser RPs

Every first-party RP is a confidential client that uses the authorization code flow with PKCE S256,
`state`, `nonce`, and `private_key_jwt`. The current client IDs in `AuthBoundaryAuthorityMap` are:

| Surface | Client IDs                                                  | Actor                       |
| ------- | ----------------------------------------------------------- | --------------------------- |
| Core    | `core-app-jp`, `core-com-jp`, `core-org-jp` (+ `-us` faces) | client / visitor / operator |
| Warp    | `warp-app-jp`, `warp-com-jp`, `warp-org-jp` (+ `-us` faces) | client / visitor / operator |
| Base    | `base-app-ww`, `base-com-ww`, `base-org-ww` (self-RP)       | client / visitor / operator |
| Edit    | `edit-org-ww`                                               | operator                    |
| Palm    | `palm-app-jp`                                               | client                      |
| Tech    | `tech-org-ww` (requires `tech.access`)                      | operator                    |

Each RP host exposes the same route contract:

- `GET /sign` renders a neutral entry page; the CSRF-protected `POST /sign` starts the flow. The RP
  does not choose sign-in or sign-up; Auth owns that choice.
- `GET /oidc/callback` is the exact registered `redirect_uri`.
- `/sign/out/completion?ri=jp|us` is the registered post-logout return URI.
- `POST /oidc/backchannel-logout` receives back-channel logout for a separated RP cell, and
  `POST /sign/out/purge` purges the matching RP cookies after OP logout (release R5 work).

`sign-rp` and `base-rails-rp` are deprecated shared registrations. `side-rails-rp`, `app-ios-rp`,
`app-android-rp`, and the `palm-api` audience are retired. Do not add new registrations from those
names.

The `docs`, `news`, and `help` surfaces are content surfaces, not OIDC RPs.

## Session Hierarchy

Identity → Base Browser Session (`ClientToken` / `VisitorToken` / `OperatorToken`) → RP Session per
registered client. RP surfaces share no cookies or sessions with each other or with Base. Each RP
cell has its own session store (`config/database.yml` `rp_*` connections), keyed by client ID.

## Sign-Out

Sign-out commits at the OP. Until a client is activated with its own separated session store,
`adr/first-party-sign-out-shared-database-without-backchannel-logout.md` applies: one transaction
revokes the parent and the RP session rows, and no back-channel logout is used. For a separated RP
cell, the OP commit establishes sign-out, and a worker outside the request delivers a Back-Channel
Logout Token afterwards. Delivery never decides whether sign-out succeeded.

## Core Browser Credential Transport

`CoreBrowserCredentialContract` and `CoreBrowserApiBoundary` implement the Core browser credential
contract, gated by `CORE_BROWSER_JWT_COOKIE_ENABLED`:

| Cookie                                                  | Purpose          | Path | SameSite | Secure | HttpOnly |
| ------------------------------------------------------- | ---------------- | ---- | -------- | ------ | -------- |
| `__Host-auth_access` (secure context) / `auth_access`   | Access JWT       | `/`  | `Strict` | `true` | `true`   |
| `__Host-auth_refresh` (secure context) / `auth_refresh` | Opaque refresh   | `/`  | `Strict` | `true` | `true`   |
| `_umaxica_session`                                      | OIDC transaction | `/`  | `Lax`    | `true` | `true`   |

- The access JWT has audience `core-browser` and a TTL of 10 minutes, capped by the session's
  absolute expiry. Rails Core accepts it only from cookie transport on `/api/v0/*`, and CSRF
  verification is required for unsafe methods.
- No cookie sets `Domain`. Cloudflare strips the `Cookie` header before requests reach the Next.js
  origin, and strips `Set-Cookie` from Next.js and Warp responses. JavaScript never reads access or
  refresh credentials.
- The `__Host-` prefix follows `JitSessionCookieConfig.force_secure?`, not only
  `Rails.env.production?`.

## Token Boundary

ID Tokens let RPs verify the login result. Access Tokens authorize API access. APIs must not use an
ID Token for authorization. Audience and transport are bound: `core-browser` is accepted only from
cookie transport. The shared person key across surfaces is the Base issuer plus `sub`.

## Related

- `adr/acme-sign-core-base-port-boundary.md` (historical)
- `adr/base-auth-ceremony-and-seven-rp-boundary.md`
- `adr/tech-and-palm-browser-rp-participation.md`
- `adr/core-browser-jwt-cookie-transport-and-nextjs-zero-cookie-boundary.md`
- `docs/security/cookie-domain-scope.md`
- `docs/security/downstream-token-authority.md`
