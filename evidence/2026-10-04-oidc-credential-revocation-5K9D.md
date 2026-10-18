# Credential changes invalidate unfinished OIDC authentication

Verified against HEAD `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5` with authentication-related and unrelated uncommitted work present.

The red service test reproduced an owned authenticated OIDC result surviving a credential change: seed 59573, one test, one assertion, one failure. Credential transitions now shorten owned unfinished OIDC transaction, login challenge and result deadlines using the writer clock, revoke associated Auth continuity, and cancel open APP capacity resolutions within the existing surface ticket transaction. Completed/consumed history and foreign actors are preserved. No schema or response shape was added.

Base OIDC completion on APP, COM and ORG now acquires the actor lock before the authorization transaction lock. The successful APP root/retry test observes that lock ordering through SQL notifications while retaining real issuance. APP capacity promotion now occurs inside OIDC finalization; the page rejects an expired or mismatched parent before revoking a selected root session.

Public tests cover all three surfaces' owned/foreign/history partitions, rejection of previously issued opaque results at Base without token/cookie/finalization issuance, and rollback of deadline updates when the Auth continuity clock raises a database connection error. APP additionally verifies an expired OIDC parent leaves its selected existing session usable. OIDC proof setup in these cases is synthetic; it is not evidence of a real Auth credential or external provider ceremony.

All Rails commands used owned manifest `tmp/auth-boundary-isolated-20261003auth6f3.json`, run ID `20261003auth6f3`, migration scope `codex_integrity_20261003auth6f3_app_ticket`, and `PARALLEL_WORKERS=1`.

`bin/rails test test/services/credential_security_transition_test.rb test/controllers/base/oauth_oidc_authority_test.rb test/controllers/base/app/sign/in/limitations_controller_test.rb test/controllers/base/com/oauth/authorizations_controller_test.rb test/controllers/base/org/oauth/authorizations_controller_test.rb test/models/concerns/oidc_authorization_transactionable_test.rb test/models/auth_ceremony_revocation_concurrency_test.rb test/integration/root_login_establishment_flow_test.rb test/integration/local_authentication_boundary_test.rb`: 146 tests, 1562 assertions, no failures/errors/skips; seed 11703.

RuboCop on the service, its test, three OAuth controllers, APP limitation controller/test and OAuth authority test: clean. Scoped `git diff --check`: clean.

No browser or live provider check ran. Independent-writer OIDC root issuance races, late primary evidence recording during credential changes, and sign-up admission linkage remain unverified. The full plan remains incomplete. OTP logging remediation stays separately escalated and excluded.
