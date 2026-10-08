# Signup expiry and Email timing retirement

Commit: `48ff7040de2b50a8a08ed660fa71878a029ba577`; uncommitted worktree changes affected these results. Normal `bin/rails test` used only the local test database fleet, without added environment variables.

Sixteen existing signup initial/post-lock deadline cases were migrated from shared Source HOTP to independent Email/Telephone APIs without removing expiry assertions. They reproduced missing durable expiry (16 tests/64 assertions, 16 failures, seed 35781). Independent operations now invoke existing `SignUpTermination` outside their proof-operation locks when an admitted parent becomes overdue. Failure counters remain unchanged; cleanup remains logical retention, not dead History creation. Four issuer fixtures now place positive issuance/resend before irreversible expiry and additionally refuse issuance after an earlier clock is restored.

The Email timing boundary guard first failed because authentication still included `CommonOtp` (seed 30550). Email-only response timing replaces those inclusions in APP/COM Email authentication, resend and both reentry concerns without exposing the old shared Source verifier. Existing explicit timing floors remain; dummy generation is CSPRNG-based, not HOTP.

Results:

- Six-file signup/receipt/malformed/timing matrix: 86 tests, 1,365 assertions, zero failures/errors/skips, seed 44475. Command: `bin/rails test test/services/sign_otp_ceremony_lock_deadline_test.rb test/operations/email_sign_up_otp_issuer_test.rb test/operations/telephone_sign_up_otp_issuer_test.rb test/services/signup_otp_committed_retry_test.rb test/services/sign_otp_ceremony_malformed_code_test.rb test/controllers/auth/credential_timing_protection_contract_test.rb`.
- Five-file actual Email enumeration/resend/withdrawal regression: 12 tests, 105 assertions, zero failures/errors/skips, seed 10226. Files: APP/COM `in/emails_controller_enumeration_test.rb`, `sign_in_otp_resender_failures_test.rb`, `withdrawal_ceremony_reentry_test.rb`, `withdrawal_ceremony_reentry_guards_test.rb`.
- Scoped RuboCop: seven signup operation/test files passed after formatting and complexity extraction; nine timing/receipt/malformed files passed with no offenses.

The first mixed run also found 32 committed-retry fixture errors: missing cleanup reference rows were obscured by a translation error during validation. Test-owned reference defaults now initialize explicitly, matching the other signup fixtures. No application configuration or translation workaround was added.

Shared legacy signup classes, remaining Source proof fields/callers and repository-wide final gates remain pending. These checkpoints do not complete the Goal.

Subsequent delivery migration retained all twenty original current/reissued/consumed/expired/owner-locked
cases across APP/COM Email/Telephone. Four expiry cases reproduced the same omitted durable
parent termination in the independent delivery guards (20 tests/140 assertions, seed 33021).
After refusing delivery, each independent guard rechecks the original session/actor/candidate,
operation/purpose and generation under the parent/child locks, releases the child lock and calls
the existing expiry/cleanup boundary. It does not hold Source/proof locks through compensation.
The combined guard/initial-post-lock expiry/retained receipt/late Email-SMS matrix passed:
82 tests, 762 assertions, no failures/errors/skips, seed 18372. Command:
`bin/rails test test/operations/sign_up_otp_delivery_guard_test.rb test/services/sign_otp_ceremony_lock_deadline_test.rb test/services/signup_otp_committed_retry_test.rb test/notifiers/notify/email_sign_up_otp_delivery_test.rb test/integration/telephone_sign_up_otp_delivery_test.rb`.
Scoped four-file RuboCop also passed with no offenses. Proof comparisons use boolean snapshots
to avoid printing keyed evidence in diagnostic output.
