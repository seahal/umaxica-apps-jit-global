# Local login revocation boundaries and evidence race

Verified against HEAD `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5` with authentication-related and unrelated uncommitted work present. Only test and documentation changes were added in this verification slice.

The service tests cover all three surfaces at one microsecond before flow expiry, exact expiry, and one microsecond after expiry. Credential changes revoke continuity without extending the flow deadline or manufacturing an authentication event; existing root-session retention remains effective.

The concurrency test uses committed, owned rows, two independent PostgreSQL writer connections (distinct backend IDs), a queue barrier, and a bounded timeout on each surface. It races synthetic Auth evidence recording against the real credential security transition. Either evidence is recorded before revocation or rejected afterward; the flow ends FAILED and its continuity is revoked in both cases. Re-recording evidence is rejected. Only test-owned rows are removed during cleanup.

An APP HTTP test starts on Base, redeems Auth admission, verifies primary Email OTP, obtains the opaque result, performs a credential security transition, and returns that result to Base. The existing flow policy refuses the FAILED flow before issuance and redirects to Base root. No token, access/refresh cookie, root-finalization timestamp, or LOGGED_IN audit event is created. The original authentication timestamp and result generation remain historical facts. This is Rails middleware integration, not a browser test.

Tests used owned manifest `tmp/auth-boundary-isolated-20261003auth6f3.json`, run ID `20261003auth6f3`, migration scope `codex_integrity_20261003auth6f3_app_ticket`, and `PARALLEL_WORKERS=1`:

- `bin/rails test test/services/credential_security_transition_test.rb test/models/auth_ceremony_revocation_concurrency_test.rb test/integration/root_login_establishment_flow_test.rb`: 57 tests, 845 assertions, no failures/errors/skips; seed 55310.
- RuboCop on those three files: clean. Scoped `git diff --check`: clean.

The initial HTTP assertion expected 400, but source inspection and execution showed the existing Action Policy denial returns a Base-root redirect. The test now asserts that actual public denial contract and verifies the absence of issuance; production authorization was preserved. An initial boundary test used an unsupported numeric duration method; the test now expresses PostgreSQL microsecond neighbors with Rational values.

This proves the evidence-recording race and post-revocation APP root rejection. It does not prove a race against successful root issuance, OIDC/sign-up invalidation, or distributed atomicity across databases. The full plan remains incomplete. Browser checks remain user-owned; OTP logging remediation remains separately escalated and excluded.
