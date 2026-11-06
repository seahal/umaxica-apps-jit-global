# WU-A14 BL-19 passkey options rate-limit follow-up

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`.
- The worktree had 535 uncommitted paths at the start of this check; the test result was produced
  against that dirty worktree. No application or test file was changed for this check.
- `PARALLEL_WORKERS=1 bin/rails test test/controllers/auth/authentication_rate_limit_test.rb`
  produced 2 runs, 3 assertions, 0 failures and 1 error. The baseline-listed
  `AuthAuthenticationRateLimitTest#test_app_passkey_options_sign-in_hits_explicit_rails_rate_limit`
  stops at `test/support/fetch_metadata_defaults.rb:31` with `undefined method 'include?' for nil`
  during its first GET, before reaching the rate-limited endpoint.
- `PARALLEL_WORKERS=1 bin/rails test test/integration/auth_endpoint_burst_rate_limit_test.rb:43`
  passed: 1 run, 13 assertions, 0 failures, 0 errors, 0 skips. After a valid APP sign-in admission,
  the public passkey-options endpoint accepts the configured burst and returns HTTP 429 on the next
  request.
- The current public integration case demonstrates the selected 429 contract. The earlier reported
  HTTP 400 from the historical candidate is not explained by this check and is not classified as a
  current application defect.
