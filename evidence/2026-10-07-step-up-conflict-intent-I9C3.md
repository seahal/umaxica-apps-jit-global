# Step-Up conflict intent verification

- Commit: `6fa6867d44b5499632079775cb0fb22cbfddd339`, with inherited and task uncommitted changes affecting results.
- Scope: existing disposable TEST manifest, one Rails worker. No migrations or historical data transitions.
- Added direct public BaseStepUpAdmissionIssuer cases for app/com/org. Exact intent reuses parent/reference without changing either deadline; changed scope, target and purpose each return transaction_conflict while retaining the original pending parent/binding and no token freshness.
- The first reauthentication fixture violated the mandatory full_reauthentication_required contract and was corrected (seed 35337); production validation was not changed.
- GREEN: `bin/rails test test/controllers/base/step_up_intent_authority_test.rb test/operations/base_step_up_admission_issuer_test.rb test/controllers/auth/step_up_admission_test.rb test/unit/security/standard_csrf_invariant_test.rb test/security/invariants/csrf_verification_strategy_invariant_test.rb`: 60 runs / 791 assertions, zero failures/errors/skips (seed 20254).
- Earlier authority/issuer/CSRF baseline passed 50 runs / 590 assertions (seed 14233).
- Extended the existing real Auth attachment/redemption test through public cancel-and-start in all three realms. A stale Auth page for the canceled transaction returns 400 without modifying its cancellation timestamp, granting freshness or verifying/consuming the replacement. Base confirmation remains a public-model fixture in this test; it is not evidence of the full browser exchange.
- Admission boundary/authority/issuer/Auth Step-Up targets passed 73 runs / 1280 assertions, zero failures/errors/skips (seed 58228). RuboCop passed on both changed test files, no offenses.
- This confirms the targeted policy/invariant matrix, not the entire Phase 16 adversarial matrix, real-browser enforcement or all Task 17.3 canceled-tab cases. No Task checkbox was completed.
- Admission model/concurrency/coordinator/purger/HTTP targets passed 58 runs / 976 assertions, zero failures/errors/skips (seed 58370). Independent-connection race coverage used the existing test barriers; this is not a full suite run.
