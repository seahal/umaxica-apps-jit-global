# WU-A14 BL-23 Visa DBSC check offer

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree had uncommitted changes that
  affected this result; 562 tracked paths were changed, 284 paths were untracked, and no paths were
  staged at the final snapshot.
- Added a public integration case for authenticated Visa APP and ORG `/edge/v0/token/check`. Both
  responses advertise matching `Secure-Session-Registration` and legacy registration headers, the
  canonical local DBSC endpoint path and a persisted challenge.
- `UMAXICA_ENV_FILE=/home/global/workspace/.env.container.devcontainer RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/integration/visa_roots_test.rb`:
  10 runs, 236 assertions, 0 failures, 0 errors, 0 skips. This includes APP/ORG valid proof, wrong
  realm audience, wrong signing key, proof replay, missing-session refusal and challenge-expiry
  boundaries.
- `bin/rubocop test/integration/visa_roots_test.rb`, `ruby -c test/integration/visa_roots_test.rb`
  and scoped `git diff --check` passed.
- Browser-native DBSC device registration was not run. This evidence establishes the Visa HTTP offer
  and registration behavior only; actual browser interoperability remains unverified. No application
  source or database schema changed, and no full suite was run.
