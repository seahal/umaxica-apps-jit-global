# RFC 9068 Access Token Profile

## Status

Accepted (2026-09-10)

## Context

First-party `auth_access` and `preference_access` JWTs used a private header `typ`, duplicated
payload typing, a numeric `sub`, a private `scp` array, optional `client_id`, and a registered
`act` claim whose meaning collided with RFC 8693. Resource-type suffixes were also folded into
`iss`.

UMAXICA needs a stable access-token contract that matches RFC 9068 as closely as possible while
keeping the existing ES384-only key policy.

## Decision

UMAXICA JWT access tokens follow RFC 9068 in token structure, claims, semantics, and validation
requirements. ES384 is the sole supported signing algorithm. UMAXICA intentionally does not
implement the RFC 9068 §2.1 requirement that conforming authorization servers and resource servers
include RS256 among their supported signature algorithms.

This is an RFC 9068 profile with one documented interoperability deviation. ES384 itself is
permitted by RFC 9068; the deviation is the absence of RS256 support. `alg=none` and every
algorithm other than ES384 are rejected. The verifier does not treat the token-provided `alg` as
authorization to select an arbitrary algorithm.

Both `auth_access` and preference access tokens use JOSE:

```json
{ "alg": "ES384", "kid": "...", "typ": "at+jwt" }
```

Required claims: `iss`, `exp`, `aud`, `sub`, `client_id`, `iat`, `jti`.

### Claim semantics

- `iss` identifies the authorization server for that token family and environment. Cookie
  `auth_access` tokens share `AUTH_JWT_ISSUER` (no resource-type suffix). Preference tokens use
  `PREFERENCE_JWT_ISSUER` because they are issued from a distinct keyring. OIDC access tokens keep
  the Acme issuer URL.
- `aud` identifies the resource server. First-party cookie auth uses
  `AUTH_JWT_{CLIENT,OPERATOR,VISITOR}_AUDIENCES` (`umaxica-api-*`). Preference tokens use the
  surface hosts that consume the host-scoped cookie.
- `client_id` identifies the first-party OAuth client that obtained the token
  (`AUTH_JWT_{CLIENT,OPERATOR,VISITOR}_CLIENT_ID`, `PREFERENCE_JWT_CLIENT_ID`). It is not copied
  from `aud`.
- `sub` is a string. For first-party cookie `auth_access` it is the resource owner's durable
  numeric id as a decimal string. For preference tokens it is the preference record `public_id`
  (the preference document identity; guests have no account subject). OIDC access tokens continue
  to use `OidcSubject`.
- `scope` is the RFC 8693 space-delimited string. Actor domain is `domain:client|operator|visitor`
  rather than a registered `act` claim. Preference tokens use `scope=preference`.
- `acr`, `nbf`, `sid`, `authn_ctx`, `amr`, `cnf`, and preference application data remain as
  documented private or optional claims. Application preferences live only in the private
  `preferences` object.

Token families are distinguished by issuer, audience, client identity, and scope. Payload `typ` is
not reintroduced.

### Keyring selection

The verification keyring is chosen by the caller (`jwt_issuer_id:`), never inferred from the
request host. When no keyring is named, the `auth` keyring is used; a token signed by any other
keyring then fails as an unknown kid.

### Validation

Verifiers require `typ=at+jwt`, `alg=ES384`, a `kid` that resolves in the expected keyring, a valid
signature, the exact issuer, an expected audience, `exp`, `iat`, and `nbf` when present. `sub`,
`client_id`, `iss`, and `jti` must be non-empty strings; `iat`, `exp`, and `nbf` must be integers;
`scope` is required and must be a non-empty string. `scp`, `act`, and payload `typ` are rejected.
Malformed claims are rejected, never coerced. The clock-skew allowance is a fixed 30 seconds
(`SecurityJwtRfc9068AccessTokenProfile::CLOCK_SKEW_LEEWAY_SECONDS`), not an environment setting.

Preference tokens additionally require `scope=preference`, `sub == public_id`, a `host` claim equal
to the host scope computed for the request host and sharing its registrable domain, and an `aud`
that contains that host scope.

### Environment isolation

Development, test, and production use non-overlapping issuer and key namespaces:

- Local issuers default to `urn:umaxica:<rails-env>:auth` and `urn:umaxica:<rails-env>:preference`,
  and local kids are prefixed with the Rails environment, so a development token never verifies
  under test and vice versa. Local audience names (`umaxica-api-*`) name resource servers and may
  be shared between development and test; isolation there rests on issuer and key.
- Production must set every issuer, audience, and client identifier explicitly (one-argument
  `ENV.fetch`). `AuthenticationJwtConfiguration.validate!` and `PreferenceJwtConfiguration.validate!`
  run at boot and refuse to start when an issuer or audience contains a development/test marker,
  a loopback host, or the reserved `.test` TLD.
- Development/test kids are not publishable outside local Rails environments.
- No audience list falls back to defaults: auth keyring audiences are the union of the per-resource
  `AUTH_JWT_*_AUDIENCES`, preference audiences come only from the boot base hosts, and the jump
  gateway audience is required outside local environments.

## Consequences

- Existing development/test JWTs become invalid after this change. Dual-issuance is not provided.
- Rails consumers read `scope` instead of `scp` and derive actor type from `domain:*`.
- Frontend code does not decode these JWTs for authorization.
