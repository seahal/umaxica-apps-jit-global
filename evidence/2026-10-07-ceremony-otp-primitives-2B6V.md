# Ceremony OTP model primitives

Commit: `48ff7040de2b50a8a08ed660fa71878a029ba577`; relevant uncommitted changes present.

- `bin/rails test test/models/ceremony_owned_otp_test.rb` initially ran 2 tests with 2 errors:
  the new public ceremony issuance operations did not exist. After implementation it passed
  2 tests and 14 assertions.
- Expanded lifecycle tests initially ran 18 tests, 96 assertions and 6 errors: malformed UTF-8
  codes reached regex comparison. A valid-encoding check fixed this without weakening tests.
- `bin/rails test test/models/ceremony_owned_otp_test.rb test/models/ceremony_owned_otp_lifecycle_test.rb`
  passed 20 tests, 152 assertions, no failures/errors/skips.
- `bin/rails db:migrate RAILS_ENV=test` applied six forward Ticket migrations. The first attempt
  was rejected by Strong Migrations before commit because CHECK validation was combined with
  addition. CHECK creation is now NOT VALID, followed by separate validation migrations; all
  six then applied successfully. No production database was touched.

The primitives use independent Email/Telephone policies, random codes and realm/channel HMAC
keys. Existing controller/delivery integration, identifier proof removal, failure-budget integration,
deadline boundary and concurrent verifier tests remain incomplete.

Subsequently, `bin/rails test test/models/ceremony_owned_otp_concurrency_test.rb` passed
6 tests and 24 assertions with exactly one successful comparison per realm/channel under a
two-connection race. Deadline boundary and caller/failure-budget integration remain incomplete.

The new public delivery-availability predicates were initially absent (12 deadline tests errored).
`bin/rails test test/models/ceremony_otp_deadline_boundary_test.rb test/models/ceremony_owned_otp_lifecycle_test.rb test/models/ceremony_owned_otp_test.rb`
then passed 32 tests and 218 assertions, checking the exact stored deadline and neighboring
microsecond instants for every realm/channel. Caller and failure-budget integration remain incomplete.

`bin/rails test test/models/ceremony_otp_terminal_facts_test.rb test/models/ceremony_otp_deadline_boundary_test.rb test/models/ceremony_owned_otp_lifecycle_test.rb test/models/ceremony_owned_otp_test.rb`
passed 34 tests and 224 assertions, with no failures, errors or skips. Ordinary model updates
cannot erase successful consumption/cancellation or rebind their terminal OTP facts. This result
does not establish protection against direct SQL updates or complete controller integration.
