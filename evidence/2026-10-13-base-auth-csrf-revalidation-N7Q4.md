# Base/Auth CSRF token revalidation

Date: 2026-10-13 UTC. Verification ran against full commit
`aa92265b7e63bf874fddd0aa8f278d5ed19de6b5`. The worktree contained extensive unrelated changes;
the CSRF implementation and its acceptance tests were already present and were not edited during
this verification.

The user's decision to follow frozen `one.md` governs over the older same-origin exception in
`adr/operator-capability-authorization.md`. The existing ADR and implementation require a
session-bound Rails authenticity token on every unsafe Base/Auth request, while retaining Rails
`:header_or_legacy_token`, Origin and Fetch Metadata checks, and framework handling of invalid
requests. The focused tests exercise same-origin missing and invalid tokens, same-site missing
tokens, JSON requests, valid tokens, Auth admissions on all three surfaces, Base APP/COM/ORG
preference mutations, ORG administrative mutations, and protocol CSRF boundaries.

Commands and results:

- `env -u POSTGRESQL_ISOLATED_TEST_RUN_ID PARALLEL_WORKERS=1 bin/rails test test/security/invariants/csrf_verification_strategy_invariant_test.rb test/security/invariants/csrf_acceptance_override_invariant_test.rb test/unit/security/standard_csrf_invariant_test.rb test/controllers/auth/admission_csrf_transport_test.rb test/integration/org_admin_csrf_test.rb test/controllers/base/oidc_result_csrf_transport_test.rb test/controllers/security/csrf_route_coverage_test.rb` — 57 runs, 675 assertions, 0 failures, 0 errors, 0 skips.
- `env -u POSTGRESQL_ISOLATED_TEST_RUN_ID PARALLEL_WORKERS=1 bin/rails test test/integration/preference_web_csrf_test.rb` — 13 runs, 38 assertions, 0 failures, 0 errors, 0 skips.

Both runs used only the standard Rails test database configuration. No isolated-run ID was set,
and no reset or migration command was run. These results revalidate the Base/Auth token boundary;
they do not complete Step 9's separate production-like deprecation-log observation, which remains
unverified because `TRUSTED_PROXIES` was unavailable in the earlier documented attempt.
