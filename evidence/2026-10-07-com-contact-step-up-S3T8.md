# COM contact Step-Up verification

- Commit: `6fa6867d44b5499632079775cb0fb22cbfddd339`, with inherited and task changes affecting results.
- Scope: existing 20-database disposable TEST manifest, one Rails worker. No migrations or historical data changes.
- RED: `bin/rails test test/controllers/base/com/identity/telephones/registrations_controller_test.rb -i '/first telephone/'` created a candidate despite absent scoped Step-Up (one run, two assertions, one failure, seed 50547).
- Change: COM telephone registration's verification-required predicate uses the existing MFA-bootstrap-active predicate, matching COM email registration, rather than the presence of a verified telephone alone. The genuinely unconfigured bootstrap contract is unchanged.
- Public tests cover missing proof on first attachment and removal of proof after initiation but before correct OTP confirmation. They assert refusal, no binding/audit and no OTP consumption. Existing successful verification and replacement tests retain their assertions.
- GREEN: `bin/rails test test/controllers/base/com/identity/telephones/registrations_controller_test.rb test/controllers/base/com/identity/emails/registrations_controller_test.rb`: 32 runs / 169 assertions, zero failures/errors/skips (seed 46971).
- Scoped RuboCop: controller and telephone integration test, two files, no offenses.
- This verifies request-entry guards, not concurrent proof revocation after the guard or complete Task 19 acceptance. No Task checkbox was completed.
