# RP-authenticated neutral-entry refusal

Date: 2026-09-22

Repository: `/home/global/workspace`

HEAD: `277673d13547d722fc88f830711eee69b923a7e8`

Worktree: already had unrelated uncommitted changes; this verification added the RP entry concern
change and its integration regressions without staging or committing any file.

## Finding

The canonical browser RP entry's `POST /sign` guard checked only the root Browser Session
predicate (`logged_in?`). A browser with a valid same-RP `oidc_rp_access` cookie was not recognized as
already authenticated and reached the OIDC authorization redirect. This violated the server-side
contract that sign-out must occur before another browser RP authentication starts.

The initial RED result was:

`9 runs, 167 assertions, 1 failure, 0 errors, 0 skips`; the new case received HTTP 302 instead of
the required plain HTTP 409 refusal.

## Change

`OidcRpSignEntry#reject_authenticated_rp_start!` now treats a valid access credential for the
controller's fixed OIDC client and resource type as authenticated. It reuses
`OidcRpBrowserCredentialContract.decode_access_token` with the current request host and does not
introduce an RP Session database lookup, refresh-cookie authentication, bearer fallback, or CSRF
change. The root Browser Session check remains in place.

## Adversarial cases

- Same-RP valid access cookie: refused with plain `409 Conflict`, the existing refusal message, and
  no pending OIDC flow.
- Different-surface `core-com` credential presented to `core-app`: not accepted as app
  authentication; the app flow can proceed normally. Client/resource/issuer/audience checks remain
  surface-bound.
- Root authenticated browser: existing plain refusal contract remains green.
- GET `/sign`: existing non-mutating neutral entry contract remains green.
- CSRF-protected POST and state/nonce/PKCE generation: existing tests remain green.

## Verification

Environment: Compose-backed test PostgreSQL and Valkey; no external provider, AWS, Cloudflare, or
GitHub write was performed.

Commands:

```text
export UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example
export RAILS_ENV=test
export POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db,test_queue_db,test_occurrence_db
export PARALLEL_WORKERS=1
bin/rails test test/integration/routes/neutral_rp_entry_contract_test.rb
bin/rails test test/integration/routes/neutral_rp_entry_contract_test.rb test/integration/core_rp_cookie_surface_contract_test.rb test/integration/oidc_rp_browser_flow_test.rb test/controllers/concerns/oidc/callback_test.rb test/services/oidc_access_token_authenticator_test.rb test/integration/core_browser_api_boundary_test.rb
```

Results:

- Neutral RP entry: `10 runs, 173 assertions, 0 failures, 0 errors, 0 skips`.
- Broader RP boundary set: `73 runs, 546 assertions, 0 failures, 0 errors, 0 skips`.
- Full Rails suite after the fix: `11,507 runs, 73,317 assertions, 0 failures, 0 errors, 5 skips`.
  The five skips were retained existing skips; no skip or assertion was added or weakened.
- `ruby -c` passed for the changed Ruby files, targeted RuboCop inspected two files with no
  offenses, `git diff --check` passed, and the frozen-plan validator returned `PASS` with zero
  mapping, closure, placeholder, or verification errors.

Not verified by this slice: the complete Auth-to-Base browser binding and one-shot result handoff,
external JP/US RP registrations and keys, live edge/tunnel behavior, and immediate invalidation of
already-issued Access JWTs. These remain separate plan gates and are not closed by this local
entry-point fix.
