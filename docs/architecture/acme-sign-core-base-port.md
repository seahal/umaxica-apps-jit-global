# Acme, Sign, Core, Base, And Palm Architecture

## Current Boundary

The accepted component model is:

| Component | Role                                           |
| --------- | ---------------------------------------------- |
| Acme      | IdP / Authorization Server                     |
| Sign      | Special relying party                          |
| Core      | Next.js web relying party and BFF              |
| Base      | Rails application foundation and control plane |
| Palm      | Native bearer-token API Resource Server        |

Acme is the only login authority. Sign, Core, Base views, iOS, and Android authenticate through
Acme. APIs are Resource Servers, not relying parties.

Palm is the canonical name for the native API formerly tracked as Port. New architecture, code,
configuration, route, and audience vocabulary should use Palm.

Current Rails implementation namespaces do not always match the target component names. Use this
mapping when reading routes, controllers, tests, and docs:

| Target component | Rails route/controller namespace | Route responsibility in this repository                          |
| ---------------- | -------------------------------- | ---------------------------------------------------------------- |
| Acme             | `base`                           | OP / Authorization Server protocol routes and identity authority |
| Sign             | `auth`                           | Credential ceremony and sign-related relying-party UI            |
| Core             | `core`                           | Rails browser API/BFF boundary for the Core web experience       |
| Base             | `base`                           | Rails control-plane, identity, preference, and settings views    |
| Palm             | `palm`                           | Native bearer-token API Resource Server                          |

The `base` namespace is therefore overloaded during the transition: it contains both Acme authority
routes and Base Rails control-plane routes. Do not infer credential-gateway ownership from the
namespace name alone.

## Responsibilities

Acme owns `/authorize`, `/token`, JWKS, ID Token issuance, Access Token issuance, issuer identity,
and subject identity.

Protocol URL contract:

- Acme OP / Authorization Server uses `/.well-known/openid-configuration`, `/.well-known/jwks.json`,
  `/oauth/authorize`, `/oauth/token`, `/oauth/userinfo`, `/oauth/revoke`, and `/oidc/logout`.
- First-party browser RP flows use `/oidc/authorization`, `/oidc/callback`, and
  `/oidc/backchannel/logout` where the RP consumes Acme login state. Palm is not a browser RP
  launcher; it retains only an inert native callback compatibility stub until a native client
  registration and concrete flow are separately approved.
- Social federation flows use `/social/:provider/sign/in`, `/social/:provider/sign/up`, and
  `/social/:provider/callback`.
- `google` and `apple` are canonical social provider names. `google_app` is historical only.
- `/oauth/jwks`, `/auth/*`, `/oauth/callback`, and `/social/auth/*` are retired route families.

Sign owns sign-related UI or special flows as a relying party. Sign is not an issuer.

Core owns the browser-facing web experience, receives the Acme callback, and serves the browser
credential boundary. `adr/core-browser-jwt-cookie-transport-and-nextjs-zero-cookie-boundary.md`
supersedes the earlier `__Host-core_sid`-only model: Rails Core may consume `aud=core-browser`
access JWTs only from HttpOnly cookie transport, and the Next.js origin must receive no `Cookie`
header at all.

Base owns Rails-suitable foundation behavior: settings, preferences, account, profile, organization,
administration, complex mutations, audit-sensitive operations, and Rails views where Rails remains
the safer implementation boundary.

Palm owns native API access for iOS, Android, and other native clients. It accepts only Acme-issued
bearer access tokens with the Palm audience. Palm is bearer-only; `cnf.jkt`-bound tokens must not be
accepted as plain Bearer tokens unless a separate boundary change adds full DPoP verification.

## Browser Flow

```text
Browser
-> Core / Next.js / jp.example.com
-> Acme /authorize
-> Core callback
-> Rails Core consumes the auth access cookie on /api/v0/*
```

The browser may hold a Core browser access JWT only through HttpOnly cookie transport. JavaScript
must not read access or refresh credentials. Next.js must not receive any `Cookie` header, including
access, refresh, OIDC transaction, preference, flash, analytics, or unrelated cookies.

