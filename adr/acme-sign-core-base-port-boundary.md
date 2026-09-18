# Acme, Sign, Core, Base, And Palm Boundary

> **Supersession (2026-09-13):** Physical Rails authority is Base (sole IdP/AS). Auth is a ceremony
> service, not a special RP. Seven first-party RPs replace shared browser clients. See
> `adr/base-auth-ceremony-and-seven-rp-boundary.md`. Acme remains conceptual vocabulary.

> Core browser credential transport update:
> `adr/core-browser-jwt-cookie-transport-and-nextjs-zero-cookie-boundary.md` supersedes this ADR's
> `__Host-core_sid`-only Core browser credential model in the Web Boundary and Guardrails sections.

## Status

Accepted; partially superseded (2026-09-13) (2026-06-12)

## Context

Earlier decisions used `acme/www` and `sign/id` to describe a Rails-hosted identity authority
inversion. That language no longer matches the target product and deployment vocabulary.

The accepted component names are now:

- Acme
- Sign
- Core
- Base
- Palm

Palm is the native API name formerly tracked as Port. New code, configuration, routes, audiences,
and plans must use Palm vocabulary. Existing filenames that contain `port` are retained for link
stability until a separate rename pass is accepted.

The withdrawn names `Deck`, `Bare`, and `Port` must not be used for new architecture vocabulary.

## Decision

Acme is the only Identity Provider and Authorization Server. Acme owns the issuer, subject identity,
OIDC/OAuth authorization endpoints, JWKS, and token issuance.

Sign is a special relying party. It may keep sign-related UI and special flows, but it is not an
Identity Provider and must not be a token issuer.

Core is the Next.js web relying party and browser-facing BFF. Core owns the web experience on a host
such as `jp.example.com`, receives the Acme callback, issues its own host-only web session cookie,
and calls server-side APIs from the Core server.

Base is a new Rails application foundation and control-plane subdomain split out of the older Core
concept. Base owns Rails-suitable application foundation behavior such as settings, preferences,
account, profile, organization, administration, complex mutations, audit-sensitive operations, and
work that should stay in Rails until Core is ready to own it. Base may render Rails views on a host
such as `www.jp.example.com`.

Palm is the native API Resource Server for iOS, Android, and other native clients. Palm does not use
browser cookies or Rails/Next.js sessions. Palm authenticates only Acme-issued access tokens
presented with `Authorization: Bearer`.

The exact Palm native implementation policy is not yet accepted. Do not commit route or API design
to a platform-specific native flow until native app registration, provider console settings, and
external documentation are checked. The fixed boundary is the URL and authority separation:
OAuth/OIDC public entry points belong to the common Acme/RP interface, while Palm-specific device
credential, token binding, refresh transport, or session transport APIs belong under API namespaces,
not under OAuth/OIDC endpoint names.

## Component Classification

| Component     | Classification                                                               |
| ------------- | ---------------------------------------------------------------------------- |
| Acme          | IdP / Authorization Server                                                   |
| Sign          | Special RP                                                                   |
| Core          | Next.js web RP / BFF                                                         |
| Base          | Rails foundation/control plane; RP for Rails views, Resource Server for APIs |
| Palm          | Native bearer-token API Resource Server                                      |
| iOS / Android | Public RPs                                                                   |

APIs are Resource Servers, not RPs. An RP initiates an authorization request and receives a
callback. A Resource Server validates access tokens and returns API responses.

## Web Boundary

The web path is:

```text
Browser -> Core / Next.js -> Acme /authorize -> Core callback -> Core server-side API calls
```

Browsers must not directly hold bearer access tokens. The browser holds only Core's host-only web
session cookie:

| Attribute | Value             |
| --------- | ----------------- |
| Name      | `__Host-core_sid` |
| Domain    | none              |
| Path      | `/`               |
| Secure    | `true`            |
| HttpOnly  | `true`            |
| SameSite  | `Lax`             |

`Domain=.example.com` must not be used for Core's browser session cookie.

Core and Base do not share cookies or sessions:

- Core session is not Base session.
- Core cookie is not Base cookie.
- Rails session is not Next.js session.
- Rails APIs must not trust a Next.js cookie.
- Next.js must not read a Rails session cookie.

The shared identity key is Acme `iss + sub`, not a shared browser cookie.

## Native And Palm Boundary

Native applications may act as public RPs. One expected direction is:

```text
iOS / Android -> Acme /authorize -> Acme /token -> Palm API
```

Native applications are expected to use Acme-issued credentials when they call Palm. Authorization
Code + PKCE is the expected OAuth/OIDC building block when the native RP flow is implemented, but
the concrete iOS/Android flow is still open. Palm must not issue OAuth/OIDC Access Tokens, Refresh
Tokens, or ID Tokens.

```json
{
  "iss": "https://acme.example.com",
  "sub": "acct_xxxxx",
  "aud": "palm-api",
  "client_id": "app-ios-rp",
  "scope": "palm.read palm.write",
  "exp": 1234567890
}
```

Palm validates signature, issuer, `aud = palm-api`, time claims, scope, client id, and subject, then
resolves the current user from Acme `iss + sub`.

