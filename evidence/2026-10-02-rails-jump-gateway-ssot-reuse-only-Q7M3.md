# Rails Jump gateway SSOT and reuse-only RT contract

- Commit: `b7c56bbf0f87c9a71440abc363a7bb4682f90839` (local and `origin/feature` at start), with
  uncommitted changes that implement this contract and affect every result below.
- Contract: `adr/jump-directed-rails-handoff-contract.md` (amended 2026-10-02).

## Environment used

The untracked local `.env` still sets the removed `PUBLIC_JUMP_GATEWAY_URL`, so boot now fails with
it (the intended configuration error). Tests ran with `UMAXICA_ENV_FILE` pointing to a scratch copy
of `.env` without the removed Jump keys and with `JUMP_GATEWAY_URL=https://jump.umaxica.net`; all
`PUBLIC_*` surface values were unchanged (production canonical origins).

## Results

- Red phase: the new and changed Jump tests run against the previous `app/` and `lib/` produced
  171 runs, 35 failures, 13 errors.
- Focused Jump, JWT installer, gateway URL, resolver, receiver and CSP tests: 292 runs, 0 failures,
  0 errors.
- Full `bin/rails test`: 12381 runs, 84677 assertions, 0 failures, 1 error, 2 skips. The error,
  `OidcRpBrowserFlowTest` session-limit Core RP callback (`undefined method 'merge!' for
  Rack::Test::CookieJar`), reproduces identically on the unmodified commit.
- `bin/rubocop` on the 35 changed Ruby files: no offenses. Whole-repository `bin/rubocop` reports
  63 offenses, none in changed files. `bun run format:check` reports 3 unchanged TypeScript files.
- `git diff --check`: clean. No private key material in the diff.
- Graph: `JumpRtReturnPolicy::ALLOWED_EDGES` equals the literal twenty-edge expectation and all
  169 ordered canonical pairs match it.

Not verified: a live round trip through the production Hono gateway (Hono does not yet follow the
strict contract) and a development boot with non-production `PUBLIC_*` origins (none are defined).
