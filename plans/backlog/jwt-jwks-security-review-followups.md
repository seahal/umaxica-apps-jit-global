# JWT / JWKS Security Review Follow-ups

Status: backlog

Other AI agents are currently working in this area. Do not implement these fixes opportunistically
while that work is in flight. Revisit this plan after the concurrent work settles.

## Context

A static security review of the JWT / JWKS / key-rotation changes found that the implementation is
improved but not ready for production. No tests or Rails runtime commands were executed during this
review.

## Deployment Blockers

- Fix Jump RT issuance before deployment. `JumpRt::Surface.normalize_namespace` currently references
  an undefined `HOST_ENV`, and `Common::Redirect#redirect_to_jump_url` only rescues `ArgumentError`,
  so this can become a 500 instead of a controlled fallback.
- Make Auth and OIDC issuer/audience/leeway verification use the boot-time JWT registry, not
  per-request `ENV` reads through `Authentication::JwtConfiguration`.
- Ensure Auth and Preference key registries load only the current private key. Legacy keys must be
  public verification keys only.
- Fail boot when a configured JWKS endpoint surface has no active kid or no active key. Empty JWKS
  for an exposed issuer should not be a valid production state.
- Remove JWT/OpenSSL/config exception messages from auth/preference/anomaly logs. Log stable reason
  codes and classes only.
- Stop silently returning `nil` for authentication token issuance failures. Use fail-hard behavior
  or an explicit typed result.

## Security Hardening Follow-ups

- Move Jump return JWKS refresh away from synchronous request-path network fetches. Keep HTTPS,
  timeout, size-limit, stale-cache, negative-cache, and revoked-kid behavior, but add background
  refresh or a circuit-breaker style boundary.
- Change Jump RT `typ` from generic `JWT` to a token-family specific value such as `jump-rt+jwt`,
  then verify that value before signature verification.
- Reject duplicate `kid` entries inside a single configured public JWK Set during boot validation.
- Replace permissive `Base64.decode64` private-key decoding with `Base64.strict_decode64`.
- Remove or isolate legacy `parse_keyset` / `decode_key` helpers that silently return `{}` or `nil`,
  so runtime code cannot regress to fail-open parsing.
- Move JWKS controller/session-skip behavior out of `Authentication::JwksRendering` into an explicit
  public JWKS controller base class or fully explicit controllers.

## Test Expectations

- Add regression coverage for Jump RT issuance with every supported namespace.
- Add registry tests for missing active kid, missing active private key, empty exposed JWKS,
  duplicate same-set `kid`, revoked active kid, mismatched active public/private key, and strict
  base64 decoding.
- Add Auth/OIDC/Preference cross-token confusion tests for wrong `typ`, wrong issuer, wrong
  audience, unknown kid, revoked kid, and wrong token family.
- Add a JWKS endpoint test proving render does not touch credentials, private keys, files, KMS, or
  network.
- Add logging tests proving JWT decode/config errors do not emit raw exception messages or token
  material.

## Notes

- Keep the deleted redirector/jump-link models deleted. Do not reintroduce `RedirectorRecord`,
  `AppJumpLink`, `ComJumpLink`, `OrgJumpLink`, or `JumpLinkable` while addressing this plan.
- Align updates with `docs/runbooks/jwt-key-rotation.md` and `docs/runbooks/jump-rt-key-rotation.md`
  once implementation behavior is final.
