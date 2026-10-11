# RP Session Revoke Lock-Order Verification

- Date: 2026-09-17
- Branch: `feature`
- Previous committed slice: `73b7beea4`
- Scope: align OIDC RP-session revoke and back-channel logout with the parent-first lock order used
  by authorization-code exchange, refresh rotation, and browser-session revoke.

## Change verified statically

`RpSessionRevoker` now uses the surface-local writing connection for RP-session and browser-session
revocation. A child-only revoke locks the Base Browser Session first and the targeted RP Session
second. `OidcTokenRevoker` and the RP-session branch of `OidcRpSessionLogout` delegate to this
operation, so OIDC revocation does not bypass the shared ordering or accidentally revoke the parent.
The legacy UUID parent-SID branch remains on the existing parent logout primitive. Back-channel
logout no longer excludes a matching RP Session merely because its refresh window has expired.

## Commands and results

- Ruby syntax checks for all six changed Ruby files — passed.
- `bundle exec rubocop app/operations/rp_session_revoker.rb app/operations/oidc_token_revoker.rb app/services/oidc_rp_session_logout.rb test/operations/rp_session_revoker_test.rb test/services/oidc_token_revocation_service_coverage_test.rb test/services/oidc_rp_session_logout_test.rb`
  — passed; 6 files inspected, no offenses.
- `pg_isready -h 127.0.0.1 -p 5432` — no response.
- The focused Rails test command for the revoker, OIDC logout, and surface lookup tests was
  attempted with isolated Valkey environment variables but was blocked before assertions because
  PostgreSQL host `primary` could not be resolved.

The parent-before-child SQL ordering, child-only scope, and successful logout status remain
database-unverified until the repository's isolated PostgreSQL test service is available. No shared
or non-test database was used.

## Follow-up verification

- Date: 2026-09-17 UTC
- `bundle exec bin/rails test test/operations/oidc_connection_revoker_test.rb test/operations/rp_session_revoker_test.rb test/models/rp_session_test.rb test/services/oidc_refresh_token_issuer_result_test.rb test/services/oidc_refresh_token_issuer_surface_test.rb test/services/oidc_token_revoker_surface_lookup_test.rb test/models/surface_writer_connection_test.rb`
  — passed, 42 runs / 210 assertions.
- The lock-order assertions now recognize Rails' application comment after `FOR UPDATE`. This
  corrected the test observation without changing the revocation implementation.
- No migration, reset, production/shared database access, or external notification was performed.

The focused set verifies the public operation's parent-before-child SQL ordering and surface-local
scope. It does not claim a full independent-connection concurrency proof or immediate invalidation
of access JWTs that were already issued.

## Follow-up verification: OIDC revocation coverage double

- Date: 2026-09-18 UTC
- `bundle exec bin/rails test test/services/oidc_token_revocation_service_coverage_test.rb` —
  passed, 8 runs / 26 assertions / 0 failures / 0 errors / 0 skips.
- The coverage test's in-memory token now accepts the production `revoke!(status:, now:)` contract
  and records those arguments. No production revocation code was changed.
- The combined OIDC/RP-session revocation regression set passed, 25 runs / 101 assertions / 0
  failures / 0 errors / 0 skips.
- `bundle exec ruby -c test/services/oidc_token_revocation_service_coverage_test.rb` and
  `bundle exec rubocop test/services/oidc_token_revocation_service_coverage_test.rb` passed.

The full Rails suite was attempted separately but terminated before completion; sign-out notice
tests still encounter the unavailable test Valkey service described by `CF-002`. This follow-up does
not claim full-suite or worker/runtime verification.
