# Jump RT JWT Key Rotation

## Purpose

This runbook manages ES384 signing keys for Jump redirect tokens.

Jump RT keys are issuer-surface scoped. Do not reuse one private key or `kid` across issuer
namespaces, neither across `app`, `com` and `org` nor across the `auth`, `base`, `core`, `warp` and
`palm` issuer groups.

Jump issuers are exactly these thirteen namespaces:

- `AUTH_APP`, `AUTH_COM`, `AUTH_ORG`
- `BASE_APP`, `BASE_COM`, `BASE_ORG`
- `CORE_APP`, `CORE_COM`, `CORE_ORG`
- `WARP_APP`, `WARP_COM`, `WARP_ORG`
- `PALM_APP`

The list is `JumpRtSurface::ISSUER_NAMESPACES` (`app/values/jump_rt_surface.rb`). `ACME_APP`,
`ACME_COM` and `ACME_ORG` remain in the general `JitSecurityJwtRegistry::SURFACE_NAMESPACES`
registry for other token families, but they are not Jump signing authorities and are not rotated by
this runbook.

Issuer registration and permitted destinations are separate contracts. See
[the directed handoff ADR](../../adr/jump-directed-rails-handoff-contract.md). Issuer identity is
the namespace's existing `PUBLIC_*` surface origin; `Rails.env` never selects it (see Development
issuance). Gateway trust registration in Hono is a separate step.

A Jump namespace with no key at all boots as unconfigured, and the first Jump rt it is asked to
issue raises `JumpRtConfigurationError` ("signing key configuration is incomplete"); a partial,
malformed, or mismatched key configuration fails boot (see Runtime Contract).

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
return-policy checks and JWKS fetch/cache behavior stay in JumpRT services. Jump RTs are reusable
(`rpl` is always `"reuse"`); Rails keeps no Jump replay state.

Inbound Jump-gateway return tokens are verified only with the Jump public JWKS derived as
`{PUBLIC_JUMP_GATEWAY_URL}/.well-known/jwks.json`; neither that URI nor the `aud` is configurable.
The lifetime cap is 30 seconds. Clock leeway is 5 seconds. A JWKS fetch failure fails closed; Rails
does not keep a stale JWKS fallback and does not store the Jump gateway private key.

## Key States

- `active`: the current private signer; its public JWK is derived from the private key and included
  in JWKS automatically.
- `grace`: verification only; listed in `PUBLIC_KEYSET` and included in JWKS. A pre-published next
  key and a just-replaced previous key are both `grace`.
- `retired`: removed from `PUBLIC_KEYSET` and JWKS after the verification window.
- `revoked`: listed in `REVOKED_KIDS`; excluded from the JWKS this Rails instance publishes and
  rejected by verifiers in this Rails instance. It does not by itself reach an external verifier
  that already cached an earlier JWKS (see Emergency Revocation).

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

Rotation is two deployments plus a cleanup. `K1` is the current active key and `K2` the new key. The
active public JWK is derived only from the active private key, so any key that is not the current
signer is published only if it is listed in `PUBLIC_KEYSET`.

### Phase A: pre-publish K2

1. Generate a new P-384 private key `K2`.
2. Choose a globally unique `kid`, for example `auth-app-jump-rt-es384-prod-2026-06-a`.
3. Store `K2` as a new, inactive version of the `JWT_<NAMESPACE>_PRIVATE_KEY` secret. Do not switch
   the runtime reference to it yet: a private key that changes while `ACTIVE_KID` still names `K1`
   fails boot as an active/public mismatch.
4. Set `JWT_<NAMESPACE>_PUBLIC_KEYSET` to contain both the `K1` public JWK and the `K2` public JWK.
   `K1` must be listed now because it stops being derived at cutover.
5. Deploy and confirm boot validation passes. JWKS publishes `K1` and `K2`; tokens are still signed
   with `K1`.
6. Wait until verifiers can have fetched the new JWKS (at least the JWKS cache lifetime plus CDN
   stale allowance) before Phase B.

### Phase B: signer cutover

1. In one deployment, change `JWT_<NAMESPACE>_ACTIVE_KID` to the `K2` kid and switch the
   `JWT_<NAMESPACE>_PRIVATE_KEY` runtime reference to the `K2` version. Never deploy one without the
   other.
2. Keep both public JWKs in `PUBLIC_KEYSET`.
3. Deploy issuer instances and confirm boot validation passes.
4. Issue a smoke token and confirm its header has `alg: ES384` and the `K2` kid.
5. Confirm Jump accepts the new token.

### Grace removal

1. Keep the `K1` public JWK published for the old-kid verification window after the cutover.
2. Remove the `K1` public JWK from `PUBLIC_KEYSET` and deploy.
3. Keep the `K1` private secret version until rollback is closed.

The old-kid verification window is
`SecurityTokenLifetimes.old_kid_verification_window(SecurityTokenLifetimes::JUMP_RT_TTL)`
(`app/values/security_token_lifetimes.rb`), which is the source of truth; with current values it is
30 seconds + 1 hour + 1 hour = 2 hours 30 seconds. Old verification keys should be public JWKs only
after rollback no longer needs the previous private signer.

