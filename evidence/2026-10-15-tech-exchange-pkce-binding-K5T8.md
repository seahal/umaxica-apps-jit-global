# Tech PKCE and callback binding with real client assertions

Recorded 2026-10-15 UTC against commit `7d4e2d941f4eb576eb77076c2c2a4e54badfa847`, with uncommitted
test and documentation changes.

Added AT-048 code-exchange coverage for an Operator with current tech.access. Separate issued
authorization codes are exchanged with a wrong but syntactically valid PKCE verifier and a changed
callback URI. Each uses a freshly signed production Tech client assertion, without mocking assertion
authentication. Both return invalid_request, issue no Tech RP row and keep the parent usable.
Existing coordinator checks explicitly define invalid_request for these mismatches; the initial
test's invalid_grant expectation was corrected after inspecting those contracts. No application
behavior was changed.

Executed
`env -u POSTGRESQL_ISOLATED_TEST_RUN_ID RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/services/oidc/tech_operator_capability_exchange_test.rb`:
3 runs, 21 assertions, 0 failures, 0 errors, 0 skips. Initial run: 3 runs, 12 assertions, 1 failure
from the incorrect error-code expectation, no errors or skips. Targeted RuboCop: one file, no
offenses. Scoped diff check: clean. Only normal Rails test databases were used. These service-level
checks do not establish live external transport, browser acceptance or completion of every protocol
partition.
