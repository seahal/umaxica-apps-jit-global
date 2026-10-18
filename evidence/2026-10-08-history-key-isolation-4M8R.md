# History/live key isolation

Commit: `48ff7040de2b50a8a08ed660fa71878a029ba577`.
Uncommitted implementation changes affected these results.

Distinct environment variable names did not prevent operators from configuring the same secret for
history and live lookup. New tests covering all six history domains reproduced that defect:
`bin/rails test test/lib/identifier_history_fingerprint_verifier_test.rb` produced 33 runs, 356
assertions, six failures, no errors or skips. Fingerprint generation and valid candidate matching
now refuse history secrets equal to any configured live HMAC secret, without disclosing secret values.
Absent live keys are not required or used as history fallback; the selected history key is mandatory.

`bin/rails test test/lib/identifier_history_fingerprint_verifier_test.rb
test/models/dead_identifier_history_contract_test.rb test/models/dead_identifier_destroy_test.rb`
passed 45 runs, 486 assertions, zero failures, errors or skips. An earlier invocation used the
nonexistent `dead_identifier_history_test.rb` path and failed before executing tests; the corrected
command above is the actual verified result.

A read-only `bin/rails runner -e test` probe removed all six live HMAC keys only from that process's
environment and generated/matched a synthetic candidate fingerprint in each realm/channel. All six
printed `independent history matching=true`. No persistent secret or external environment was changed.
This construction check was executed and recorded, not added as a configuration Minitest case.

Focused RuboCop passed for the primitive and its tests: two files, no offenses.
Whole-owner erasure, all lifecycle integration and final verification remain outstanding.

The repository's actual live-key reader also accepts Rails combined credentials. A second set of
six tests reproduced reuse through that provider: 39 runs, 428 assertions, six failures, no errors
or skips. The guard now checks both configured credentials and process environment secrets. The
same primitive/schema/destruction selection then passed 51 runs, 522 assertions, zero failures,
errors or skips. Earlier counts describe earlier, overlapping selections, not an additive total.
