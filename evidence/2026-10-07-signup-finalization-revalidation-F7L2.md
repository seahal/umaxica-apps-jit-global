# Signup finalization revalidation

- Commit: `6fa6867d44b5499632079775cb0fb22cbfddd339`, with inherited and task uncommitted changes affecting results.
- Scope: existing 20-database disposable TEST manifest, one Rails worker. No migrations or historical data changes.
- Deadline RED: actual app/com email HTTP journeys advanced the permitted Ticket DB clock from the first completed-requirement authorization decision to the exact expiry deadline. Both persisted effective Source bindings before finalization refusal (two runs / 42 assertions / two failures, seed 37125).
- The controller now rebuilds its finalization context and rechecks the same policy after acquiring/reloading the Ticket row lock, before Source side effects. No policy/security control was bypassed or relaxed.
- Owner RED: `bin/rails test test/operations/telephone_signup_source_audit_test.rb -i '/suspended Identity/'` finalized a suspended Source Identity instead of refusing (one run / one assertion / one failure, seed 17955).
- Both telephone finalizers and the email Source branches now refuse an unavailable owner under the Source owner lock. Public operation tests preserve retained OTP and no binding/intent; email HTTP cases preserve no effective binding/intent and no completed Ticket.
- GREEN: email HTTP plus existing policy targets passed 38 runs / 277 assertions, zero failures/errors/skips (seed 54349).
- GREEN: `bin/rails test test/integration/contact_email_signup_source_audit_test.rb test/policies/sign_up/finalization_database_clock_test.rb test/operations/telephone_signup_source_audit_test.rb test/operations/sign_app_up_telephone_registration_finalizer_test.rb test/operations/sign_com_up_telephone_registration_finalizer_test.rb`: 12 runs / 268 assertions, zero failures/errors/skips (seed 3094).
- This controls the allowed DB-clock dependency; it is not an independent-connection race test. Exact recovery, all Source/Ticket faults and the complete Final Verification remain unfinished. No Task checkbox was completed.
- Scoped RuboCop passed on both telephone finalizers, the shared signup controller concern and both changed test files: five files, no offenses. Scoped diff whitespace check passed.