Core browser credential cookies use the existing Rails auth cookie concern and names, not a
Core-only fork:

| Cookie                                                               | Purpose          | Domain                     | Path                       | SameSite                   | Secure                     | HttpOnly                   |
| -------------------------------------------------------------------- | ---------------- | -------------------------- | -------------------------- | -------------------------- | -------------------------- | -------------------------- |
| `__Host-auth_access` in secure contexts, `auth_access` in dev/test   | Access JWT       | none                       | `/`                        | `Strict`                   | `true` in secure contexts  | `true`                     |
| `__Host-auth_refresh` in secure contexts, `auth_refresh` in dev/test | Opaque refresh   | none                       | `/`                        | `Strict`                   | `true` in secure contexts  | `true`                     |
| existing Rails/OIDC transaction state                                | OIDC transaction | existing ceremony controls | existing ceremony controls | existing ceremony controls | existing ceremony controls | existing ceremony controls |

The access JWT uses the `core-browser` audience and a short TTL. The refresh credential is opaque.
Do not split the auth ceremony into Core-only cookie concerns or names unless a later ADR accepts
that drift.

Do not use `Domain=.example.com` for Core browser credentials. Cloudflare strips the entire `Cookie`
header before forwarding requests to the Next.js origin or `side.jp.umaxica.app`, and strips
`Set-Cookie` from Next.js and Side responses before they reach the browser.

## Session And Cookie Boundary

Core and Base do not share cookies or sessions.

- Core session is not Base session.
- Core cookie is not Base cookie.
- Rails session is not Next.js session.
- Rails APIs must not trust a Next.js cookie.
- Next.js must not read Rails session cookies.

The shared person key across components is Acme `iss + sub`.

## Native And Palm Flow

```text
iOS / Android
-> Acme /authorize
-> Acme /token
-> Palm API with Authorization: Bearer
```

Native apps are public RPs using Authorization Code + PKCE. Palm is a Resource Server. Palm does not
use Rails sessions, Next.js sessions, or browser cookies.

Palm validates:

- token signature;
- `iss` equals the Acme issuer;
- `aud` equals `palm-api`;
- `exp`, `nbf`, and `iat`;
- scope;
- `client_id`;
- `sub`.

Palm resolves users from Acme `iss + sub`.

## Token Boundary

ID Tokens are for RPs to verify login results. Access Tokens are for APIs and Resource Servers to
authorize API access.

APIs must not use ID Tokens for authorization.

Audience and transport are bound:

- `aud=core-browser` is accepted only from cookie transport.
- `aud=palm-api` is accepted only from Authorization bearer transport.
- `aud=side-service` is service-token-only and never user-bound.

`port-api` is legacy vocabulary for the former Palm name and is not the target audience for new
native API tokens.

Reverse transport must be rejected. Because Core browser uses cookie transport, Rails CSRF
verification is mandatory for unsafe methods.

## Names And URLs

Initial client and audience names:

- `sign-rp`
- `core-next-rp`
- `base-rails-rp`
- `app-ios-rp`
- `app-android-rp`
- `palm-api`

Optional future API audiences for Core-to-Base server-side calls may use names such as `core-api` or
`base-api`.

URL direction:

- Acme: `acme.example.com` or equivalent.
- Sign: `sign.example.com` or equivalent.
- Core: `jp.example.com`.
- Base: `www.jp.example.com` or equivalent Rails foundation/control-plane subdomain.
- Palm: `palm.jp.umaxica.app` in current Rails route configuration; final production URL shape
  remains open.

Palm URL selection remains open. The Palm responsibility and `palm-api` bearer-token audience are
fixed.

## Related

- `adr/core-browser-jwt-cookie-transport-and-nextjs-zero-cookie-boundary.md`
- `adr/core-browser-credential-transport.md`
- `adr/acme-sign-core-base-port-boundary.md`
- `docs/security/cookie-domain-scope.md`
- `docs/security/downstream-token-authority.md`
