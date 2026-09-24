# OIDC endpoint and realm revalidation

## Scope

- Repository HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Branch: `feature`
- Worktree: pre-existing staged, unstaged, and untracked changes were preserved; no reset,
  cleanup, commit, push, or external write was performed.
- Date: 2026-09-22

This slice rechecked the repository-owned endpoint/realm boundary for authorization-code exchange,
refresh, revocation, and first-party browser authorization. It did not register or retire any
external client, key, issuer, or deployment configuration.

## Findings

- `OidcTokenExchangeCoordinator` requires a controller-supplied `expected_resource_type` before
  client authentication and rejects a code whose stored resource type differs before Valkey
  consumption or token issuance.
- Authorization-code payload validation also requires the exact client ID, redirect URI, PKCE,
  registered redirect URI for the stored realm, and transaction/session binding before the
  destructive consume path.
- Refresh resolution and rotation receive the expected resource type, then require the usage,
  registered client, root resource, and RP-session client binding to remain in that same realm
  before rotation.
- `OidcTokenRevoker` scopes lookup to the authenticated registered client and expected resource
  type. It resolves the RP Session in the surface-local database and does not fall back to the
  parent Browser Session or a sibling RP Session.
- The three Base browser authorization controllers map `app` to `client`, `com` to `visitor`, and
  `org` to `operator` through their fixed controller boundary. First-party browser RPs remain
  neutral even when `screen_hint=signup` or `screen_hint=signin` is supplied.
- The remaining `sign_in`/`sign_up` branch is limited to the retained `core-next-rp` bridge
  compatibility registration. Its bridge migration and external callers are not proven by this
  repository-only check, so removing it would be an unapproved external-contract change.

## Verification

Focused command:

```text
export UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example
export POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db,test_app_zenith_db
PARALLEL_WORKERS=1 bin/rails test test/services/oidc/realm_binding_test.rb test/services/oidc/token_exchange_service_test.rb test/services/oidc_token_revocation_service_coverage_test.rb test/controllers/base/oauth_oidc_authority_test.rb test/integration/oidc_rp_browser_flow_test.rb
```

Result: `160 runs, 828 assertions, 0 failures, 0 errors, 0 skips`.

Full command:

```text
bin/rails test
```

Result: `11536 runs, 73429 assertions, 0 failures, 0 errors, 8 skips`.

Additional checks:

- Ruby syntax checks passed for the three Base authorization controllers, the token exchange
  coordinator, and the token revoker.
- Targeted RuboCop passed for the affected implementation and test files (`10 files inspected, no
  offenses detected`).
- `git diff --check` passed.
- The observed OmniAuth DEBUG/ERROR lines were emitted by existing provider-failure and CSRF/state
  rejection cases; they did not produce test failures.

## Disposition

The repository-owned endpoint/realm contract is revalidated and does not require a local code
change in this slice. `core-next-rp` remains a bounded compatibility gate under `CF-007` until its
external bridge callers, registrations, keys, and migration state are explicitly verified. No
external service was contacted.