## Rollback

Rollback is safe only if the previous private key is still available.

1. In one deployment, restore `JWT_<NAMESPACE>_ACTIVE_KID` to the previous `kid` and switch the
   `JWT_<NAMESPACE>_PRIVATE_KEY` runtime reference back to the previous secret version.
2. Keep both previous and attempted-new public JWKs in `PUBLIC_KEYSET`; the attempted-new key is no
   longer derived once it stops being the signer.
3. Deploy issuer instances.
4. Confirm boot validation passes and new tokens use the previous `kid`.
5. Do not remove the attempted-new public JWK until tokens already issued with it have expired.

## Emergency Revocation

Two different keys can be compromised, and they are revoked in different places.

### Rails issuer key (`JWT_<NAMESPACE>_*`)

A Rails surface private key signs Jump RTs; Hono is the external verifier.

1. Generate and install a replacement private key and `kid` (Phase A step 1-3).
2. In one deployment: add the compromised `kid` to `JWT_<NAMESPACE>_REVOKED_KIDS`, set `ACTIVE_KID`
   and the `PRIVATE_KEY` runtime reference to the replacement, and remove the compromised public JWK
   from `PUBLIC_KEYSET`. Boot fails if the active kid is revoked, so the replacement cannot be
   deferred.
3. Purge CDN caches for the exact issuer JWKS URL.
4. Refresh or invalidate the issuer JWKS cache in Hono, and apply any emergency deny mechanism Hono
   defines.
5. Confirm the Rails JWKS no longer lists the compromised `kid` and that Jump rejects tokens signed
   with it.

Rails-side revocation alone does not guarantee immediate rejection by an external verifier holding a
previously cached issuer JWKS. Hono does not read Rails `REVOKED_KIDS`. The Hono operational
contract MUST define cache invalidation or an equivalent emergency rejection mechanism; until it
does, a cached copy can keep the compromised key usable until that cache expires.

### Jump gateway return-signing key (`JUMP_RETURN_REVOKED_KIDS`)

Hono signs return tokens; Rails is the verifier. `JUMP_RETURN_REVOKED_KIDS` is a receiver-side
blocklist that lets Rails reject a Hono return-signing key locally.

1. Add the compromised Jump return-signing `kid` to `JUMP_RETURN_REVOKED_KIDS` on every Rails
   receiver and deploy. Rails rejects it even if it still holds or fetches a stale gateway JWKS.
2. Hono replaces its signing key and removes the compromised key from its JWKS.
3. Confirm Rails rejects return tokens signed with the compromised `kid`.

### Both cases

Review logs by `kid`, issuer, destination host, and `jti`. Do not log full JWTs or key material.

## CDN Guidance

JWKS may be cached publicly, but emergency revoke must not depend on CDN expiry.

- Keep `Cache-Control` short enough for normal rotation; current endpoint TTL is one hour.
- CDN stale behavior must be less than the maximum acceptable revocation delay.
- On emergency revoke, purge the exact JWKS URL for the issuer.
- A verifier is protected from a stale JWKS only by revoked-kid configuration it holds itself: Rails
  holds `JUMP_RETURN_REVOKED_KIDS` for Hono keys; Hono's equivalent for Rails issuer keys is defined
  by the Hono operational contract.

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

## Development issuance

`PUBLIC_JUMP_GATEWAY_URL` is the only gateway setting; keep it at `https://jump.umaxica.net` while
no emulator exists. `JUMP_GATEWAY_URL` was removed and fails boot if still set.
`PRIVATE_JUMP_GATEWAY_URL` is not supported: Rails has no private network path to Jump, so setting
it, even empty, fails boot. There are no Jump-specific development settings. Development signs with
the installer-owned keys in `tmp/local_jwt_keysets.json` (kid `development-<namespace>-es384-a`); a
`JWT_<NAMESPACE>_*` environment value that does not match that store fails boot, so no other key
material can be injected locally.

Issuer identity comes from the existing surface setting for the namespace (`PUBLIC_AUTH_*_URL`,
`PUBLIC_BASE_*_URL`, `PUBLIC_CORE_*_URL`, `PUBLIC_WARP_*_URL`, `PUBLIC_PALM_SERVICE_URL`). For live
Jump each such setting must be a public HTTPS root origin; localhost, private ingress and IP
literals fail registry configuration at boot and raise `JumpRtConfigurationError` at issuance and on
return verification. `Rails.env` does not change the identity, so development may use a canonical
origin such as `https://www.umaxica.app`. In that case the JWKS at that origin must publish the
development kid, and the development private key then signs as the canonical issuer with full
authority; the `development` marker in the kid does not limit it. Otherwise expose a distinct
origin's Rails JWKS route and browser return through public HTTPS ingress, and register the exact
issuer, JWKS and kid in Hono separately. Verify DNS, TLS, JWKS accessibility from Jump and the
published kid before use. An Access login page in front of JWKS does not constitute a fetchable
keyset. No deployment, trust registration, secret provisioning or key rotation is performed by this
Rails change.

Edit remains an OIDC assertion client, not a Jump issuer; its OIDC keys and registration are
independent from this surface key runbook.
