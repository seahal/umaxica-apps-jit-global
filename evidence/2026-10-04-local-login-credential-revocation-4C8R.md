# Local login evidence revocation on credential changes

Verified against HEAD `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5` with authentication-related and unrelated uncommitted work present.

`CredentialSecurityTransition` now ends actor-owned, unfinished sign-in flows referenced by local admissions before changing token state. It locks the actor, flow, and continuity rows on their writers. It preserves result digests, generation, and authentication timestamps as history, shortens outstanding result expiry, and revokes continuity. Completed flows and foreign actors remain unchanged. This covers local admission-linked sign-in flows; it does not establish equivalent coverage for every OIDC or sign-up flow.

Tests used only the owned database manifest `tmp/auth-boundary-isolated-20261003auth6f3.json`, run ID `20261003auth6f3`, migration scope `codex_integrity_20261003auth6f3_app_ticket`, and `PARALLEL_WORKERS=1`.

- `bin/rails test test/services/credential_security_transition_test.rb test/operations/identity_credential_removal_committer_test.rb test/integration/local_authentication_boundary_test.rb test/integration/root_login_establishment_flow_test.rb test/integration/org_root_login_establishment_test.rb test/integration/totp_registration_boundary_test.rb`: 57 tests, 992 assertions, no failures/errors/skips; seed 15887.
- After adding a public clock fault injection test, `bin/rails test test/services/credential_security_transition_test.rb`: 29 tests, 300 assertions, no failures/errors/skips; seed 13316. Each surface rolled back flow and continuity changes and retained the token when the ticket clock failed before continuity revocation.
- RuboCop on the service and its test: clean. Scoped `git diff --check`: clean.

An earlier run exposed duplicate synthetic result digests across variants. Fixtures now use distinct digests; uniqueness constraints were retained. No browser, live-provider, distributed transaction, or concurrent root-finalization claim is made. The full implementation plan remains incomplete. OTP logging remediation remains separately escalated and outside this work.
