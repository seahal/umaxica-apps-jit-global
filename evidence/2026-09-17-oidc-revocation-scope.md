# OIDC revocation-scope hardening evidence

- Date: 2026-09-17 UTC
- Branch: `feature`
- Parent commit: `78e26f336`
- Working tree: pre-existing `README.md` modification and `misc.md`/`refactor.md` deletions were
  preserved and were not staged.

## Implemented check

`OidcTokenRevoker` now resolves an access-token `sid` only in the registered client's surface-local
RP Session table. It still requires the RP Session's client ID and JTI to match. The previous
fallback to a surface parent `ClientToken`, `VisitorToken`, or `OperatorToken` was removed, so an RP
revocation cannot terminate a parent Browser Session or sibling RP sessions.

## Verification

- `ruby -c app/operations/oidc_token_revoker.rb`: passed.
- `ruby -c test/services/oidc_token_revoker_surface_lookup_test.rb`: passed.
- `ruby -c test/services/oidc_token_revocation_service_coverage_test.rb`: passed.
- `ruby -c test/services/branch_coverage_batch24_mass_easy_arms_test.rb`: passed.
- `bundle exec rubocop --force-exclusion app/operations/oidc_token_revoker.rb test/services/oidc_token_revoker_surface_lookup_test.rb test/services/oidc_token_revocation_service_coverage_test.rb test/services/branch_coverage_batch24_mass_easy_arms_test.rb`:
  passed; no offenses.
- `git diff --check`: passed.
- The affected Rails tests were attempted with isolated test Valkey variables, but Rails boot
  stopped before assertions because PostgreSQL host `primary` could not be resolved.

## Not verified

Real PostgreSQL lookup isolation, revocation transaction behavior, and the HTTP RFC 7009 response
matrix remain unverified until the isolated test database is available. No production or shared
datastore was used.
