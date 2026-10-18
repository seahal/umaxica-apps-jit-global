# Legacy OTP and notifier binding retirement

Commit: `48ff7040de2b50a8a08ed660fa71878a029ba577`; the worktree contained uncommitted changes.

The unused shared `CommonOtp` concern and four unused Telephone definitions were removed:
`SignTelephoneRegistrable`, both `Sign{App,Com}UpTelephoneSignupCreator` operations and
`SignTelephoneOtpDelivery`. All five source paths are Git-tracked and their deletions remain
recoverable; no tests were deleted. Their current callers use independent channel ceremonies.
Historical inventory entries were annotated rather than presented as current definitions.

The Telephone implementation worker ran the five-file creator/delivery/concern/branch31 batch:
pre-removal 21/221, seed 65393; post-removal 21/221, seed 35727, with zero failures/errors/skips.
Scoped lint and whitespace checks passed. Its Phone-only model/assertion sweep then passed the
seven-path command covering the three Telephone models, Telephone concern, Operator status,
signup HTTP delivery and APP controller line 504: 109/597, seed 2728, zero failures/errors/skips.
Earlier fixture errors (canonical cleanup rows, wrong public ceremony reference and an impossible
issued-nil-expiry setup) were corrected without dropping the tested cases.

`OtpEmailNotifierAdapter` now forwards signup, credential-registration and reentry transaction/
generation values instead of HOTP counters. It no longer has an arbitrary keyword sink. Eight
realm/purpose binding cases reproduced missing forwarded references or old counter validation, and
the unexpected-keyword case reproduced silent acceptance: 13/16, one failure/eight errors, seed 63034.
The earlier single keyword regression was 5/12, one failure, seed 44883.

`bin/rails test test/adapters/otp_email_notifier_adapter_test.rb test/adapters/otp_adapter_test.rb
test/adapters/otp_email_adapter_test.rb test/notifiers/notify/email_sign_up_otp_delivery_test.rb`
passed: 30/118, seed 11863, zero failures/errors/skips. The first combined run exposed one stale
Mailer-adapter test expecting ignored keywords (seed 32636); it now checks rejection before queueing,
consistent with the approved no-silent-fallback contract. Three scoped files passed RuboCop and
whitespace checks. No raw code was persisted by the adapter change.

The five-file Email status/binding/failure-retention/finite-deadline model batch also passed after
private-helper extraction: 56/629, seed 63310, zero failures/errors/skips, normal 16-worker execution.
These are focused results; identifier HOTP columns, remaining shared signup/registration definitions,
the direct-SQL terminal proof gap and final gates remain unresolved.
