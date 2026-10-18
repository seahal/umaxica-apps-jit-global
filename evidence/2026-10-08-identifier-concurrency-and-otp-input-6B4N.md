# Identifier concurrency and malformed signup OTP inputs

Commit: `48ff7040de2b50a8a08ed660fa71878a029ba577`.
The worktree contained uncommitted implementation and test changes affecting these results.
All database checks ran on the existing local test-prefixed PostgreSQL databases.

## Observed checks

- `bin/rails test test/services/sign_otp_ceremony_malformed_code_test.rb` first failed on four
  fixture prerequisites, seed 15617; explicit semantic cleanup/status references fixed the setup.
  The actual reproduction then failed in all four realm/channel cases with invalid UTF-8 from
  `blank?`, seed 51663. Encoding admission now precedes that call and preserves proof/failure state.
- That file and `test/services/sign_otp_ceremony_test.rb` passed 24 runs / 386 assertions,
  seed 55162. Boundary/partition inputs include invalid UTF-8, five/seven digits around the valid
  six-digit format, NUL, Unicode digits, zero, false, nil and empty strings.
- `test/services/sign_otp_ceremony_lock_deadline_test.rb` needed its own cleanup reference setup.
  Two Telephone issuance cases then refused on cooldown instead of reaching their target lock
  (seed 38579); moving the synthetic last-send timestamp outside cooldown for both channels fixed
  the fixture, preserving every expiry assertion. The file passed 16 / 64, seed 49946.
- `test/models/live_identifier_namespace_test.rb` initially failed 16 cases with four errors,
  seed 56397. It incorrectly asserted uniqueness of unverified APP/COM candidates and used an ORG
  Contact retention method that does not exist. Its unchanged duplicate-refusal requirement is
  now exercised against actual finalized live bindings, distinct owners and the correct retention
  owner. No uniqueness index, validation or security guard was weakened. Its 26 cases passed
  194 assertions, seed 24249.
- The new six-case concurrent creation matrix produced one live winner and one rolled-back
  conflict per realm/channel. Its first cleanup left two synthetic ORG history rows; the next
  combined run identified that contamination, not a uniqueness failure. Only the test-created
  `OperatorTelephoneHistory` 62 / staff 980190971 and `OperatorEmailHistory` 94 / staff 980190973
  were destroyed after rechecking `test_org_zenith_db`, exact owner matches and no live contacts.
  These synthetic histories are not recoverable; rerunning the fixture regenerates test evidence.
  The fixture now collects its own generated histories before deleting its own owners.
- Final command: `bin/rails test test/models/live_identifier_creation_concurrency_test.rb
  test/models/live_identifier_namespace_test.rb test/operations/dead_identifier_purge_concurrency_test.rb
  test/services/sign_otp_ceremony_malformed_code_test.rb test/services/sign_otp_ceremony_test.rb
  test/services/sign_otp_ceremony_lock_deadline_test.rb`.
  Result: **84 runs / 768 assertions, zero failures/errors/skips**, seed 26377, 16 processes.
- `bundle exec rubocop` for the changed service and the four changed/new test files passed:
  five files, no offenses. Earlier formatting offenses were corrected by normal RuboCop formatting.

No migration, production connection, secret, remote mutation or deployment occurred in this slice.
This is focused evidence, not certification of whole-goal completion. Signup proof ownership,
Telephone delivery, registration callers and complete removal of identifier HOTP remain unfinished;
full Rails, full lint and final harness/architecture checks remain required.
