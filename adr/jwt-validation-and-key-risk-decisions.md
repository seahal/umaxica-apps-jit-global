# JWT Temporal Validation and Upstream Risk Decisions

Date: 2026-10-22

Status: Accepted

Approval: repository owner instruction in the session following the session/JWT/OAuth audit.

## Context

The application uses the Ruby `jwt` gem, currently 3.3.0. Its `JWT.decode` options are
`verify_expiration` and `verify_not_before`; `verify_exp` and `verify_nbf` are ignored. Expiration
and not-before checks default to enabled, which hid the incorrect names during normal decoding
but prevented the intended expiration exemption during logout and revocation.

The gem applies the general `leeway` to `exp` and `nbf`. The `iat` check needs its separate
`verify_iat: { leeway: 30 }` option. Setting only `verify_iat: true` allows no future clock skew.

Apple sign-in uses `omniauth-apple` 1.4.0 and `json-jwt` 1.17.2. The upstream strategy verifies
the token using the key fetched from Apple's fixed JWKS endpoint but supplies no signature
algorithm allowlist. With a synthetic RSA key, its public authentication boundary accepts both
RS256 and RS512. This observation does not mean that Apple currently issues RS512 tokens.

## Decisions

### First-party temporal validation

Auth and Preference access tokens, OIDC ID tokens, OP tokens verified by separated RPs, and OIDC
client assertions MUST use the existing fixed 30-second clock-skew allowance for `iat`.
Applicable `exp` and `nbf` checks retain their 30-second allowance. Client assertions retain their
additional strict expiration check at the token endpoint.

The application MUST pass the gem's supported option names. Normal access-token authentication
MUST validate expiration. The explicit `decode_allow_expired` path MAY omit only expiration
verification for logout/revocation identification; signature, issuer, audience, required claims,
`iat` and `nbf` checks remain active. This path does not establish authenticated request authority.

Boundary tests MUST freeze the reference clock and exercise the nearest integer timestamps below,
at and above each changed 30-second boundary.

### Accepted Apple upstream algorithm behavior

The owner accepts the upstream strategy's absence of an explicit algorithm allowlist for this
change. The application will retain that behavior and its existing mandatory nonce enforcement;
it will not fork or patch the strategy to enforce RS256 only.

The accepted residual risk is that algorithm policy follows the dependency rather than an
application-owned fixed allowlist. This acceptance preserves signature, fixed JWKS source,
issuer, audience, expiration and nonce validation; it does not authorize unsigned or forged
tokens, arbitrary verification keys or attacker-selected JWKS URLs.

The Apple Minitest contract MUST independently cover RS256 and RS512 acceptance with a trusted
synthetic RSA key and rejection with a different signing key. A dependency upgrade that changes
either result requires review of this decision before updating the assertion. These are token
verification behavior tests, not dependency-installation tests.

### Rails session key operations

The owner accepts operational protection of `secret_key_base` and key rotation on suspected or
confirmed disclosure as the response for Rails session-cookie key compromise. This change adds no
new session-key mechanism and performs no rotation.

Rotation MUST retire the compromised key from cookie verification, including any verification
fallbacks. Retaining it through a compatibility rotation would preserve an attacker's ability to
forge cookies. Sessions protected by the retired key become unusable and users must authenticate
again. Rails session keys and JWT signing keys are separate; rotating one does not rotate the other.

This operational decision is not evidence that deployed environments have distinct keys or that
a key has never been disclosed. Environment-specific key provisioning remains necessary.

## References

- [First-party access-token profile](rfc9068-access-token-profile.md)
- [JWT key operations](../docs/operations/jwt-key-rotation.md)
- `test/values/jwt_temporal_validation_test.rb`
- `test/contracts/omniauth_apple_strategy_contract_test.rb`
