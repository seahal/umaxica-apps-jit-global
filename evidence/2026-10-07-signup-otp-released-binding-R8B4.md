# Signup OTP released-binding verification

- Commit: `6fa6867d44b5499632079775cb0fb22cbfddd339`, with inherited and task uncommitted changes affecting results.
- Scope: existing disposable TEST manifest, one Rails worker; no migrations or historical transitions.
- RED: `bin/rails test test/services/sign_otp_ceremony_test.rb -i '/released signup/'` accepted retained correct OTP on a released binding (one run, one assertion, one failure, seed 32517).
- Issuance and verification now refuse released Contact facts before use and recheck under the Source contact lock. No OTP is replaced or consumed, no release fact is cleared and no Identity is re-resolved.
- Four public operation cases cover app/com email/telephone using actual persisted owner, Contact, binding facts, Ticket and HOTP. They assert refusal for both issuance and verification plus preservation of proof and release.
- GREEN: `bin/rails test test/services/sign_otp_ceremony_test.rb test/integration/contact_email_signup_source_audit_test.rb test/operations/telephone_signup_source_audit_test.rb`: 19 runs / 241 assertions, zero failures/errors/skips (seed 30769).
- Initial scoped lint reported one whitespace offense, fixed without behavioral changes. Shared failure/dispatch limits, exact success retries and full Phase 19/Final Verification remain unfinished.
- After the whitespace correction, scoped RuboCop passed on the operation and its test: two files, no offenses; scoped diff whitespace check passed.
