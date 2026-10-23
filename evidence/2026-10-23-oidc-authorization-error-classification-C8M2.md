# Authorization coordinator error classification

- Date: 2026-10-23.
- Commit: `6e4d70d0b0799a4ef9bd9fc4cea2c21d4b3eca72`.
- Worktree: existing staged, unstaged and untracked authentication-cycle changes affected the
  tested implementation. This correction and its tests were also uncommitted.
- Scope: the WU-42 / D-147 request-error classifications already emitted by
  `OidcAuthorizeRequestResolver` were collapsed by `OidcAuthorizeCoordinator` into
  `invalid_request`, except for `InvalidScope`. Catching `RequestError` preserves its explicit
  error code. No request/response fields, storage formats or authentication controls changed.

## Observations

- Baseline: `bin/rails test test/services/oidc/authorize_service_test.rb` passed with
  29 runs, 108 assertions, 0 failures, 0 errors, 0 skips. Two assertions expected the old
  classifications, contrary to the resolver and `two.md` WU-42's decided error table.
- Red: after correcting those expectations and asserting absent success redirects, the same
  command produced exactly 2 failures: `unsupported_response_type` and `access_denied` were
  both returned as `invalid_request`; 29 runs, 107 assertions, 0 errors, 0 skips.
- Green: `bin/rails test test/services/oidc/authorize_service_test.rb
  test/resolvers/oidc_authorize_request_resolver_test.rb
  test/controllers/base/oauth_redirect_uri_conformance_test.rb` passed:
  39 runs, 236 assertions, 0 failures, 0 errors, 0 skips.
  Existing success, invalid-scope, missing-parameter, invalid-client, redirect validation and
  HTTP conformance tests remained green.
- `bundle exec rubocop app/services/oidc_authorize_coordinator.rb
  test/services/oidc/authorize_service_test.rb --format simple`: 2 files inspected, no offenses.
- `git diff --check` scoped to the changed service, tests, checklist and evidence passed.
- The accepted ADR `adr/oidc-authorization-request-profile.md` still labels the overall work
  unimplemented, while current resolver code and the earlier WU-42 evidence describe delivered
  portions. This narrow correction does not establish completion of WU-42.
- The full Rails suite and external Jump integration were not run for this correction.
