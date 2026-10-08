# Ceremony finite deadlines

Commit: `48ff7040de2b50a8a08ed660fa71878a029ba577`; the worktree had uncommitted implementation changes.

Six APP/COM/ORG Email/Telephone cases reproduced an `ArgumentError` when a persisted OTP deadline
was PostgreSQL positive or negative infinity (seed 25789: six errors). Each independent channel
now explicitly rejects non-finite parent or OTP deadlines before delivery and verification.
No replacement timestamp, identifier-backed verifier, or exception fallback was introduced.
Terminal model guards also protect the original parent deadline.

`bin/rails test test/models/ceremony_otp_finite_deadline_test.rb
test/models/ceremony_owned_otp_test.rb test/models/ceremony_owned_otp_lifecycle_test.rb
test/models/ceremony_owned_otp_concurrency_test.rb test/models/ceremony_otp_delivery_test.rb`
passed: 44 tests, 359 assertions, zero failures/errors/skips, seed 36233.

Scoped RuboCop on the two channel concerns and the new finite-deadline test passed: three files,
no offenses.

This is focused evidence, not completion of the full suite or the outstanding direct-SQL terminal
proof protection.
