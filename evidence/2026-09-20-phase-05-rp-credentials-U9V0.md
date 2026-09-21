# Phase 05 RP credential boundary evidence

Date: 2026-09-20
Repository HEAD at start of this slice: `52efa31df2a28763ad405f604bb3ef0c416b3b93`
Working tree: pre-existing staged, unstaged, and untracked changes were preserved; no commit was
created and no GitHub or external service was modified.

## Scope

This slice completed the Rails-side RP credential handoff and Core browser-cookie consumption for
the seven-RP callback concern, with direct HTTP coverage for Core app/com/org. It did not validate a
live Cloudflare/TanStack path.

The callback stores Base-issued Access and Refresh credentials in the dedicated host-only
`oidc_rp_access` / `oidc_rp_refresh` cookie slots and does not call generic root `log_in` for the
Core, Side, or Edit RP callback controllers. Core validates the Access JWT locally against the
registered RP issuer, audience, resource type, and `client_id`, then resolves the resource from
the verified OIDC public subject. Core does not use the old root Browser Session cookie as an RP
credential and does not perform a per-request RP Session lookup.

Rails CSRF protection, cookie-only transport, `Authorization: Bearer` rejection, `no-store`, and
the existing Core feature flag remain in force.

## Verification

All commands were run with the configured test environment:

```text
export UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example
PARALLEL_WORKERS=1 bin/rails test test/controllers/concerns/oidc/callback_test.rb \
  test/controllers/core/com/api/v0/sessions_controller_test.rb \
  test/integration/core_browser_api_boundary_test.rb \
  test/contracts/openapi_core_session_contract_test.rb \
  test/integration/core_rp_browser_flow_test.rb \
  test/services/oidc/token_exchange_service_test.rb \
  test/services/valkey/auth_state/authorization_code_store_test.rb \
  test/services/oidc_access_token_authenticator_test.rb \
  test/services/oidc_issuer_test.rb
```

Result: `162 runs, 782 assertions, 0 failures, 0 errors, 0 skips`.

```text
PARALLEL_WORKERS=1 bin/rails test test/integration/core_rp_cookie_surface_contract_test.rb
```

Result: `1 run, 12 assertions, 0 failures, 0 errors, 0 skips`.

```text
bin/rubocop app/controllers/concerns/core_browser_api_boundary.rb \
  app/controllers/concerns/oidc_callback.rb \
  app/controllers/concerns/oidc_rp_cookie_name.rb \
  app/services/oidc_rp_browser_credential_contract.rb \
  test/controllers/core/com/api/v0/sessions_controller_test.rb \
  test/integration/core_browser_api_boundary_test.rb \
  test/contracts/openapi_core_session_contract_test.rb \
  test/controllers/concerns/oidc/callback_test.rb
```

Result: `8 files inspected, no offenses detected`.

```text
PARALLEL_WORKERS=1 bin/rails test
```

Result: `11372 runs, 72631 assertions, 0 failures, 0 errors, 5 skips` in `359.429415s`.
The five skips are existing skipped tests; no test was added, removed, or weakened for this
slice.

```text
git diff --check
```

Result: passed with no whitespace errors.

The final changed-file RuboCop check covered 12 Ruby files and reported no offenses.

## Adversarial checks performed

- A valid RP Access JWT authenticates Core without a root `VisitorToken`.
- A sibling RP `client_id` claim is rejected even when the audience is otherwise valid.
- A legacy root Browser Session cookie is not accepted by the Core RP boundary.
- A Palm audience is rejected from the Core RP cookie transport.
- The same exact-client contract succeeds independently on Core app, com, and org.
- A blank resource public identifier does not fall back to a database primary key.
- Refresh rotates the RP credential and returns `204` with no credential body.
- CSRF failure and Bearer transport refusal remain covered.
- Callback storage is covered without a root `log_in` call.

## Unverified

- Live Cloudflare Tunnel, external Access configuration, and future TanStack SSR cookie forwarding
  were not exercised.
- Regional JP/US RP registration deployment and external key rollout remain separate work.
