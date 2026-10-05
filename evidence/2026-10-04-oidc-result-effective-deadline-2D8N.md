# OIDC opaque result effective deadline and typed validation

Verified against HEAD `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5` with authentication-related and unrelated uncommitted changes present.

OIDC result preparation now bounds its delivery expiry by the requested transport TTL, parent transaction expiry and login challenge expiry. An expired challenge cannot issue a new result generation. Matching requires authenticated/consumed state, a 64-character hexadecimal String digest and a positive Integer generation; it also refuses either expired durable deadline. No field, enum, schema, cookie or response shape was changed.

The original code failed the effective deadline assertion: seed 64602, one test, one assertion, one failure. Public model tests on APP, COM and ORG cover valid matching, missing/empty/zero/NUL/malformed types, stale generation, digest length neighbors, and one-microsecond expiry neighbors. A legacy oversized result deadline cannot revive its expired parent or challenge. Authentication time and result generation are preserved by reads.

All Rails commands used owned manifest `tmp/auth-boundary-isolated-20261003auth6f3.json`, run ID `20261003auth6f3`, migration scope `codex_integrity_20261003auth6f3_app_ticket`, and `PARALLEL_WORKERS=1`.

- Narrow public result test: one test, 87 assertions, no failures/errors/skips; seed 29139.
- `bin/rails test test/models/concerns/oidc_authorization_transactionable_test.rb test/controllers/base/oauth_oidc_authority_test.rb test/controllers/base/app/sign/in/limitations_controller_test.rb test/controllers/base/com/oauth/authorizations_controller_test.rb test/controllers/base/org/oauth/authorizations_controller_test.rb test/services/credential_security_transition_test.rb test/services/base_auth_admission_coordinator_test.rb test/integration/root_login_establishment_flow_test.rb test/integration/local_authentication_boundary_test.rb`: 146 tests, 1508 assertions, no failures/errors/skips; seed 7441. This includes the existing successful APP finalized-result retry without another root session.
- RuboCop on the modified model concern and test: clean. Scoped `git diff --check`: clean.

No browser, live provider, new schema or shared database operation was performed. The full plan remains incomplete; initial registration linkage and neutral-entry mode selection still require work. OTP logging remediation remains excluded.
