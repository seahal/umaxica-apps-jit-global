# JWT Key Rotation

> **Partially superseded by Identity Authority inversion:** JWT key rotation remains required, but
> token authority belongs to `acme/www`. `sign/id` is ceremony-only and must not issue sessions,
> refresh tokens, downstream tokens, or step-up freshness. Existing sign-side physical tables/models
> do not imply sign-side authority.

## Scope

This runbook covers Auth access tokens, Preference tokens, OIDC ID Tokens, and issuer-surface JWKS.
Jump RT has additional redirect-specific steps in `docs/operations/jump-rt-key-rotation.md`.

## Runtime Model

`Jit::Security::Jwt::Registry` is the source of truth built at boot. Request handlers must not parse
keyset JSON, read credentials, read files, call KMS, or make network calls for local signing or JWKS
rendering.

Responsibility boundaries:

- `Jit::Security::Jwt` is the low-level JWT/JWK/JWKS/key registry layer.
- `Security::TokenLifetimes` owns application token-family TTL and old-kid verification windows.
- `Security::Jwt::*Codec` classes own token-family encode/decode details for Auth access tokens,
  Preference JWTs, OIDC ID Tokens, and JumpRT.
- Controllers and concerns should call the existing services/facades; they should not read key
  material or construct JWKS documents.

Current private keys are loaded once. Current public JWKs are derived once from those private keys.
Legacy public keys are loaded as grace keys. Revoked kids are rejected even when stale public JWKS
documents still contain them.

The registry validates the same invariants in every environment. Non-empty issuer records require an
issuer, audience, active kid, active private key, valid public JWK fields, and an active key that is
present in JWKS. Optional surface records with no active kid and no keys may remain empty.

`*_PUBLIC_KEYSET` must be public JWK Set JSON:

```json
{
  "keys": [
    {
      "kty": "EC",
      "crv": "P-384",
      "kid": "...",
      "alg": "ES384",
      "use": "sig",
      "x": "...",
      "y": "..."
    }
  ]
}
```

Do not store private DER, private PEM, or private JWK fields in public keysets.

## Required Key Names

Auth:

```text
AUTH_JWT_ACTIVE_KID
AUTH_JWT_PRIVATE_KEYSET
AUTH_JWT_PUBLIC_KEYSET
AUTH_JWT_REVOKED_KIDS
AUTH_JWT_ISSUER
AUTH_JWT_CLIENT_AUDIENCES
AUTH_JWT_VISITOR_AUDIENCES
AUTH_JWT_OPERATOR_AUDIENCES
AUTH_JWT_CLIENT_CLIENT_ID
AUTH_JWT_VISITOR_CLIENT_ID
AUTH_JWT_OPERATOR_CLIENT_ID
```

All three auth audience variables are required and must contain non-empty, comma-separated values.
Audience values must not overlap across client, visitor, and operator resource types; missing,
blank, or overlapping configuration fails closed. In production, issuers and audiences containing
a development/test marker, a loopback host, or the `.test` TLD are rejected at boot. The clock-skew
leeway is fixed at 30 seconds; there is no leeway environment variable.

Preference:

```text
PREFERENCE_JWT_ACTIVE_KID
PREFERENCE_JWT_PRIVATE_KEYSET
PREFERENCE_JWT_PUBLIC_KEYSET
PREFERENCE_JWT_REVOKED_KIDS
PREFERENCE_JWT_ISSUER
PREFERENCE_JWT_CLIENT_ID
```

Preference audiences are the boot base hosts (`base_service`, `base_corporate`, `base_staff`);
there is no audience environment variable and no fallback list. A Preference issuer record with
keys but no configured base hosts fails validation at boot.

Issuer-surface JWKS:

```text
JWT_<NAMESPACE>_ACTIVE_KID
JWT_<NAMESPACE>_PRIVATE_KEY
JWT_<NAMESPACE>_PUBLIC_KEYSET
JWT_<NAMESPACE>_REVOKED_KIDS
```

Production should source private material from the production secret backend. Rails credentials are
acceptable for development and test.

## Rotation Procedure

1. Generate a P-384 ES384 key.
2. Choose a globally unique `kid`.
3. Store the new private key in the secret backend.
4. Publish the new public JWK as a grace key.
5. Deploy and confirm boot validation passes.
6. Switch `ACTIVE_KID` to the new `kid`.
7. Deploy all signers.
8. Confirm new tokens use the new `kid`.
9. Keep old public keys until `max token TTL + leeway + CDN max stale`.
10. Remove old public keys after the grace window.

Current old-kid verification windows are:

- Auth access JWT:
  `Security::TokenLifetimes::AUTH_ACCESS_JWT_TTL + JWKS_ROTATION_LEEWAY + CDN_STALE_LEEWAY`.
- Preference JWT:
  `Security::TokenLifetimes::PREFERENCE_JWT_TTL + JWKS_ROTATION_LEEWAY + CDN_STALE_LEEWAY`.
- OIDC ID Token:
  `Security::TokenLifetimes::OIDC_ID_TOKEN_TTL + JWKS_ROTATION_LEEWAY + CDN_STALE_LEEWAY`.
- JumpRT: `Security::TokenLifetimes::JUMP_RT_TTL + JWKS_ROTATION_LEEWAY + CDN_STALE_LEEWAY`.

Old verification keys should be public JWKs only. Do not keep old private keys in production runtime
unless rollback still requires the previous signer.

## Emergency Revocation

1. Add the compromised `kid` to the relevant `*_REVOKED_KIDS`.
2. Deploy verifiers first.
3. Install a new private key and active `kid`.
4. Remove the compromised public key from public JWKS.
5. Purge CDN JWKS caches.
6. Confirm compromised `kid` is rejected.

## Rollback

Keep old private key secret versions until rollback is closed. To roll back, restore the old
`ACTIVE_KID`, restore/select the matching private-key secret version, keep both public JWKs in JWKS
until both token populations expire, then deploy.
