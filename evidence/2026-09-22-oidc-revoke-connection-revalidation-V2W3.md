# OIDC revoke and connection reactivation revalidation

## Scope

- Repository HEAD: `ab4746f9d403021b3ea5fff53a0a6ae4b4e68ec9`
- Worktree: already contained unrelated user changes; no existing changes were reset, staged, committed, or pushed.
- Date: 2026-09-22

## Repository findings

- `OidcConnectionRecorder` locks the surface-local connection and rejects an authorization code
  issued at or before the persisted revocation time before clearing the marker. It therefore does
  not let a stale code re-establish a revoked connection.
- `OidcTokenRevoker` authenticates the registered client, resolves the RP session in the expected
  surface-local database, requires the session client ID to match, and requires an access-token JTI
  match. It does not fall back to a Base Browser Session or revoke sibling RP sessions.
- `RpSessionRevoker` uses the explicit `:rp_session` scope for RP revocation and locks the parent
  before the child. Parent and identity-wide scopes remain separate operations.

## Verification

Command:

```text
env RAILS_ENV=test UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db PARALLEL_WORKERS=1 bin/rails test test/operations/oidc_connection_recorder_test.rb test/operations/oidc_connection_revoker_test.rb test/operations/rp_session_revoker_test.rb test/controllers/base/sign_out_and_oauth_revocation_test.rb
```

Result: `23 runs, 72 assertions, 0 failures, 0 errors, 0 skips`.

The current full Rails suite also passed separately with `11,500 runs, 73,296 assertions, 0
failures, 0 errors, 5 skips`. No external RP registration, key, provider, or deployment state was
changed or claimed as verified.

## Disposition

The local revoke and stale-connection behavior is revalidated. External RP registration/region
identity and the remaining Auth/Base authority handoff are separate boundaries and remain open.

