# OIDC grant rollback regression evidence

- Date: 2026-09-22
- Repository: `seahal/umaxica-apps-jit-global`
- HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Worktree: pre-existing uncommitted changes were preserved; this verification ran with a dirty worktree.
- Scope: transaction-bound authorization-code grant rollback when RP token issuance fails.

## Verification

The Rails test environment used the repository's disposable Compose configuration through
`UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example` and the four requested test
database names. No application, environment, or external-service configuration was changed for
the verification.

Focused command:

```text
PARALLEL_WORKERS=1 bin/rails test test/services/oidc/token_exchange_service_test.rb test/services/oidc_authorization_transaction_service_test.rb test/controllers/base/oauth_authorization_surfaces_test.rb
```

Result: 123 runs, 571 assertions, 0 failures, 0 errors, 0 skips.

Full-suite command:

```text
bin/rails test
```

Result: 11,532 runs, 73,415 assertions, 0 failures, 0 errors, 8 skips.

Additional checks:

- `bundle exec ruby -c test/services/oidc/token_exchange_service_test.rb`: passed.
- `bundle exec rubocop test/services/oidc/token_exchange_service_test.rb`: passed; no offenses.
- `git diff --check`: passed.

## Contract verified

When durable grant claim succeeds but token encoding fails, the public exchange result is a
server error without a token response. The RP Session count is unchanged, the durable grant claim
is rolled back, and the authorization-code transport remains issued for a safe retry. The test
reaches this behavior through the public token exchange API and does not call private methods.