DPoP remains supported and maintained as optional proof-of-possession infrastructure, but it is not
the default Palm, Core, or Base entry point. DPoP support being present does not approve a new flow
to rely on it. Before any concrete client or API flow adopts DPoP, the implementation and threat
model must be reviewed again, including client private-key storage, nonce handling, replay behavior,
and compatibility with the current Acme token boundary.

If Palm later stores or issues a local device artifact, that artifact is not an OAuth/OIDC access
token. Name it as a Palm local credential, device binding credential, or transport credential.

Do not encode iOS, Android, or other platform differences in OAuth/OIDC route paths. Express those
differences through client registration and request metadata such as `client_id`, `redirect_uri`,
PKCE, client registry metadata, device credential metadata, attestation type, or token binding
method.

Palm must not add platform-specific OAuth/OIDC callback routes such as:

- `/oauth/callback/ios`
- `/oauth/callback/android`
- `/ios/oauth/callback`
- `/android/oauth/callback`

Existing Palm `/oauth/callback*` routes are reserved native callback compatibility stubs only. They
must remain inert: no token exchange, no state mutation, no durable account/session writes, no
secret reflection, and no cookie issuance. Do not delete them until native app registration,
provider console settings, external documentation, and access logs have been checked. They are
deletion or consolidation candidates, not the formal Palm OAuth/OIDC entry point.

Future Palm device and token transport APIs should use explicit API namespaces such as:

- `/api/v0/device/*`
- `/api/v0/token/*`
- `/api/v0/session/*`

## Client And Audience Names

The initial client and audience vocabulary is:

- `sign-rp`
- `core-next-rp`
- `base-rails-rp`
- `app-ios-rp`
- `app-android-rp`
- `palm-api`

If Core needs to call Rails/Base APIs as a distinct API audience, use separate audiences such as
`core-api` or `base-api`. Do not mix Web/Core server-side APIs with the native Palm API surface.

## Token Use

ID Tokens are for RPs to verify login results. Access Tokens are for Resource Servers to authorize
API access. APIs must not use ID Tokens for authorization.

## JWKS Publication Boundary

JWKS publication follows token issuance and verification boundaries.

Acme JWKS is required because Acme is the Identity Provider and Authorization Server. Acme publishes
the public keys used to verify Acme-issued ID Tokens and Access Tokens.

Sign JWKS is retained as non-IdP public verification metadata. Sign is not an Identity Provider, but
Sign may issue signed transport, credential ceremony, or JumpRT-style tokens that another component
must verify. Those keys must remain separate from Acme OIDC token signing.

Base is expected to need its own JWKS endpoint if Base issues signed transport tokens or
Rails-foundation/control-plane tokens that another component verifies. Future Base key work should
introduce explicit Base issuer namespaces, such as `BASE_APP`, `BASE_COM`, and `BASE_ORG`, or
another clearly named Base-specific key boundary. Do not silently repurpose `CORE_*` namespaces as
Base namespaces.

Core JWKS remains undecided and must not be removed as part of the Base split. Core is the Next.js
web RP/BFF, and it may still need JWKS if the Core implementation signs tokens that external
verifiers consume or while Rails Core compatibility endpoints remain in service. A later explicit
decision may move Core JWKS ownership to the Next.js Core implementation or retire it if Core no
longer signs externally verified tokens.

## URL Direction

The URL direction is:

- Acme: `acme.example.com` or equivalent.
- Sign: `sign.example.com` or equivalent.
- Core: `jp.example.com`.
- Base: `www.jp.example.com` or another Rails foundation/control-plane subdomain.
- Palm: `palm.jp.umaxica.app` in the current Rails route configuration; final production URL shape
  remains open.

Palm URL selection remains separately adjustable. The responsibility, `palm-api` token audience, and
bearer-token boundary are decided first.

## Supersession

This ADR supersedes prior identity-authority material where that material treats `acme/www` as the
combined Rails Session, Token, Account, Preference, Authorization, and downstream-token authority or
treats `sign/id` as a credential-gateway host in the same Rails authority model.

Historical material remains useful for implementation risks, security vocabulary, migration notes,
and Rails controller lifecycle constraints. It must not override this component naming and
responsibility model. Historical `Port` / `port-api` references are superseded by `Palm` /
`palm-api` unless a later migration note explicitly marks them as compatibility vocabulary.

## Guardrails

Do not:

- treat Sign as an IdP;
- make Core authenticate to Sign;
- share cookies or sessions between Core and Base;
- use `Domain=.example.com` for Core's session cookie;
- let browser JavaScript hold bearer tokens;
- use ID Tokens for API authorization;
- make API controllers depend on Rails browser sessions;
- make iOS or Android depend on the Core BFF for API access;
- call an API a relying party when it is validating access tokens as a Resource Server.
- adopt DPoP for a new flow without first reviewing the current DPoP implementation and threat
  model;
- add Palm-specific OAuth/OIDC endpoint names for iOS or Android platform differences;
- call a Palm local credential or device binding credential an OAuth/OIDC access token.

## Related

- `adr/core-browser-jwt-cookie-transport-and-nextjs-zero-cookie-boundary.md`
- `adr/core-browser-credential-transport.md`
- `docs/architecture/acme-sign-core-base-port.md`
- GH issue #829
- `adr/identity-authority-boundary.md`
- `adr/acme-session-and-token-authority.md`
- `adr/sign-residual-idp-surface-retirement.md`
