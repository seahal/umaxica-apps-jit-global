# Cookie Domain Scope By Surface

## Status

Accepted on 2026-05-17.

> **Update (2026-06-18):** Credential cookie names are now role-based transport names. Production
> uses `__Host-auth_access`, `__Host-auth_refresh`, `__Host-auth_dbsc`, `__Host-preference_access`,
> `__Host-preference_refresh`, and `__Host-preference_dbsc`. Development and test use the same names
> without the `__Host-` prefix. Cookie names must not encode `global`, `regional`, `app`, `com`,
> `org`, `core`, or `palm`. Credential meaning is enforced by host-only scope, issuer, audience,
> validator contract, client classification, and transport binding, not by the cookie name.
> Preference credential cookies are host-only; legacy `{app,com,org}_preference_*` and old unscoped
> names are short-term read/delete compatibility only.

> **Partial supersession (2026-06-02):** The vocabulary and security properties in this ADR remain
> useful, but authority ownership is superseded by `adr/identity-authority-boundary.md`. `acme/www`
> owns session, token, account, preference, authorization, downstream-token trust, and step-up
> freshness. `sign/id` owns only credential inventory and short-lived credential ceremony state.

## Context

`Core::CookieDomain.for` can return an apex-scoped domain (e.g. `.example.com`). A cookie set with
that domain is readable by **every subdomain** on the acme. A cookie set with no `domain` attribute
is **host-only** and is readable only by the exact host that set it.

`Core::CookieOptions.for` controls this through the `domain:` keyword:

- `domain: true` (default) -> calls `Core::CookieDomain.for` -> apex-scoped, cross-subdomain.
- `domain: false` -> no `domain` attribute -> host-only, not shared across subdomains.

A recurring misreading is that the accepted-risk note in `app/services/core/cookie_domain.rb:84-87`
("auth cookies are readable by ALL subdomains ... mitigated by httponly") applies to **all** refresh
tokens, including the authentication surface. It does not. The two surfaces deliberately use
opposite domain scoping.

## Decision

Credential cookie names are role-based transport slots:

- `auth_access`, `auth_refresh`, and `auth_dbsc` carry auth credentials for the current host.
- `preference_access`, `preference_refresh`, and `preference_dbsc` carry preference credentials for
  the current host.
- Secure contexts add the `__Host-` prefix. `__Host-` cookies must be Secure, use `Path=/`, omit
  `Domain`, and remain host-only.
- Cookie names must not encode `global`, `regional`, `app`, `com`, `org`, `core`, or `palm`.

The same cookie name can exist on different hosts without conflict because these are host-only
cookies. Acme's `__Host-auth_access`, Sign's `__Host-auth_access`, and Core/Base browser hosts'
`__Host-auth_access` are separate browser cookie jar entries. The credential kind is enforced by the
issuer, audience, validator contract, client classification, and accepted transport.

Preference credential cookies are no longer apex-scoped. New writes use only the unscoped
`preference_*` role names, host-only. Legacy `{app,com,org}_preference_*` and old unscoped
`__Secure-preference_*` names may be read for a short compatibility window and must be deleted after
successful reissue or refresh.

Palm is a browser RP and uses host-only browser credential cookies with the `palm-app` audience.
The retired native API and `palm-api` bearer audience do not participate in the current contract.
Acme/Sign do not issue or consume Core/Base regional browser cookies. Sign is a special RP, not a
token or refresh authority; refresh rotation authority is `AcmeRefreshTokenService`.

## Evidence

- `app/services/core/cookie_options.rb:8-22` — `domain:` keyword gates `Core::CookieDomain.for`.
- `app/services/core/cookie_domain.rb:84-94` — apex scoping (`best_effort_apex`) and the
  accepted-risk note.
- `app/controllers/concerns/authentication_cookie_name.rb` — auth role-name mapper.
- `app/controllers/concerns/preference_cookie_name.rb` — preference role-name mapper plus legacy
  read/delete name inventory.
- `app/controllers/concerns/authentication_cookie_service.rb` — authentication cookies use
  `domain: false` and `path: "/"`.
- `app/controllers/concerns/preference_base.rb` — preference credential cookies use `domain: false`
  and `path: "/"`; legacy preference credential cookies are deleted during reissue/refresh.
- `app/controllers/concerns/preference/base.rb:139-145` (`set_color_theme`) and
  `app/controllers/concerns/preference/consented_buffer.rb:23-29` — apex-scoped, intentionally
  `httponly: false` non-token preference cookies (theme, consent flag).

## Consequences

- Authentication and preference credential cookies are isolated by exact host.
- Refresh cookies also use `Path=/` in secure contexts because `__Host-` requires it. Endpoints that
  must reject refresh credentials outside refresh flows must enforce that server-side through
  transport and endpoint contracts, not cookie path.
- Cross-host preference sharing cannot rely on apex-scoped credential cookies. Host/surface context
  and the DB preference record resolve the preference boundary.

## Related

- `docs/security/cookie-domain-scope.md` — current behavior reference.
- `docs/security/refresh-token-rotation.md`
- `adr/refresh-revoke-aal-downgrade-and-replay-hardening.md`
- `adr/theme-preference-cookie-and-param-contract.md`
