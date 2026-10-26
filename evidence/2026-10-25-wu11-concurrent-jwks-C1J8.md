# WU-11: concurrent JWKS cold-cache lookups

- Revision: `bde2346c17e2aa911acc95de1f6035f80498f2da`.
- The worktree contained extensive pre-existing staged and unstaged authentication changes.
  Verification includes that state plus this uncommitted change.
- Scope: `two.md` section 6.3, D-144, successful self-fetch of a key identified by the distributed
  recent-success window. Concurrent requests on one client reuse a fresh key populated while
  waiting for the fetch mutex. A lease-driven refresh still fetches normally; removed keys are
  not restored from the previous cache.

## Observations

- Red: `bin/rails test test/adapters/oidc_jwks_concurrent_lookup_test.rb` failed as intended:
  four cold lookups caused four fetches instead of one. A queue barrier makes all four requests
  observe the cold cache before allowing them to proceed, without sleeps or external HTTP.
- Green: `bin/rails test test/adapters/oidc_jwks_concurrent_lookup_test.rb
  test/adapters/oidc_jwks_refetch_limiter_test.rb test/adapters/oidc_op_protocol_verifiers_test.rb`:
  19 tests, 138 assertions, zero failures/errors/skips. Includes successful key removal, rotation
  during outage, cache expiry boundaries and distributed refetch limiting.
- `bin/rails test test/unit/security/forbidden_rails_patterns_test.rb
  test/security/invariants/forbidden_patterns_invariant_test.rb
  test/services/oidc/id_token_verifier_test.rb test/services/oidc/jwks_service_test.rb`:
  28 tests, 121 assertions, zero failures/errors/skips.
- After formatting, the new concurrency test passed again: one test, six assertions.
- `bundle exec rubocop app/adapters/oidc_op_jwks_client.rb
  test/adapters/oidc_jwks_concurrent_lookup_test.rb`: two files, no offenses.
- Scoped `git diff --check` passed.

## Limits

This closes the reproduced successful-fetch race only. Failed self-fetch retries, lease-holder
death, real-store TTL boundaries and request-level BCL outage acceptance were not completed by
this change. The full suite and schema drift verification were not run; there are no schema
changes. WU-11 and the overall authentication cycle remain open.
