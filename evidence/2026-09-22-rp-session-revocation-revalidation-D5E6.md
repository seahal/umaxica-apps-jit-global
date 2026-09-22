# RP Session and refresh revalidation

- Date: 2026-09-22
- HEAD: `277673d13547d722fc88f830711eee69b923a7e8`
- Worktree: already contained unrelated and in-scope uncommitted changes; no existing changes were discarded.
- Scope: repository-side revalidation of RP Session scope isolation, parent-first revocation, stateless Access JWT behavior, refresh rotation/reuse, realm lookup, and concurrent refresh handling.

## Verification

Command:

```text
export UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example
export POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db
PARALLEL_WORKERS=1 bin/rails test test/models/rp_session_test.rb test/models/refresh_token_concurrency_test.rb test/operations/rp_session_revoker_test.rb test/services/oidc_rp_session_logout_test.rb test/services/oidc_access_jwt_child_revoke_independence_test.rb test/services/oidc_token_revocation_service_coverage_test.rb test/services/oidc_token_revoker_surface_lookup_test.rb test/services/oidc_refresh_token_issuer_surface_test.rb test/services/oidc_token_exchange_boundary_test.rb test/security/invariants/refresh_token_reuse_invariant_test.rb test/controllers/base/edge_v0_token_refresh_binding_test.rb
```

Result: `81 runs, 367 assertions, 0 failures, 0 errors, 0 skips`.

The collection covered targeted RP-session revoke scope, parent-before-child locking, Access JWT
natural-expiry and stateless verification behavior, refresh rotation/reuse, surface/realm lookup,
and concurrent refresh attempts. The test process reached the Compose-backed PostgreSQL service;
no external provider, AWS, Cloudflare, or live RP registration was contacted.

## Disposition

This closes the repository-side execution evidence gap for the tested RP-session/revocation slice.
It does not close regional external RP registration, production deployment topology, authority-owner
cutover/backfill, or immediate invalidation of already-issued Access JWTs.
