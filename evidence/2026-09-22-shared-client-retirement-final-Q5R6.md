# Shared browser RP retirement: final local verification

Date: 2026-09-22

Repository: `seahal/umaxica-apps-jit-global`

HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`

Worktree: dirty before and after this verification. Existing user changes were preserved. No
commit, push, pull request, GitHub write, AWS write, Cloudflare write, external RP registration
change, or provider call was performed.

## Change verified

The local static OIDC registry no longer returns the obsolete shared browser registrations
`sign-rp`, `base-rails-rp`, or `side-rails-rp`. Surface-specific tests use the current Core, Side,
and Edit RP registrations. `core-next-rp` remains intentionally registered because
`CoreRpBridge` still references it at runtime; its external registration/key retirement and any
bridge data migration remain separate gates.

The registry cache signature now includes the Core host settings used by the retained
`core-next-rp` registration. This prevents a cached registration from surviving a change to those
settings.

The authority map still lists the retired IDs as historical inventory. That list is not a runtime
registry and is covered by its inventory tests.

## TDD and verification

The first retirement attempt produced RED failures because legacy OIDC tests and flow helpers still
encoded the shared clients. The implementation was then completed by mapping each affected public
contract to its surface-specific RP, rather than adding compatibility registrations.

Focused retirement and adjacent OIDC tests:

```text
PARALLEL_WORKERS=1 bin/rails test \
  test/controllers/base/oauth_oidc_authority_test.rb \
  test/controllers/concerns/oidc/sso_initiator_test.rb \
  test/services/oidc/logout_request_test.rb \
  test/services/oidc/logout_token_codec_test.rb \
  test/services/acme_logout_transaction_coordinator_test.rb \
  test/services/acme_logout_transaction_service_test.rb \
  test/values/oidc_client_flipper_actor_test.rb \
  test/security/invariants/refresh_token_reuse_invariant_test.rb \
  test/services/oidc/acme_service_origin_test.rb \
  test/services/oidc/id_token_verifier_test.rb \
  test/integration/base_rp_browser_flow_test.rb \
  test/integration/sign_app_oidc_browser_flow_test.rb \
  test/controllers/auth/app/sign_outs_controller_test.rb \
  test/controllers/auth/com/sign_outs_controller_test.rb \
  test/controllers/auth/org/sign_outs_controller_test.rb
```

Result: `137 runs, 726 assertions, 0 failures, 0 errors, 0 skips`.

Additional checks:

- `bundle exec rubocop $(git diff --name-only --diff-filter=ACM -- '*.rb')`: 37 files, no offenses.
- `bin/rails zeitwerk:check`: passed; Rails reported the existing optional `rails_db` eager-load
  notice only.
- `bin/brakeman --no-pager`: 0 errors, 0 security warnings.
- `git diff --check`: passed.
- `bin/rails test`: `11530 runs, 73392 assertions, 0 failures, 0 errors, 8 skips`.

The full suite used the repository test environment with the explicit devcontainer environment
file and the four prepared PostgreSQL test databases. PostgreSQL and Valkey were reachable. The
eight skips were pre-existing; no skip was added by this slice.

## Remaining gates

This evidence proves the local repository slice only. It does not prove that external deployments,
external RP registrations or keys, callers outside this repository, or the `core-next-rp` bridge
data migration have been retired. Those remain explicit follow-up gates. The retention dry-run
clarification is independent and does not require a preview API. Notification delivery/receipt/
retry/permanent-failure work is also independent and remains open.
