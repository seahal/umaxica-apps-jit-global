# Jump RT JWT Key Rotation

## Purpose

This runbook manages ES384 signing keys for Jump redirect tokens.

Jump RT keys are issuer-surface scoped. Do not reuse one private key or `kid` across `app`, `com`,
and `org`, or across `sign`, `acme`, and `core` issuer groups.

Issuer surfaces:

- `SIGN_APP`, `SIGN_COM`, `SIGN_ORG`
- `ACME_APP`, `ACME_COM`, `ACME_ORG`
- `CORE_APP`, `CORE_COM`, `CORE_ORG`

## Runtime Contract

At boot, `Jit::Security::Jwt::Registry` builds immutable issuer/key records:

- current private key is loaded once from Rails credentials or the production secret backend;
- current public JWK is derived once from the current private key;
- legacy/grace public JWKs are loaded from `JWT_<NAMESPACE>_PUBLIC_KEYSET`;
- revoked kids are loaded from `JWT_<NAMESPACE>_REVOKED_KIDS`;
- malformed JWKs, private JWK fields, wrong `alg`, wrong `kty`, wrong `crv`, active/public mismatch,
  and non-default duplicate kids fail boot.

The JWKS endpoint must only render the prebuilt public JWKS. It must not read private keys,
credentials, files, KMS, or the network while serving a request.

JumpRT token-family behavior is implemented through `SecurityJwtJumpRtTokenCodec` while
`JumpRtIssuer` and `JumpRtReturnVerifier` remain the service entry points. URL normalization,
return-policy checks, JWKS fetch/cache behavior, and one-time replay caching stay in JumpRT
services.

Inbound Jump-gateway return tokens are verified only with the Jump public JWKS derived as
`{PUBLIC_JUMP_GATEWAY_URL}/.well-known/jwks.json`. The lifetime cap is 30 seconds. Clock leeway is
5 seconds. A JWKS fetch failure fails closed; Rails does not keep a stale JWKS fallback and does
not store the Jump gateway private key.

## Key States

- `active`: used for new signing and included in JWKS.
- `grace`: verification only; included in JWKS until all old tokens expire.
- `retired`: removed from JWKS after the grace window.
- `revoked`: rejected by verifiers even if a CDN or RP still has a stale JWKS copy.

Revocation is not the same as retirement. Retirement handles normal rotation. Revocation handles
suspected private-key compromise.

## Environment and Secret Names

```text
JWT_<NAMESPACE>_ACTIVE_KID
JWT_<NAMESPACE>_PUBLIC_KEYSET
JWT_<NAMESPACE>_REVOKED_KIDS
JWT_<NAMESPACE>_PRIVATE_KEY
```

`ACTIVE_KID`, `PUBLIC_KEYSET`, and `REVOKED_KIDS` are environment configuration. Private keys are
secret values. In production they should come from the production secret backend, such as AWS KMS or
Secrets Manager, exposed to the app through the same logical credential name.

`PUBLIC_KEYSET` must be public JWK Set JSON or a JSON array of public JWKs. It must not contain
private DER, private PEM, or private JWK fields.

Keep old private keys available in the secret backend until rollback is no longer possible. The
offline source copy should remain in controlled physical custody; the cloud secret version should
also be retained while its public key is in `grace`.

## Normal Rotation

1. Generate a new P-384 private key.
2. Choose a globally unique `kid`, for example `sign-app-jump-rt-es384-prod-2026-06-a`.
3. Store the new private key as the issuer surface `JWT_<NAMESPACE>_PRIVATE_KEY` secret version.
4. Add the new public JWK to `JWT_<NAMESPACE>_PUBLIC_KEYSET` while keeping the old active public
   JWK.
5. Deploy and confirm boot validation passes.
6. Change `JWT_<NAMESPACE>_ACTIVE_KID` to the new `kid`.
7. Deploy issuer instances.
8. Issue a smoke token and confirm its header has `alg: ES384` and the new `kid`.
9. Confirm Jump accepts the new token.
10. Keep the old public key in JWKS for `max token TTL + leeway + CDN max stale`.
11. Remove the old public key from `PUBLIC_KEYSET`.
12. Keep the old private key secret version until rollback is closed.

The normal old-kid verification window is
`Security::TokenLifetimes::JUMP_RT_TTL + JWKS_ROTATION_LEEWAY + CDN_STALE_LEEWAY`. Old verification
keys should be public JWKs only after rollback no longer needs the previous private signer.

## Rollback

Rollback is safe only if the previous private key is still available.

1. Restore `JWT_<NAMESPACE>_ACTIVE_KID` to the previous `kid`.
2. Restore or select the previous `JWT_<NAMESPACE>_PRIVATE_KEY` secret version.
3. Keep both previous and attempted-new public JWKs in `PUBLIC_KEYSET`.
4. Deploy issuer instances.
5. Confirm boot validation passes and new tokens use the previous `kid`.
6. Do not remove the attempted-new public JWK until tokens already issued with it have expired.

## Emergency Revocation

If a private key may be compromised:

1. Add the compromised `kid` to `JWT_<NAMESPACE>_REVOKED_KIDS`.
2. Add the compromised Jump return signing `kid` to `JUMP_RETURN_REVOKED_KIDS` on Rails RPs when
   revoking Jump's return-signing key.
3. Deploy the verifier side first so stale JWKS cannot keep the key alive.
4. Generate and install a replacement private key and `kid`.
5. Set `ACTIVE_KID` to the replacement `kid`.
6. Remove the compromised public JWK from `PUBLIC_KEYSET`.
7. Purge CDN caches for the issuer JWKS URL.
8. Confirm tokens signed with the compromised `kid` are rejected.
9. Review logs by `kid`, issuer, destination host, and `jti`. Do not log full JWTs or key material.

## CDN Guidance

JWKS may be cached publicly, but emergency revoke must not depend on CDN expiry.

- Keep `Cache-Control` short enough for normal rotation; current endpoint TTL is one hour.
- CDN stale behavior must be less than the maximum acceptable revocation delay.
- On emergency revoke, purge the exact JWKS URL for the issuer.
- Verifiers must keep local revoked-kid configuration so a stale CDN JWKS cannot re-enable a
  compromised key.

## Validation Checklist

Before production deployment:

- `kid` is globally unique and includes token family, surface, environment, date, and sequence.
- The key is P-384 and signs with ES384.
- Active private key derives the active public JWK.
- JWKS contains no private fields: `d`, PEM, DER, `k`, or secret backend names.
- Revoked kids are absent from JWKS.
- Issuer origin is the exact registered issuer for that surface.
- Token `aud` is the Jump gateway origin.
- Token TTL is no more than the verifier maximum.
- Rollback private key versions are still available.
