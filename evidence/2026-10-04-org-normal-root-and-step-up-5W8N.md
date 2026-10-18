# ORG Normal root issuance and subsequent step-up

Verified against HEAD `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5` with uncommitted authentication changes and unrelated concurrent work on 2026-10-04 UTC.

Added a generator-created integration test that starts with an actor having no root session. Separate Base/Auth cookie jars redeem a real local admission. The Entra strategy performs its actual request phase, state/nonce processing, PKCE token exchange and RS256 ID-token verification. Faraday test adapters supply the token and JWKS HTTP responses; no real Microsoft service was contacted and no dynamic strategy replacement is used. An actual WebAuthn FakeClient assertion completes the second factor. Auth returns opaque evidence without access/refresh cookies or an OperatorToken; Base completion creates one Normal-context token with its root establishment anchor. Repeated completion creates no additional token or renewed anchor, and another sign-in attempt is refused while logged in.

The same newly issued Base cookie starts a separate birthdate step-up through Base confirmation POST, Auth admission POST, real Passkey assertion, opaque result handoff and Base finalization. The protected page succeeds, the exact transaction is consumed, the original root anchor is unchanged, and there remains exactly one root token. Auth has no root credentials throughout. Turnstile is stubbed and Jump transport is decoded rather than browser-executed.

Commands used the owned manifest `tmp/auth-boundary-isolated-20261003auth6f3.json`, run ID `20261003auth6f3`, `POSTGRESQL_TEST_PREPARE_DATABASES=codex_integrity_20261003auth6f3_app_ticket` and `PARALLEL_WORKERS=1`.

- `bin/rails test test/integration/org_root_login_establishment_test.rb`: 1 test, 47 assertions, green, seed 24523.
- Combined with `org_admin_step_up_ceremony_test.rb`, `org_admin_csrf_test.rb`, `emergency_step_up_prohibition_test.rb` and `org_step_up_passkey_committers_test.rb`: 23 tests, 299 assertions, green, seed 37870.
- `bundle exec rubocop test/integration/org_root_login_establishment_test.rb`: no offenses.
- `git diff --check`: passed before the final extension; the added extension is lint-clean.

Browser checks remain user-owned; live-provider verification, registration/management completion and the broader R01–R16 acceptance gates are outstanding. The excluded OTP logging work was not changed. This is not a full-suite pass or a claim of full implementation completion.
