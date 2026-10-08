# Realm identifier encryption tests

Commit: `48ff7040de2b50a8a08ed660fa71878a029ba577`; uncommitted implementation changes affected these checks.

- RED: `bin/rails test test/models/realm_identifier_encryption_test.rb` ran 2 tests,
  8 assertions, 2 failures. Cross-realm decryptions succeeded under the old shared keyring.
- GREEN: the same command ran 2 tests, 18 assertions, no failures, errors or skips after explicit
  realm providers were assigned to all six identifier models.
- Expanded: `bin/rails test test/models/realm_identifier_encryption_test.rb test/lib/realm_identifier_digest_test.rb test/models/telephone_issuance_timestamp_test.rb`
  ran 13 tests, 123 assertions, no failures, errors or skips. This includes old global ciphertext
  rejection and previous-read/current-write rotation for each realm.

Commands used the normal local test configuration without additional environment assignments.
Only non-secret local example keys were added; production configuration was not changed.
Other PII keyrings, full regression tests and encryption re-encryption operations remain unverified.
