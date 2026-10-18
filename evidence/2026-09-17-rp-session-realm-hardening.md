# RP Session and OAuth Realm Hardening Evidence

Date: 2026-09-17

Repository: `seahal/umaxica-apps-jit-global`

Branch: `feature`

Baseline task commit before this uncommitted slice: `f921fbe2b`
(`Add surface-local authority schema foundation`). The pre-existing modified `README.md` and deleted
`misc.md`/`refactor.md` were preserved and were not staged. No migration, database reset, worker
start, external delivery, deployment, push, or GitHub write was performed.

## Implemented contract

- The app, com, and org Base OAuth controllers pass fixed endpoint realm values (`client`,
  `visitor`, and `operator`) to token exchange and revocation.
- Authorization-code realm mismatch is rejected before Valkey consume, rotation, or RP-session side
  effects. Refresh mismatch is rejected before refresh rotation.
- A parent Browser Session is locked before looking up an RP child. A second authorization-code
  exchange for the same parent and RP is rejected while the existing RP Session is unrevoked or
  still retiring; its JTI and scope are not replaced.
- Each surface RP-session table receives an explicit `oidc_access_token_max_expires_at` migration.
  Issued Access JWT expiry is stored monotonically, and known retirement occurs only after the
  maximum expiry plus the configured verifier leeway. A legacy row without known history is not
  treated as retired.
- Revocation uses the RP-session row lock. This remains PostgreSQL state, not a Valkey revocation
  list, and no ordinary bearer-request RP-session lookup was added.

## Checks run

| Command                                                                                                      | Result                                                                                      |
| ------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------- |
| Ruby syntax check for changed auth models, services, controllers, tests, and three migrations                | Passed                                                                                      |
| `bundle exec rubocop --force-exclusion` over the 15 changed/new Ruby files                                   | Passed; no offenses                                                                         |
| `git diff --check`                                                                                           | Passed                                                                                      |
| `RAILS_ENV=test ... bundle exec bin/rails zeitwerk:check` with disposable test Valkey URLs                   | Passed: `All is good!`                                                                      |
| `RAILS_ENV=test ... bundle exec bin/rails test test/services/oidc/realm_binding_test.rb`                     | Blocked during test boot: PostgreSQL host `primary` could not be resolved; no assertion ran |
| `RAILS_ENV=test ... bundle exec bin/rails test test/models/rp_session_test.rb`                               | Blocked during test boot: PostgreSQL host `primary` could not be resolved; no assertion ran |
| `RAILS_ENV=test ... bundle exec bin/rails test test/controllers/base/oauth_oidc_authority_test.rb`           | Blocked during test boot: PostgreSQL host `primary` could not be resolved; no assertion ran |
| `RAILS_ENV=test ... bundle exec bin/rails test test/services/oidc_token_revocation_service_coverage_test.rb` | Blocked during test boot: PostgreSQL host `primary` could not be resolved; no assertion ran |
| `RAILS_ENV=test ... bundle exec bin/rails test test/services/oidc/token_exchange_service_test.rb`            | Blocked during test boot: PostgreSQL host `primary` could not be resolved; no assertion ran |

The unverified portions are database migration application, rollback, concurrent issuance/revoke,
refresh rotation, Valkey atomic consume, and external RP acceptance. No non-test datastore was used
as a fallback. The remaining seven-client versus regional JP/US registration conflict is recorded as
`CF-007`; this slice does not claim that integration is complete.

## Security review

- `request` parameters do not choose the endpoint realm.
- Realm mismatch happens before code consumption and before refresh/replay side effects.
- Existing RP-session credentials are not overwritten by a later authorization code.
- Missing historical Access JWT expiry fails closed rather than allowing replacement.
- The implementation does not claim immediate invalidation of already-issued Access JWTs; their
  natural expiry plus verifier leeway remains the residual window.
- No raw token, cookie, OTP, secret, request body, or authorization header was added to logs,
  migrations, or evidence.
