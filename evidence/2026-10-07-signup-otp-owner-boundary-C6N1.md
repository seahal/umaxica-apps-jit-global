# Signup OTP candidate ownership verification

- Commit: `6fa6867d44b5499632079775cb0fb22cbfddd339`, with uncommitted inherited and task changes affecting the result.
- Environment: the existing task-owned 20-database disposable TEST manifest, one Rails worker. No migration or historical data transition was performed.
- RED: `bin/rails test test/services/sign_otp_ceremony_test.rb -i '/another Identity/'` failed because issuance did not refuse a Ticket referring to another Identity's candidate (one run, one assertion failure, seed 6167).
- Change: `SignOtpCeremony` compares the candidate owner with the Ticket principal before use and again under the Source contact lock, for app/com email/telephone issuance and verification. Mismatches raise explicitly; another Identity's OTP is neither dispatched nor consumed, and its failure counter is preserved. The existing test factory now supplies its real fixture owner's ID rather than unrelated ID 123.
- GREEN: the OTP service test plus the four telephone signup/audit files passed 43 runs / 1440 assertions, zero failures/errors/skips (seed 3900). After scoped style fixes, `bin/rails test test/services/sign_otp_ceremony_test.rb` passed 15 runs / 91 assertions, zero failures/errors/skips (seed 27592).
- Scoped RuboCop: `app/services/sign_otp_ceremony.rb` and `test/services/sign_otp_ceremony_test.rb`, two files, zero offenses.
- ADR, the four customer Contact OTP diagrams and their inventory sections describe the delivered guard. This is not completion of D-87: common recreated-flow/browser failure and dispatch limits, exact committed-result recovery and the complete delivery/parity matrix remain outstanding.
