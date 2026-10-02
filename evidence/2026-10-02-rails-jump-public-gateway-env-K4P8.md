# Rails Jump PUBLIC_JUMP_GATEWAY_URL and environment-neutral issuer identity

- Commit: `b7c56bbf0f87c9a71440abc363a7bb4682f90839`, with uncommitted changes. This includes the
  earlier strict-contract change (`evidence/2026-10-02-rails-jump-gateway-ssot-reuse-only-Q7M3.md`)
  and this follow-up, and they affect every result below.
- Contract: `adr/jump-directed-rails-handoff-contract.md` (third 2026-10-02 amendment).

## Change verified

- `PUBLIC_JUMP_GATEWAY_URL` is the sole gateway setting. The gateway origin, `aud` and JWKS URI
  (`<origin>/.well-known/jwks.json`) are derived from it. `JUMP_GATEWAY_URL`, `*_JWKS_URL` and
  `*_AUDIENCE` raise at boot, even when blank. `PRIVATE_JUMP_GATEWAY_URL` is not read.
- The development canonical-origin rejection (`JumpRtSurface::PRODUCTION_ISSUER_ORIGINS` check on
  `Rails.env.development?`) was removed. Issuer origin validation itself is unchanged and
  environment-independent.
- `JitSecurityJwtRegistry` builds the 13 Jump issuer records with `JumpRtSurface.issuer_origin`, so
  an unsafe or missing `PUBLIC_*` issuer origin fails at boot. Boot makes no network calls.

## Environment used

The untracked local `.env` and `.env.local` still set `JUMP_GATEWAY_URL`. The container also
exports `PUBLIC_JUMP_GATEWAY_URL=jump.umaxica.net` without a scheme. Both now fail boot, which is
intended. Tests ran with `UMAXICA_ENV_FILE=.env.example` and
`PUBLIC_JUMP_GATEWAY_URL=https://jump.umaxica.net`. The `PUBLIC_*` surface values were the
canonical production origins.

## Results

- Red phase: the new registry boot tests failed before implementation (2 failures, "nothing was
  raised"). The old development rejection test failed after removal and was inverted.
- `RAILS_ENV=development bin/rails runner`: boot succeeded, and
  `JitSecurityJwtRegistry.surface("BASE_APP").issuer` was `"https://www.umaxica.app"`.
- Focused Jump, JWT registry/installer, config, OIDC browser flow, Palm, Edit, Warp, receiver,
  security-header, redirect and JTI tests: 444 runs, 2238 assertions, 0 failures, 1 error.
- Full `bin/rails test`: 12395 runs, 84727 assertions, 0 failures, 1 error, 2 skips.
  - The error is `OidcRpBrowserFlowTest` (`test/integration/oidc_rp_browser_flow_test.rb:121`),
    `undefined method 'merge!' for Rack::Test::CookieJar`.
  - The earlier evidence recorded this same error as reproducing on the unmodified commit.
  - A baseline re-run in a clean HEAD worktree during this session hung for more than 10 minutes
    and was stopped, so this session did not re-confirm the baseline.
- `bin/rubocop` on the changed Ruby files: 3 offenses, each identical in the HEAD version of its
  file (`Layout/LineLength`, two `Minitest/MultipleAssertions`). None are on changed lines.
- `git diff --check`: clean. No private key material was added to the diff or this record.
- Graph and `rpl`: the code was not changed. `jump_rt_issuer_jwks_authority_test` (13 issuers,
  sign → JWKS verify) and the return-policy/verifier tests (20 edges, 169 pairs, `rpl` exactly
  `"reuse"`) passed in the focused run.

Not verified: a live round trip through the production Hono gateway (Hono is not yet updated), and
public JWKS reachability.
