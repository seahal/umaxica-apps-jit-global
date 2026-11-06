# RFC 9068 Access Token Profile

## Status

Accepted (2026-09-10). This profile applies to Auth access JWTs only. Preference JWTs use the
separate realm contract in
[`preference-realm-jwt-and-host-bound-browser-binding.md`](preference-realm-jwt-and-host-bound-browser-binding.md).

## Context

First-party Auth access JWTs used a private header `typ`, duplicated payload typing, a numeric
`sub`, a private `scp` array, optional `client_id`, and a registered `act` claim whose meaning
collided with RFC 8693. Resource-type suffixes were also folded into `iss`.

UMAXICA needs a stable Auth access-token contract that matches RFC 9068 as closely as possible while
keeping the existing ES384-only key policy.

## Decision

UMAXICA Auth access JWTs follow RFC 9068 in token structure, claims, semantics, and validation
requirements. ES384 is the sole supported signing algorithm. UMAXICA intentionally does not
implement the RFC 9068 §2.1 requirement that conforming authorization servers and resource servers
include RS256 among their supported signature algorithms.

This is an RFC 9068 profile with one documented interoperability deviation. ES384 itself is
permitted by RFC 9068; the deviation is the absence of RS256 support. `alg=none` and every algorithm
other than ES384 are rejected. The verifier does not treat the token-provided `alg` as authorization
to select an arbitrary algorithm.

Auth access JWTs use JOSE:

```json
{ "alg": "ES384", "kid": "...", "typ": "at+jwt" }
```

Required claims: `iss`, `exp`, `aud`, `sub`, `client_id`, `iat`, `jti`.

### Claim semantics

- `iss` identifies the Auth authorization server and environment. Auth access tokens share
  `AUTH_JWT_ISSUER` without a resource-type suffix. OIDC access tokens use the issuer URL defined by
  the active OIDC profile.
- `aud` identifies the resource server. First-party Auth access uses
  `AUTH_JWT_{CLIENT,OPERATOR,VISITOR}_AUDIENCES` (`umaxica-api-*`).
- `client_id` identifies the first-party OAuth client that obtained the token
  (`AUTH_JWT_{CLIENT,OPERATOR,VISITOR}_CLIENT_ID`). It is not copied from `aud`.
- `sub` is a string containing the resource owner's durable numeric id as a decimal string. OIDC
  access tokens continue to use `OidcSubject`.
- `scope` is the RFC 8693 space-delimited string. Actor domain is `domain:client|operator|visitor`
  rather than a registered `act` claim.
- `acr`, `nbf`, `sid`, `authn_ctx`, `amr`, and `cnf` remain documented private or optional claims.

Auth token families are distinguished by issuer, audience, client identity, and scope. Payload `typ`
is not reintroduced.

### Keyring selection

The verification keyring is chosen by the caller (`jwt_issuer_id:`), never inferred from the request
host. When no keyring is named, the `auth` keyring is used; a token signed by any other keyring then
fails as an unknown kid.

### Validation

Verifiers require `typ=at+jwt`, `alg=ES384`, a `kid` that resolves in the expected keyring, a valid
signature, the exact issuer, an expected audience, `exp`, `iat`, and `nbf` when present. `sub`,
`client_id`, `iss`, and `jti` must be non-empty strings; `iat`, `exp`, and `nbf` must be integers;
`scope` is required and must be a non-empty string. `scp`, `act`, and payload `typ` are rejected.
Malformed claims are rejected, never coerced. The clock-skew allowance is a fixed 30 seconds
(`SecurityJwtRfc9068AccessTokenProfile::CLOCK_SKEW_LEEWAY_SECONDS`), not an environment setting.

### Environment isolation

Development, test, and production use non-overlapping Auth issuer and key namespaces:

- Local Auth kids are prefixed with the Rails environment, so a development token never verifies
  under test and vice versa. Local audience names (`umaxica-api-*`) name resource servers and may be
  shared between development and test; isolation there rests on issuer and key.
- Production must set every Auth issuer, audience, and client identifier explicitly (one-argument
  `ENV.fetch`). `AuthenticationJwtConfiguration.validate!` runs at boot and refuses to start when an
  issuer or audience contains a development/test marker, a loopback host, or the reserved `.test`
  TLD.
- Development/test Auth kids are not publishable outside local Rails environments.
- Auth audience configuration has no fallback: the keyring audiences are the union of the
  per-resource `AUTH_JWT_*_AUDIENCES`; the Jump gateway audience is required outside local
  environments.
- Preference tokens use independent `PREFERENCE_APP_JWT_*`, `PREFERENCE_COM_JWT_*`, and
  `PREFERENCE_ORG_JWT_*` keyrings. Their `typ=JWT`, closed seven-claim shape, fixed realm audience,
  400-day lifetime, and no-compatibility rule belong to the Preference ADR linked above.

## Consequences

- Existing development/test Auth JWTs become invalid after this change. Dual-issuance is not
  provided.
- Rails consumers read `scope` instead of `scp` and derive actor type from `domain:*`.
- Frontend code does not decode these JWTs for authorization.
