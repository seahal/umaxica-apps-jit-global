# WU-11: RP JWT verification — typed JWKS lookup with a distributed refetch limit

- Date: 2026-10-23. Base commit `6e4d70d0b0799a4ef9bd9fc4cea2c21d4b3eca72`; change uncommitted.
- Decisions: D-23, D-136, D-144 (design `two.md` 6.3), BX-6, BX-7.

## Change

- New `OidcJwksRefetchLimiter` (`app/adapters/`): per issuer (SHA-256 of the JWKS URI, 32 hex) a
  10 s lease taken by one Lua script only when no outcome is recorded, and a 30 s `last` record
  `{outcome, kids}` in the rate-limit Valkey under `<rate-limit namespace>:oidc_jwks_refetch`.
  `Umaxica::Valkey::Unavailable` falls back to a process-local window of the same length.
  Configuration errors are not swallowed.
- `OidcOpJwksClient#lookup` returns `found` / `invalid` / `unavailable` (with a reason) per the 6.3
  table; a known `kid` in a fresh cache never touches Valkey; inside the stale window a known `kid`
  keeps verifying while refresh is refused or failing. `public_key_for` is removed (no compatibility
  wrapper). One cached client per JWKS URI and process (`for_jwks_uri`); the Back-Channel Logout
  receiver uses it instead of building a client per request (BX-6).
- Access, ID and Logout Token verifiers check that the unverified `iss` equals the configured issuer
  before any lookup (D-144 pre-check; `alg`/`kid` format were already checked) and report
  `key_unavailable` separately. The BCL receiver answers 503 for it (BX-7);
  `RpRequestAuthenticator` raises `OidcOpJwksClient::FetchError`, which its callers already map to 503.
- `config.x.rate_limit.namespace` is exposed in development, production and test; the test worker
  hook updates it after fork.
- Two tests that pinned the old "refetch on every unknown kid" behavior were rewritten to the
  D-144 window semantics (stated in their names); a stale-cache, rotation and outage case each keeps
  its intent.

## Verification

- `test/adapters/oidc_jwks_refetch_limiter_test.rb` (new): held key with Valkey down (A11-4), local
  window never unlimited (A11-7), window boundary at 29 / 30 / 31 s on the local window (A11-12),
  failed recent fetch → unavailable (A11-6), four threads with their own limiters against the test
  rate-limit Valkey → one fetch (A11-5), recent fetch seeing the `kid` → one self-fetch, header
  pre-check → no fetch (A11-11). 7 runs, 0 failures.
- Verifier tests: 12 runs, 0 failures. JWKS consumers (temporal validation, request authenticator,
  cell session revoker, refresh committer, refresh/logout concurrency, outbox dispatch, token
  exchange): 156 runs, 0 failures. BCL receiver and related: 168 runs, 0 failures.
- **Not run:** A11-8 (lease holder dies; relies on the Valkey key TTL), a request-level BCL 503 case
  (the test transport serves the JWKS in-process; no non-mocked way to make it fail), Valkey TTL
  boundaries on the real store (covered on the local window only).
