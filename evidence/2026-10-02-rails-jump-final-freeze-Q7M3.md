# Rails Jump final freeze verification

Date: 2026-10-02. Verified commit: `515e6fecbbfe1d60caf139e034c7c3559310f505` (rejects
`PRIVATE_JUMP_GATEWAY_URL` at boot; aligns `docs/operations/jump-rt-key-rotation.md`). This record
supersedes `2026-10-02-rails-jump-contract-freeze-J2F4.md` for the current state; that record is
unchanged.

## Environment

A `git worktree` of the exact commit was used; `git status --short` was empty and `git diff --check`
exited 0. Ignored inputs were copied or linked from the main checkout: `vendor/bundle`,
`node_modules`, `.env`, `.env.local`, `config/credentials/*.key`, `tmp/local_jwt_keysets.json`,
built assets. The operator shell exported `PUBLIC_JUMP_GATEWAY_URL=jump.umaxica.net` (no scheme),
which correctly fails boot; every run overrode it with
`PUBLIC_JUMP_GATEWAY_URL=https://jump.umaxica.net`.

A first full run without the credentials keys and `.env.local` produced 326 configuration errors
(Turnstile, HMAC salt, WebAuthn rp_id) and is discarded.

## Results

- Focused Jump command (J2F4's command plus `test/lib/config_values/jump_gateway_values_test.rb`):
  **359 runs, 1,990 assertions, 0 failures, 1 error, 0 skips**, seed 5139.
- `bin/rails test`: **12,397 runs, 84,725 assertions, 0 failures, 2 errors, 2 skips**, seed 39593,
  140.8 s. Re-running the same seed reproduced the same counts.
- `bin/rails test test/lib/config_values/jump_gateway_values_test.rb`: 47 runs, 0 failures.
- Boot check: `PRIVATE_JUMP_GATEWAY_URL= bin/rails runner 1` raised
  `ArgumentError: PRIVATE_JUMP_GATEWAY_URL is not supported because Rails has no private transport path to Jump`.
- `erb_lint --lint-all`: no errors.
- `rubocop`: inside the worktree it inspects 0 files, because the worktree lives under the excluded
  `tmp/`. Run in the main checkout, whose Ruby files equal this commit (only an unrelated local
  `.env.example` edit differed): 4,942 files, 63 offenses, none in files changed by this commit.
  `.env.example` is not a Ruby file, so the lint result is not affected by it.
- `bun run format:check` fails on three TSX files that are unchanged by this commit and fail
  identically at `7c308e49`.

## Open errors (not introduced by this commit)

1. `OidcRpBrowserFlowTest#test_app_email_sign-in_session-limit_handoff_completes_Core_RP_callback_without_a_root_session`
   (`test/integration/oidc_rp_browser_flow_test.rb:331`):
   `NoMethodError: undefined method 'merge!' for Rack::Test::CookieJar`. It fails identically at
   `7c308e49`, which introduced the call.
2. `OidcRpTokenClientTest#test_allows_an_explicitly_approved_local_HTTP_token_endpoint`
   (`test/services/oidc/rp_token_client_test.rb`): `JWT_AUTH_APP_* must not be set in test` from
   `JitSecurityJwtLocalKeysetInstaller`. It passes alone (7 runs, 0 errors) and fails in the full
   run with seed 39593, so another test leaks `JWT_AUTH_APP_*` environment state.

The Rails side therefore is not fully green at this commit. These two errors must be fixed, and this
verification repeated, before the freeze is declared.

## Development log observation

`log/development.log` in the main checkout showed five `jump_rt.issued` events (BASE_APP x2,
AUTH_COM, BASE_COM, BASE_ORG) that redirected to `https://jump.umaxica.net/?rt=[FILTERED]`. After
the first issuance there was one `jump_return.rejected` (`invalid_claim`, `/sign/in`). For the later
round trips, Jump fetched the issuer JWKS (200) and the return passed `verify_jump_return_rt!`:
Rails returned a 303 to the same URL without `rt`, and the follow-up request rendered normally. No
rejection was logged after the first one.
