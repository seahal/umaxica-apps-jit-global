# Core Browser Credential Transport For jp.umaxica.app

## Status

Superseded by `adr/core-browser-jwt-cookie-transport-and-nextjs-zero-cookie-boundary.md` on
2026-06-14.

## Supersedes

This ADR is retained for traceability. Its credential-cookie stripping language is narrower than the
accepted zero-cookie Next.js and Side boundary in
`adr/core-browser-jwt-cookie-transport-and-nextjs-zero-cookie-boundary.md`.

## Context

Core is composed of a Next.js UI and a Rails Core BFF/API. Browsers call `jp.umaxica.app/api/v0/*`
directly. The Core browser path needs to reuse the existing Rails JWT verification pipeline.

The previous accepted boundary prohibited browser-held bearer or access tokens and allowed only
`__Host-core_sid`. Core browser credential transport now uses an access JWT carried only by an
HttpOnly cookie.

## Decision

The Core browser may hold an access JWT only with this cookie transport:

| Attribute | Value                |
| --------- | -------------------- |
| Name      | `__Host-core_access` |
| Secure    | `true`               |
| HttpOnly  | `true`               |
| SameSite  | `Strict`             |
| Path      | `/`                  |
| Domain    | none                 |
| TTL       | short                |
| Audience  | `core-browser`       |

The Core browser refresh credential must be opaque:

| Attribute | Value                   |
| --------- | ----------------------- |
| Name      | `__Secure-core_refresh` |
| Secure    | `true`                  |
| HttpOnly  | `true`                  |
| SameSite  | `Strict`                |
| Domain    | none                    |
| Path      | `/api/v0/token/refresh` |

The OIDC transaction cookie is:

| Attribute | Value              |
| --------- | ------------------ |
| Name      | `__Host-core_oidc` |
| Secure    | `true`             |
| HttpOnly  | `true`             |
| SameSite  | `Lax`              |
| Path      | `/`                |

The OIDC transaction cookie must be deleted after callback handling.

JavaScript must not read access credentials, refresh credentials, or OIDC transaction credentials.
The Next.js origin must not receive access, refresh, or OIDC transaction cookies. Rails Core is the
only consumer of `__Host-core_access`.

Cloudflare must strip credential cookies before forwarding requests to the Next.js origin.
Cloudflare must strip all cookies before forwarding requests to `side.jp.umaxica.app`. Next.js must
not set Core credential cookies.

## Transport Binding

Audience and transport are bound:

- `aud=core-browser` is accepted only from cookie transport.
- `aud=palm-api` is accepted only from Authorization bearer transport. The older `port-api`
  vocabulary is superseded by Palm.
- `aud=side-service` is service-token-only and never user-bound.

Reverse transport must be rejected.

## CSRF

Because Core browser uses cookie transport, Rails CSRF verification is mandatory for unsafe methods.
`SameSite=Strict` is defense in depth, not the primary CSRF control.

## Consequences

This supersedes the previous `__Host-core_sid`-only browser model. The design is no longer a classic
opaque-session BFF.

The compensating controls are:

- HttpOnly cookies;
- short access-token TTL;
- opaque refresh tokens;
- refresh rotation and revocation;
- audience-to-transport binding;
- CSRF verification;
- Cloudflare cookie stripping;
- no user-bound server-side rendering;
- no credentials sent to the Next.js origin.

## Rejected Alternatives

### `__Host-core_sid` Only

This is the more classical BFF model, but it does not reuse the existing JWT access-token pipeline
directly.

### Browser-Readable Access Token

Rejected. JavaScript must never read access or refresh credentials.

### Next.js RP/BFF

Rejected. Next.js must not hold important credentials.

## Verification

- Cloudflare Trace confirms `Cookie` is stripped on Next.js and Side routes.
- Request tests confirm cookie flags and paths.
- Request tests confirm `aud=core-browser` through an Authorization header is rejected.
- Request tests confirm `aud=palm-api` through cookie transport is rejected.
- CSRF tests cover unsafe methods.
- Next.js ingress tests fail if `__Host-core_access` reaches Next.js.

## Related

- `adr/acme-sign-core-base-port-boundary.md`
- `docs/architecture/acme-sign-core-base-port.md`
- GH issue #829
