# Signup policy database-clock verification

- Commit: `6fa6867d44b5499632079775cb0fb22cbfddd339`, with uncommitted inherited and task changes affecting these results.
- Scope: the existing task-owned 20-database disposable TEST manifest, one Rails worker. No migration or historical data transition was performed.
- RED: `bin/rails test test/policies/sign_up/finalization_database_clock_test.rb` failed because app finalization authorization remained true at the exact Ticket DB deadline (one run, two assertions, one failure, seed 49012).
- Change: signup BasePolicy supplies the owning Ticket class's `database_now` explicitly to the expiry predicate instead of relying on its application-clock default.
- GREEN: `bin/rails test test/policies/sign_up/finalization_database_clock_test.rb test/policies/sign_up/policies_test.rb test/services/sign_up/contracts_test.rb test/services/sign_otp_ceremony_test.rb test/integration/app_secret_signup_journey_test.rb` passed 84 runs / 1555 assertions, zero failures/errors/skips (seed 32336).
- The new test uses actual persisted app/com flows, actual Actor authentication context and permitted DB-clock control; each checks one microsecond before, at and one microsecond after the deadline.
- Scoped RuboCop passed for `app/policies/sign_up/base_policy.rb` and `test/policies/sign_up/finalization_database_clock_test.rb`: two files, zero offenses.
- Signup diagram/inventory guard notes and `five.md` were updated. Controller context/policy revalidation under lock, the older inventory's tombstone-edge reconciliation and full signup/final verification remain unfinished.
