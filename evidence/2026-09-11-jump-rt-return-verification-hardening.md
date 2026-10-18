# Jump RT return verification hardening

Date: 2026-09-11

## What was checked

Command:

```bash
bin/rails test test/services/jump_rt/return_verifier_test.rb \
  test/lib/config_values/jump_gateway_values_test.rb \
  test/services/security/token_lifetimes_test.rb \
  test/services/jump_rt/issuer_test.rb \
  test/integration/jump_rt_return_verification_test.rb
```

Result: 80 runs, 231 assertions, 0 failures, 0 errors, 0 skips.

## Behavior recorded

- Return and issue TTL cap: 30 seconds.
- Verifier leeway: 5 seconds.
- JWKS live cache: 30 seconds; no stale fallback.
- Unknown kid: force JWKS refetch, then 5-second negative cache.
- Production JWKS URI must match `{origin}/.well-known/jwks.json`.
- Rejection log field is `request_path`; the compact JWT is not included.
