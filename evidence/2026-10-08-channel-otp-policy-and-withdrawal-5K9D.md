# Channel OTP policy constants and withdrawal failure retention

Commit: `48ff7040de2b50a8a08ed660fa71878a029ba577`.
Uncommitted worktree changes affected these results.

CommonOtpPolicy and CommonOtp's shared expiration constant were removed. EmailOtpPolicy and
TelephoneOtpPolicy independently own their existing ten-minute lifetimes, thirty-second resend
cooldowns and ten-second overwrite windows. Email response timing remains Email-owned. All
application/test callers select the actual channel; no aliases or legacy capability probes were
introduced. This preserves current HTTP behavior while proof ownership migration remains open.

`bin/rails test test/services/sign_otp_ceremony_test.rb test/models/otp_failure_retention_test.rb
test/models/telephone_issuance_timestamp_test.rb` initially produced 49 runs, 430 assertions,
zero failures and one error: the writer-clock assertion still referenced the removed shared
expiration constant. It now asserts the owning Email policy. The rerun passed 49 runs, 434
assertions, zero failures, errors or skips. Focused RuboCop passed for the two policies, CommonOtp,
SignOtpCeremony and its test (five files).

Withdrawal cleanup independently reset identifier failures and finite lockout deadlines, despite
not consuming a correct OTP. Two new real APP/COM cases reproduced this: two runs, two assertions,
two failures, no errors or skips. The two reset assignments were removed from each channel cleanup.
No proof, retention or delivery fallback was added.

`bin/rails test test/operations/withdrawal_personal_data_anonymizer_test.rb
test/integration/withdrawal_ceremony_reentry_test.rb
test/controllers/concerns/withdrawal_ceremony_reentry_guards_test.rb
test/models/enforcement_recovery_ceremony_test.rb` passed 12 runs, 100 assertions, zero failures,
errors or skips. Its earlier run had one StaleObjectError before anonymization: the existing Secret
fixture advanced the Client lock version. Reloading the actor before the existing withdrawal update
restored the current owner snapshot without changing assertions or application lock protections.

The whole-Identity physical erase/history boundary still needs confirmation. Existing synthetic
identifier rewriting is not the final History design and remains open. Final verification has not
been completed; these overlapping focused runs do not constitute a full-suite result.
