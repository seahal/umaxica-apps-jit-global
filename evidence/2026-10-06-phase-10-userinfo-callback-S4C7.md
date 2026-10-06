# Phase 10: UserInfo, callback and discovery

Date: 2026-10-06

Commit: `bfe569a162078df62e8e3b3011367840780e3078`

The worktree was dirty before and during this phase; unrelated staged, unstaged and untracked work
was preserved. Verification used the owned disposable manifest
`tmp/auth-boundary-isolated-20261003auth6f3.json` with one worker and all 20 declared databases.

Implemented D-61, D-59, D-65 and D-106:

- Base app, com and org UserInfo accept GET and POST with Bearer Authorization only, reject missing,
  malformed, Basic, query and cookie transports with the specified challenges, serialize scoped claims,
  and classify database failures as `503 temporarily_unavailable`.
- OIDC callback validation is ordered through authorization response, exchange, token completeness, ID
  Token, access-token authority, UserInfo subject equality, exact identity binding, and RP session or
  credential establishment. Protocol failures are `text/plain` 422 responses with `no-store` and no
  `Location`; dependency failures are 503. Callback logs carry only the coarse D-106 fields.
- Discovery advertises `userinfo_endpoint` and exactly `authorization_code` plus `refresh_token`.
  The app token endpoint now has the FQDN availability gate; the inherited com/org gates were verified.

Commands and observed results:

- `bin/rails test test/controllers/base/oauth_oidc_authority_test.rb` — 53 runs, 323 assertions,
  0 failures, 0 errors, 0 skips.
- `bin/rails test test/controllers/concerns/oidc/callback_test.rb test/services/oidc/discovery_document_test.rb`
  — 25 runs, 219 assertions, 0 failures, 0 errors, 0 skips.
- `bin/rails test test/integration/routes/base_authority_route_contract_test.rb` — 13 runs,
  278 assertions, 0 failures, 0 errors, 0 skips.
- UserInfo-focused run (`-i /userinfo/`) — 12 runs, 68 assertions, 0 failures, 0 errors, 0 skips.
- `bin/rails test test/integration/fqdn_availability_gate_test.rb
  test/security/invariants/default_no_store_policy_invariant_test.rb` — 23 runs, 3524 assertions,
  0 failures, 0 errors, 0 skips.
- Targeted `bundle exec rubocop` on the 14 changed Ruby files — no offenses.
- `bin/rails zeitwerk:check` — all eager-loaded application files valid.
- `git diff --check` on the phase files — no output.

The Phase 0 baseline could not execute assertions because Bundler/Rails was unavailable at that time;
the baseline therefore does not provide a behavioral comparison. The phase-targeted runs above are
green.
