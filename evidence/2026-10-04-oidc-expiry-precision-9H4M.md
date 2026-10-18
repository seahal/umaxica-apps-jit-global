# OIDC admission expiry precision

Verified against HEAD `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5` with authentication-related and unrelated uncommitted changes present.

The OIDC authorization model previously truncated both timestamps to seconds. A deadline with fractional seconds was therefore rejected one microsecond before actual expiry. The public boundary test reproduced this on the original code: seed 33681, one test, one assertion, one failure. Both `expired?` and `login_challenge_expired?` now compare timestamps directly, preserving PostgreSQL microsecond precision and rejecting exact equality.

The test covers APP, COM and ORG at one microsecond before, exactly at, and one microsecond after each deadline. Public authentication registration succeeds before expiry while preserving the original authentication event and remains pending with no event at or after expiry. New tests use production public APIs with explicit test setup, not the existing private fixture builder.

All Rails commands used owned manifest `tmp/auth-boundary-isolated-20261003auth6f3.json`, run ID `20261003auth6f3`, migration scope `codex_integrity_20261003auth6f3_app_ticket`, and `PARALLEL_WORKERS=1`.

- Narrow public boundary test: one test, 45 assertions, no failures/errors/skips; seed 27695.
- `bin/rails test test/models/concerns/oidc_authorization_transactionable_test.rb test/controllers/base/oauth_oidc_authority_test.rb test/controllers/base/app/sign/in/limitations_controller_test.rb test/controllers/base/com/oauth/authorizations_controller_test.rb test/controllers/base/org/oauth/authorizations_controller_test.rb test/services/credential_security_transition_test.rb test/services/base_auth_admission_coordinator_test.rb`: 128 tests, 959 assertions, no failures/errors/skips; seed 11652.
- RuboCop on the modified model concern and test: clean. Scoped `git diff --check`: clean.

No schema, browser, live provider or shared database operation was performed. The full authentication plan remains incomplete. OTP logging remediation remains separately escalated and excluded.
