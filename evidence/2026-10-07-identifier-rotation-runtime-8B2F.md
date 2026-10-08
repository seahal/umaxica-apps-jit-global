# Identifier rotation runtime verification

Commit: `48ff7040de2b50a8a08ed660fa71878a029ba577`; relevant uncommitted changes present.

- The existing encryption HTTP drill reproduced a 400 response because it entered sign-in without
  durable admission. Its current browser entry now uses the existing admission helper, CSRF enabled,
  finalized live bindings and the code from actual queued mail. Missing semantic flow-state test
  data was supplied using its model constants, without production setup or test-only runtime code.
- The updated HTTP path passed one test and 24 assertions. A stronger old-key rejection assertion
  then failed: changing the global encryption context had not rotated explicit realm attribute
  providers. The drill now changes the actual realm attribute providers, retains previous reads,
  re-encrypts and restores all in-process test state. Old-only providers reject the new ciphertext.
- `bin/rails test test/integration/identifier_encryption_rotation_drill_test.rb test/models/realm_identifier_encryption_test.rb test/services/identifier_encryption_reencrypt_test.rb`
  passed 7 tests and 86 assertions, no failures/errors/skips. This covers local APP sign-in after
  rotation and APP/COM/ORG stored identifier reads, not live external delivery or production rotation.
- Backfill malformed-identifier RED ran 3 tests, 20 assertions and one failure from silent skip.
  It now raises a sanitized error and writes only the current digest column; obsolete optional
  `*_bidx` dual-write paths were removed. Expanded Email/Telephone failure checks passed
  `bin/rails test test/services/identifier_blind_index_backfill_test.rb`: 4 tests, 23 assertions,
  no failures/errors/skips.

Full Rails tests, full RuboCop and final security harness verification remain incomplete.

The re-encryption target-input regression ran RED with 3 tests, 3 assertions and one failure:
unsupported/empty target lists were accepted. The operation now accepts only a nonempty distinct
subset of the six identifier models and snapshots that list. Its silent decryption-error rescue
and empty-schema skip were removed. Unreadable ciphertext remains an explicit exception.
`bin/rails test test/services/identifier_encryption_failure_test.rb test/services/identifier_encryption_reencrypt_test.rb test/integration/identifier_encryption_rotation_drill_test.rb test/models/realm_identifier_encryption_test.rb`
passed 10 tests and 96 assertions, no failures/errors/skips. Focused RuboCop on the re-encryption
operation, failure tests and HTTP drill passed.
