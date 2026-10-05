# Step-up decision clock

Checked against commit `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5` with uncommitted authentication changes and unrelated parallel work.

Actual ClientToken expiry tests reproduced four failures: Base finalization and the resolver accepted a token exactly at and one microsecond after its deadline when application time lagged the decision time. Both now pass their decision time to `currently_usable?`. The tests also cover one microsecond before the deadline and retain pending evidence after rejected finalization.

Using owned database manifest `tmp/auth-boundary-isolated-20261003auth6f3.json`, run ID `20261003auth6f3`, preparation restricted to `codex_integrity_20261003auth6f3_app_ticket`:

- `bin/rails test test/operations/identity_step_up_ceremony_freshness_committer_test.rb`: before correction, 16 runs, 105 assertions, four failures (seed 31988).
- The same file plus `test/services/step_up/resolver_test.rb`, `test/resolvers/step_up_resolver_aal_test.rb`, and `test/controllers/concerns/verification/base_step_up_logging_test.rb`: 34 runs, 184 assertions, no failures/errors/skips (seed 55773).
- Admission, step-up guard, ORG emergency prohibition and revocation concurrency files: 27 runs, 225 assertions, five failures (seed 43863). All five are in the emergency prohibition file, which still uses legacy grant/root-authentication assumptions and the obsolete freshness committer keyword interface. Its coverage migration remains required; this run is not green.
- RuboCop on the six changed Ruby files: no offenses after adding assertion spacing.

No browser verification, deployment, shared-database reconstruction or OTP logging remediation was performed. This evidence does not establish completion of the whole authentication plan.
