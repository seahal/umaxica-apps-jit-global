# Realm identifier and OTP slices

Commit: `48ff7040de2b50a8a08ed660fa71878a029ba577`; uncommitted task changes affected these results.

- `bin/rails db:migrate RAILS_ENV=test` applied 14 pre-existing pending migrations and then the
  three new telephone issuance-timestamp migrations. Effective targets were test-prefixed databases
  on the configured `primary` test host. No development/production reset was performed.
- Telephone timestamp RED: 3 tests failed because all three models lacked `otp_last_sent_at`.
- `bin/rails test test/models/telephone_issuance_timestamp_test.rb test/models/concerns/telephone_test.rb test/models/concerns/otp_lockable_test.rb`:
  36 tests, 115 assertions, zero failures/errors/skips after replacing the created-at anchor.
- Failure-retention RED: both Email and Telephone reset 1 historical failure to 1 instead of
  incrementing to 2; the no-shared-policy assertion also failed.
- After independent policy replacement and existing timestamp/window expectation updates:
  `bin/rails test test/models/concerns/telephone_test.rb test/models/otp_failure_retention_test.rb test/models/telephone_issuance_timestamp_test.rb test/models/concerns/otp_lockable_test.rb`:
  39 tests, 134 assertions, zero failures/errors/skips.
- `bin/rails test test/models/otp_failure_retention_test.rb`: 5 tests, 34 assertions, zero
  failures/errors/skips, including issuance/resend counts 0, 1, MAX-1, MAX and MAX+1 for Email and
  Telephone. These checks do not certify all realm/flow cancellation or successful-consumption paths.
- Realm HMAC RED: both channel calls rejected the new required realm argument. After six-key
  selection and realm/channel domain binding, the two tests passed with 12 assertions.
- Malformed-identifier RED: a malformed identifier acquired a lookup digest. Explicit input/type,
  encoding/NUL and telephone-format validation was then added to the digest boundary.
- `bin/rails test test/lib/identifier_blind_index_test.rb test/lib/realm_identifier_digest_test.rb`:
  18 tests, 109 assertions, zero failures/errors/skips. Coverage includes normalization,
  cross-realm separation, channel separation, missing keys despite legacy keys, unsupported realms
  and identifier sentinel/malformed inputs.
- Narrow RuboCop autocorrection of the two new channel policies and initial new model tests
  completed with 29 formatting offenses corrected. This is not a full lint result.

An 87-test combined run additionally exposed the existing Email candidate uniqueness expectation
conflicting with effective-binding-only implementation. The old window-reset expectations also
failed in that run and were subsequently updated to the newly approved retention contract. Live
uniqueness implementation and full verification remain outstanding; no broad suite pass is claimed.

`bin/rails db:verify_no_schema_drift RAILS_ENV=test` failed: the task regenerates dumps and compares
them to the Git index, including intended uncommitted migrations and pre-existing/dump-format
differences. It does not prove schema migration effects are incorrect. No commit was made to bypass
this gate. Dump review and final verification remain outstanding.

The channel-binding separation regression ran RED with 8 tests, 40 assertions and one failure:
APP Email still included shared stateful ContactBinding. Separate EmailContactBinding and
TelephoneContactBinding now preserve the existing public transitions and database constraints.
`bin/rails test test/models/otp_failure_retention_test.rb test/models/contact_binding_constraints_test.rb`
passed 15 tests and 278 assertions without failures/errors/skips. Focused RuboCop on the two new
binding concerns and the retention test passed. This does not certify remaining shared caller policy
or final OTP ownership migration.

Preserving failure counts exposed a timed-unlock regression: issuance cleared an expired finite
lockout marker, then a fresh issuance anchor reactivated count-only lockout at MAX. The six-model
RED ran 14 tests, 58 assertions and 6 failures. Both channel policies now leave lockout state
unchanged during issuance; normal successful consumption remains the reset boundary.
`bin/rails test test/models/otp_failure_retention_test.rb test/models/concerns/otp_lockable_test.rb test/models/concerns/telephone_test.rb`
passed 47 tests and 190 assertions, no failures/errors/skips. Existing identifier-backed proof
methods in these tests are still awaiting the final ceremony caller migration and removal.
