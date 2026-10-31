# Cookie Domain Scope

## Current Behavior

Authentication and RP credential cookies are host-local transport slots. The cookie name
describes the transport role, not the logical credential kind.

| Role                | Secure context name         | Insecure dev/test name |
| ------------------- | --------------------------- | ---------------------- |
| Auth access         | `__Host-auth_access`        | `auth_access`          |
| Auth refresh        | `__Host-auth_refresh`       | `auth_refresh`         |
| Auth DBSC / binding | `__Host-auth_dbsc`          | `auth_dbsc`            |
| RP access           | `__Host-rp-access`          | `rp-access`            |
| RP refresh          | `__Host-rp-refresh`         | `rp-refresh`           |

These credential cookies are host-only and use `Path=/`; secure contexts use `Secure` and the
`__Host-` prefix. They never carry a `Domain` attribute.

Preference transport has a separate contract:

| Role | Cookie | Scope and use |
| --- | --- | --- |
| Anonymous Preference JWT | `__Secure-preference` | Realm-domain scoped, `HttpOnly`, signed snapshot used for runtime reads |
| Language display mirror | `language` | Realm-domain scoped and JavaScript-readable |
| Experience display mirror | `__Secure-experience` | Realm-domain scoped and JavaScript-readable |
| Consent and Web Push binding | `__Host-preference_binding` | Host-only, `HttpOnly`; proves browser ownership for bounded reads/writes |

The three shared Preference cookies are issued from the same database snapshot. APP, ORG and COM
remain separate JWT realms even where a realm's sibling subdomains share the cookie domain. A signed
Preference JWT does not authorize consent reads by itself; the host-only binding remains required.
Preference refresh, Preference DBSC/assurance, actor consent mirrors and per-item Preference cookies
are retired.

Cookie names must not include `global`, `regional`, `app`, `com`, `org`, `core`, or `palm`. Auth's
`__Host-auth_access` and a Core RP's `__Host-rp-access` are separate cookies because the browser
stores them per host.

## JavaScript-readable Preference Mirrors

Rails writes only the non-secret `language` and `__Secure-experience` display mirrors. They are
apex-scoped (for example, `.umaxica.app`) for browser UI, Hono compatibility and edge rendering.
Rails request code does not use them as authoritative Preference input. The signed JWT is the
runtime display projection.

These mirrors must not carry session IDs, access tokens, refresh tokens, Preference JWTs, DBSC
values, authorization grants, ceremony secrets, one-time tokens, raw credentials, or
credential/session authority data. Request context such as `ri` remains in the URL and is not
mirrored to a cookie.

Browser-visible hosts and internal Rails/pod origins should use the `PUBLIC_` and `PRIVATE_`
boundary vocabulary in docs and config. That keeps cookie transport discussions separate from
host-ownership discussions.

## Authority and Transport Boundaries

Credential kind is enforced by issuer, audience, validator contract, client classification, and
transport binding:

- Visa is the only physical Authorization Server and token authority; Base is the browser RP.
- Auth is ceremony-only. It does not own issuer, token, Browser Session, or RP Session authority.
- Core/Warp/Edit RP callbacks store Visa-issued credentials in the RP cookie slots above. The exact
  RP client ID, issuer, audience, and resource type are checked before the cookie is used.
- `SignRefreshTokenService` is a legacy compatibility subclass; new refresh authority references
  should use `AcmeRefreshTokenService`.
- Legacy `core-browser` credentials are not accepted by the Core browser API as RP credentials.
- Palm browser credentials use the common Browser RP contract with the `palm-app` audience and
  host-only RP cookies.
- Palm and Core RP cookie validators reject sibling RP client bindings. Palm's former native bearer
  API is retired, and no bearer-to-browser-cookie bridge exists.
- Auth does not issue or consume Core/Base regional browser cookies; Visa and each RP keep their
  host-local authority and RP cookie boundaries.

Because `__Host-` requires `Path=/`, authentication and RP refresh cookies are not path-restricted.
Refresh endpoint exclusivity is a server-side transport and endpoint contract. Preference cookies
have their own documented domain scopes and do not use Preference refresh or DBSC endpoints.

## Related

- `adr/cookie-domain-scope-by-surface.md` — historical cookie naming decision; its Preference
  refresh/DBSC rows are superseded by the current Preference architecture.
- `docs/security/refresh-token-rotation.md`
- `docs/reference/subdomains.md`
